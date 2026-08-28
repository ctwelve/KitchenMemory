# CloudKit production schema evolution and container replacement

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

- Status: Research complete
- Researched: 2026-08-27
- Scope: Production CloudKit schema evolution for raw CloudKit and managed
  Core Data/SwiftData stores, including the new-container escape hatch

## Conclusion

Within one production CloudKit container, the durable rule is **append-only
record types and fields, with deliberately mutable indexes**. New record types
and new fields may be deployed. Existing record types and fields cannot be
deleted or renamed, and an existing field cannot be repurposed to another type.
Queryable, sortable, and searchable indexes may be added or removed; public
database security-role grants may also be changed. Removing an index can make a
query slower or unsupported, so it is operationally consequential even though
it is permitted. [Apple's CloudKit schema-evolution explanation](https://developer.apple.com/videos/play/wwdc2021/10118/)
· [Deploying a container schema](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema)

The proposed exception for “expanding” a text field does not exist in
CloudKit. `STRING` and `BYTES` have no declared schema width to enlarge or
shrink. The combined non-asset content of a `CKRecord` is limited to 1 MB;
large text or binary content belongs in a `CKAsset`. For managed Core Data,
variable-length String, Binary Data, and Transformable attributes already
generate a companion asset field, and Core Data moves oversized values between
the inline and asset representations. Increasing an application's accepted
text length is therefore validation and storage behavior, not a CloudKit schema
change. [CloudKit schema-language types](https://developer.apple.com/documentation/cloudkit/integrating-a-text-based-schema-into-your-workflow)
· [`CKRecord` value and size rules](https://developer.apple.com/documentation/cloudkit/ckrecord)
· [Core Data's CloudKit record mapping](https://developer.apple.com/documentation/coredata/reading-cloudkit-records-for-core-data)

## Production change matrix

| Change | Production status | Consequence |
| --- | --- | --- |
| Add a record type | Allowed after development initialization and explicit schema deployment | Older apps ignore or cannot understand the new type. |
| Add a field to an existing type | Allowed after explicit schema deployment | Existing records are not backfilled, and older apps do not know the field. Ship forward-compatible readers. |
| Delete or rename a record type | Forbidden after production promotion | Add a replacement type and leave the old type deployed, or migrate to a new store/container. |
| Delete or rename a field | Forbidden after production promotion | Add a replacement field and leave the old field deployed. A source-code rename is safe only if its persistent CloudKit name remains unchanged. |
| Change an existing field's type or meaning | Forbidden/unsafe | Add a new field or record type, translate data at the application layer, and retire the old representation logically. |
| Convert an existing field to encrypted | Forbidden | CloudKit encryption may be selected only for a newly introduced field. [Encrypting user data](https://developer.apple.com/documentation/cloudkit/encrypting-user-data) |
| Add or remove an index | Allowed | Review every dependent query before removal; indexes affect query capability as well as performance. |
| Change public-database role grants | Allowed | Treat as a security review and test older clients before deployment. |

Production clients cannot create unknown record types or fields just in time;
the server rejects them until the schema change is deployed. Schema deployment
copies record types, fields, and indexes from Development into Production, but
it copies **no records**. [`CKRecord`](https://developer.apple.com/documentation/cloudkit/ckrecord)
· [Deploying a container schema](https://developer.apple.com/documentation/cloudkit/deploying-an-icloud-container-s-schema)

SwiftData uses `NSPersistentCloudKitContainer` and inherits this server
contract. A SwiftData `SchemaMigrationPlan` can migrate a local model store; it
does not grant permission to destructively alter a production CloudKit schema.
Apple states the SwiftData rule directly: after production promotion, model
types cannot be deleted and existing model attributes cannot be changed.
[SwiftData CloudKit synchronization](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)

## New-container escape hatch

Apple lists a completely new store associated with a new CloudKit container as
one strategy for a major Core Data model change. The same app can access the old
and new containers concurrently when both identifiers are present in its
CloudKit entitlements. Raw CloudKit supports multiple `CKContainer(identifier:)`
instances, and `NSPersistentCloudKitContainer` supports additional store
descriptions backed by different containers. [Creating a Core Data model for CloudKit](https://developer.apple.com/documentation/coredata/creating-a-core-data-model-for-cloudkit)
· [Identifying an app's containers](https://developer.apple.com/documentation/cloudkit/identifying-an-app-s-containers)
· [`NSPersistentCloudKitContainerOptions`](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontaineroptions)

Apple does not provide a server-side operation that migrates records between
containers. Because schema deployment explicitly copies no records, the
following is an architectural inference from the cited APIs: a new-container
cutover is an **application-owned data migration**, not a CloudKit schema
migration. The app must load or fetch old-container data, transform it, and save
new records into the destination. That copy must be resumable and idempotent;
there is no cross-container transaction or global acceptance point.

The migration also crosses real identity and security boundaries:

- A `CKRecord.ID` is unique only within a database, and `CKRecord.Reference`
  can link records only within the same zone and database. Preserve Kitchen
  Memory's application-owned stable identities and rebuild destination
  relationships rather than treating CloudKit IDs as portable identity.
  [`CKRecord.ID`](https://developer.apple.com/documentation/cloudkit/ckrecord/id)
  · [`CKRecord.Reference`](https://developer.apple.com/documentation/cloudkit/ckrecord/reference)
- CloudKit creates user records per container. Do not assume a user-record ID
  from the old container has the same meaning in the new one.
  [`CKContainer`](https://developer.apple.com/documentation/cloudkit/ckcontainer)
- A share is container-specific: share metadata names its container, and share
  acceptance executes against that container. Copying records does not carry
  the old share URL, owner/participant relationship, permissions, or accepted
  participation into the destination. **Inference:** shared Kitchens require
  an owner-authorized destination share and fresh participant acceptance; a
  participant's shared view is not ownership authority for migration.
  [`CKShare.Metadata.containerIdentifier`](https://developer.apple.com/documentation/cloudkit/ckshare/metadata/containeridentifier)
  · [`CKAcceptSharesOperation`](https://developer.apple.com/documentation/cloudkit/ckacceptsharesoperation)
- Each new container needs its own Production schema, indexes, security grants,
  and encryption choices. Both containers must remain entitled while the app
  supports migration, rollback, or straggling devices. Apple says a created
  iCloud container cannot later be deleted or renamed.
  [Enabling CloudKit](https://developer.apple.com/documentation/cloudkit/enabling-cloudkit-in-your-app)

## Kitchen Memory consequence

For the current container, keep V3 strictly additive. If a future design needs
to change an existing field's type or meaning, first prefer a new field or
versioned replacement type with explicit compatibility logic. Consider a new
container only when that additive residue would itself make the schema unsafe
or unmaintainable. Such a cutover is a separate migration product: it must
preserve application identity, account for private ownership, rebuild sharing,
and prove resumable per-user copying before any old-container path is retired.

The frozen V3 contract deliberately does not request optional CloudKit
field-level encryption for Session attributes. Cookbook content does not
justify the resulting recovery and future multi-user key constraints, and
Kitchen Memory retains user-authorized raw recovery as a deliberate escape
hatch. This does not weaken the private-database access boundary or change
CloudKit's automatic asset protection. Because encryption state is immutable
after Production promotion, any later reversal requires additive replacement
fields, record types, or a new container generation rather than reinterpretation
of V3 fields.
