# Recipe documents and Kitchen archives

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

Research for [#96](https://github.com/ctwelve/KitchenMemory/issues/96), 2026-09-06. This recommends future contracts; it does not add an importer, exporter, document type, persistence migration, or retention policy. All fixtures are synthetic. The accompanying Python program is a nonshipping reference experiment, not a KitchenKit implementation.

## Questions and competing hypotheses

Before selecting a direction:

1. **One established Recipe vocabulary is sufficient.** Falsify by round-tripping a two-parent immutable Revision, independent Selection, original wording beside uncertain parsed quantity, and a future field through its ordinary model.
2. **One format can mean both shareable Recipe and full backup.** Falsify if a recipient cannot distinguish omitted Sessions/deletions from absent evidence, or if sharing one dish leaks unrelated Kitchen organization/history.
3. **Existing persistence JSON is already a portable format.** Falsify through an unknown member, noncanonical numeric spelling, owner reassignment, or schema-independent reader.
4. **A small domain envelope with two explicit profiles is sufficient.** Falsify through byte-preserving unknown evidence, bounded hostile input, and independent reconstruction of an archive without the originating database. The experiment below addresses only the first two technical properties; independent KitchenKit reconstruction remains a shipping prerequisite.

## Evidence and alternatives

| Candidate | Useful capability | Loss against Kitchen Memory / decision |
| --- | --- | --- |
| Open Recipe Format | YAML; ordered ingredients and steps, amounts/yields, processing, book/source attribution, extensible `X-` fields | No specified Kitchen Memory Revision/Selection graph, Session closure, deletion frontier, or organization receipts. Extensions could carry them, but would constitute a new dialect. Its recipe identifier guidance is not our owner-independent UUID contract. Consider a future compatibility adapter, not archival authority. [ORF reference](https://openrecipeformat.readthedocs.io/latest/topics/reference/orf.html) |
| Schema.org Recipe, usually JSON-LD | Source attribution, image/media, yield, durations, instructions with sections/steps; current reference permits Text, ItemList, or PropertyValue ingredients and inherits HowTo `tool` | Do not inaccurately describe it as only flat text or incapable of Equipment. Nonetheless it does not define our immutable Save/Selection, rational uncertainty, Session Facts, or causal organization semantics. Suitable optional presentation projection; never claim lossless Kitchen restoration from that projection. [Recipe vocabulary](https://schema.org/Recipe) |
| JSON | Ordered arrays and portable text syntax; object members permit application extensions | Syntax supplies neither domain semantics nor automatic unknown-field preservation. Reject duplicate members, nonfinite numbers and invalid UTF-8; store exact rational/decimal values in explicitly tagged strings rather than relying on binary floating point. [RFC 8259 §§4, 6, 8–9](https://www.rfc-editor.org/rfc/rfc8259) |
| ZIP + manifest | Documented cross-platform packaging and compression | Does not establish scope, media authenticity, dependency completeness, privacy, or safe extraction. Select a deliberately restricted stored/deflated profile, stream to controlled staging, and independently verify SHA-256. [PKWARE APPNOTE](https://support.pkware.com/pkzip/appnote) |
| BagIt | Payload manifests, checksums, completeness/validation terminology | Useful archival discipline, but no Recipe or Kitchen semantics. Full BagIt packaging adds files and optional mechanisms this first envelope does not require. Reconsider if preservation-tool interoperability becomes a real requirement. [RFC 8493](https://www.rfc-editor.org/rfc/rfc8493) |
| Apple Archive | Native compression and preservation of filesystem attributes | Attributes such as ownership, permissions and extended attributes are exactly what a domain export should avoid copying indiscriminately. Keep as an optional measured transport candidate; no evidence here that it offers broader interoperability than ZIP. [Apple Archive](https://developer.apple.com/documentation/applearchive) |
| FileDocument / FileWrapper / UTType | Native document reading/writing, regular-file and package representations, declared content types | These are application integration capabilities, not interchange contracts. Use the existing app's import/export affordances; no document-based rewrite required. Implement security-scoped access lifetime and stage a stable copy before validation. [FileDocument](https://developer.apple.com/documentation/swiftui/filedocument), [FileWrapper](https://developer.apple.com/documentation/foundation/filewrapper), [sandbox access](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox), [type declarations](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/understanding_utis/understand_utis_declare/understand_utis_declare.html) |

These lossiness judgments are inferences comparing those primary specifications with this repository's contracts, not claims that arbitrary extensions are impossible. ORF documentation identifies revision `a4291272`; it is evidence of a format, not evidence of widespread adoption. Schema.org's fetched page identifies itself as the development vocabulary; a compatibility adapter must pin/test the supported vocabulary profile.

## Existing constraints

[ADR 0004](../adr/0004-apple-persistence-and-portability.md) requires versioned domain interchange independent of SwiftData. [ADR 0011](../adr/0011-use-document-envelopes-for-cooking-sessions.md) makes Session snapshots self-contained and immutable; [ADR 0017](../adr/0017-use-additive-recipe-authority-evidence.md) makes Recipe authority additive. Nothing in this recommendation changes those decisions.

`RecipeRevisionCodec` in `KitchenKit/Domain/RecipeAuthority.swift` removes optional image bytes, hashes canonical JSON, and rejects decode/re-encode byte differences. `KitchenKit/Domain/CookingSessionCodecs.swift` uses the same canonical equality boundary. `OrganizationStore` validates version, identity, canonical evidence and digest. Passing unknown fields through those typed decoders is therefore not forward-compatible transport: it can reject the document after fields disappear on re-encode. Do not weaken these authority validators to make an importer appear permissive.

[Recipe content](../recipe-domain-model.md) preserves original wording, authored section/row order, Equipment, source capture, exact/ranged/approximate/textual quantities and presentation overrides. [Media](../recipe-media.md) separates immutable digest references from byte availability. [Folders](../folders.md) and [Tags](../tags.md) have identities, aliases, causal receipts and independent ordering. Export projections alone cannot replace these records.

## Recommended envelope and scope

Use one documented transport family with **two distinct profiles and document types**, `recipe` and `kitchen`. Proposed extensions/type identifiers remain unassigned until implementation. A manifest declares format major/minor, scope, required features, payload format versions, inventory counts, logical IDs and references, byte sizes, media availability and hashes. A local export snapshot fixes the inventory before writing. An optional Schema.org rendition is explicitly nonauthoritative.

Use a restricted ZIP containing `manifest.json`, immutable payload members and `media/<sha256>` members. Names are generated, never borrowed from user filenames. Permit a JSON-only Recipe variant only when its media omission is explicit. Preserve immutable evidence as exact byte members with its original codec version/digest, rather than decoding and rewriting it through the manifest's JSON parser. Manifest unknown optional members are retained in a generic lossless representation or as original bytes plus known-field overlays. Unknown numeric lexemes must survive: a generic floating-point dictionary is insufficient.

| Content | Portable Recipe | Kitchen archive |
| --- | --- | --- |
| One Recipe identity, all retained immutable Revisions, ancestry, Saves/Selections and original/source content | Yes; includes concurrent branches, not just current appearance | All Recipes and retained authority |
| Attribution, uncertainty, presentation choice, authored order, Equipment and media metadata | Yes, intact | Yes, intact |
| Source captures and referenced media | Include available bytes; declare unavailable content. Sensitive source evidence is private content, not telemetry | Include all retained in-scope bytes; explicitly report incompleteness |
| Cooking Sessions, snapshots, Facts, Closures, continuations and deletion/restoration evidence | No; a source Session lineage reference may be unresolved and clearly external | All retained evidence, including stopped/active/finished/unavailable/recovery states |
| Folder/Tag identities, aliases, assignments, manual sequence, ordering mode and system-view visibility | Exclude; optional plain descriptive labels only in a separately identified sharing rendition | Include authoritative evidence/checkpoints, not only rendered tree/list |
| Deleted Items, Recipe tombstones, Recovery evidence | Not a general restoration channel; reject pruned/unreadable identity as a normal Recipe export, offer explicit readable-content derivative separately | Include all retained evidence and promises; never equate omitted payload with successful purge |
| Kitchen Owner / account identity, credentials, CloudKit IDs, local paths, diagnostics | Neither | Neither |
| Local sync switch, onboarding, local Folder/Tag enablement, expansion, locale, maintenance timers, sync observations and drafts | Neither | Excluded from v1 content archive; state this limitation instead of claiming a complete device backup |

The portable history profile can reveal earlier private wording: the export preview must state that history is included. A future “share current Recipe” projection may deliberately omit it, but must have a different explicit scope and loss report. Do not silently substitute that projection for the lossless profile.

An archive preserves the retained Kitchen at capture time; it cannot recover already pruned payload or prove that every offline device has synchronized. Report unresolved references and observations without claiming global completeness. A strict self-contained export fails if a required payload is unavailable; an explicitly incomplete archive preserves available evidence and an inventory of missing material. Import must not guess missing history.

## Ownership, identity and import transaction

The artifact carries domain UUIDs and an archive-local scope identifier, **never a Kitchen Owner account identifier**. Bind ownership to the current authorized local Kitchen only after admission. An archive is not authority to join another person's Kitchen. Domain Kitchen UUIDs are distinct from account identity; where the format needs them for lineage, document the exact justification and mapping. Inspect every payload family before claiming owner-free export: blindly serializing `FolderCommand` would include its Kitchen ID even though the stored organization payload isolates ownership.

Default Recipe import is **copy with retained provenance**. Allocate a new Recipe and all subordinate/authority IDs through one durable mapping, rewrite every known reference consistently, and create newly identified imported evidence; retain the original immutable byte graph separately as source provenance. Do not claim remapped bytes retain their old authority digest. Unknown payloads that might contain IDs make structural copy unsafe: retain the artifact without activation until a supported migrator can interpret them. Avoid inventing ancestry across Kitchens.

Separate explicit restore/reconcile mode preserves logical IDs only for a verified compatible lineage and target ownership. UUID equality alone is insufficient proof. Same ID plus same payload/version/digest is an exact retry; same ID plus different evidence is a conflict and blocks activation. Never timestamp-overwrite or silently regenerate one colliding ID. Recipe identity behind a tombstone remains barred from resurrection. Name collisions remain distinct Folder/Tag identities in Organization Recovery; they are not UUID collisions or permission to merge.

Kitchen v1 import should first target an **isolated staging Kitchen/store**, validate and reconstruct every supported aggregate, then expose a review summary. Prefer import as a separate newly owned Kitchen over wholesale merge into the existing one; the current single-Kitchen app needs an explicit activation/replace policy before this can ship. An additive merge into an existing Kitchen is a later slice, requiring causal evidence compatibility and retained tombstone checks. No distributed atomicity promise.

Pipeline: obtain selected-file access → bounded local staging → inspect archive/version/inventory → hash and structural validation → typed domain graph validation → preview scope/conflicts/loss → commit one supported local transaction or isolated store activation. Persist an import operation ID, full input digest, selected mode/target and ID mapping. Exact retry uses that receipt; a new copy is an explicit new operation. Validation, cancellation, quota exhaustion or commit failure leaves the existing Kitchen unchanged. Clean staging on cancellation/failure; after process death resume or discard the journal. Do not implement rollback as inverse synchronized Deletes: other devices may already observe them. Large archive atomic activation requires crash-injection proof before any success claim.

Version policy: reject unknown major versions and unknown required features; accept unknown optional fields only when preserved without interpretation. Unknown authority-bearing record kinds are retained as unsupported evidence, never activated as valid state. A required dependency's unsupported version blocks its aggregate. Keep original bytes through migration; new derived bytes obtain their own version/digest and provenance. Security validation applies equally to unknown fields and opaque members.

## Resource and media admission profile

The following are **proposed initial hard limits**, not existing product limits or performance measurements. One preview must explain refusal without partial writes. Export above the supported profile fails or proposes an explicitly separate future large-archive workflow; it must not silently truncate.

| Resource | Proposed production starting bound |
| --- | --- |
| Compressed input / aggregate expanded bytes | 512 MiB / 2 GiB, also capped by available staging quota with reserved headroom |
| Archive entries | 100,000; count during central-directory scanning before allocating an unbounded list |
| Manifest / individual structured payload | 8 MiB / 8 MiB; all payloads also consume total budget |
| JSON nesting / aggregate token count | 64 / 4 million across structured input; preflight or streaming parse before recursion/allocation |
| Logical identities across **all** kinds | 100,000, including Recipes, Revisions, nested content IDs, Session Facts, organization and receipts |
| All relationships/causal links/assignments | 500,000; count repeated entries too, before coalescing |
| Folders + Tags / projected Folder depth | 10,000 combined / 64; iterative cycle/depth validation; causal graphs separately bounded by the global identity/edge budgets |
| Organization name | Existing 256-grapheme domain rule **and** 1,024 UTF-8 bytes; reject controls; budget normalization work and preserve spelling |
| Media | 20 MiB each, 1 GiB total; at most 50 megapixels decoded per image and one concurrent decode; benchmark these proposed decode limits |
| Expansion ratio / stream chunk | 100:1 per member and overall, plus absolute byte budgets / 64 KiB |

Ratios alone do not prevent bombs. Check declared sizes for early rejection and count actual streamed output independently. Reject encryption, multipart/nested archives, unsupported compression, duplicate or case-fold-colliding names, absolute paths, dot segments, backslashes, NUL, symlinks/hardlinks, device files and filesystem attributes. Generate extraction destinations from validated manifest hashes, never concatenate unchecked entry names. No external fetch, XML entity expansion, JSON-LD remote context resolution, embedded executable content, or automatic URL opening. Check CRC as transport error detection and SHA-256 against manifest; an unsigned hash proves integrity relative to that manifest, not authorship.

Do not re-encode archived image bytes merely to import them: that would change immutable references. Decode in a bounded adapter before presentation; unsupported media remains explicitly unavailable but retained. Present media references without payload as missing, preserve descriptions/order/roles, and never substitute unrelated bytes. Package only referenced payloads plus evidence needed to explain unresolved references. Existing normalized app images already omit source metadata; arbitrary future originals require their own deliberate private-content contract.

[PRIVACY.md](../../PRIVACY.md) excludes account and private debugging material from public artifacts. A user-directed Recipe export itself necessarily contains selected private authored content, but must not accidentally include local metadata. Source captures and URLs can themselves contain secrets. Use a pre-export sensitive-data check and review of the selected scope; if forbidden credentials/local paths occur inside immutable evidence, refuse that lossless profile and offer a separately identified sanitized derivative. Never silently redact bytes while asserting their original digest/history remains intact. Generic scans cannot prove the absence of secrets in arbitrary text; a narrowly reviewed source-capture contract is required before shipping.

Retention: archives are user-owned snapshots and do not expire themselves. Restore preserves original deletion evidence and anti-resurrection promises; extend protection conservatively when needed, never shorten it. Archive creation/import is not proof of replica settlement and must not trigger physical pruning. Session evidence stays retained under the current policy; deeper Session cleanup remains a separate dependency-aware decision. Delete temporary staged bytes and receipts containing content when no longer needed; retain only minimal local retry identity/mapping for the documented retry horizon. Do not upload fixtures, source captures or failures to diagnostics.

## Reproducible experiment

Accompanying directory: [synthetic interchange fixtures](recipe-and-kitchen-interchange-fixtures/README.md).

Run `python3 experiment.py` within that directory. It generates `recipe-unknown-fields.json`, `kitchen.json`, `malformed.json`, `excessive-folder-depth.json`, `synthetic-recipe.zip`, and `results.json`. It uses only Python's standard library, no network, no product database, no image decoding and no Xcode test action.

Observed result: **24/24 checks passed**. Both profiles preserve semantic unknown members nested at multiple levels; an opaque future evidence payload preserves exact bytes including numeric spelling and whitespace. The synthetic Recipe carries original wording alongside a rational range, stable ingredient/Equipment order, attribution and opaque source text. The Kitchen fixture includes retained evidence placeholders. Rejection checks cover malformed/duplicate-key/nonfinite JSON, unsupported versions/required features, JSON byte/nesting limits, excessive Folder depth/cycles, oversized names, identity/relationship budgets, dangling edges, unsafe ZIP paths, media hash mismatch, ZIP expansion/entry/aggregate budgets. The maximum permitted 128 identities succeeds under the reduced experiment profile.

The reduced limits are recorded in `results.json` and intentionally differ from the unmeasured production proposals above. JSON input is capped before decoding; nesting is scanned before the recursive parser; Folder traversal is iterative and bounded; media is read in 4 KiB chunks. Python allocation peaks are captured per case (including generated inputs in some cases), **not a production RAM bound**. `zipfile` reads a central-directory list, so this experiment bounds that allocation only through its small compressed-input cap; shipping requires incremental entry admission. Exact object roundtrip does not prove complete Kitchen domain reconstruction, and retained Session placeholders do not prove closure reconciliation. No test here establishes crash atomicity, image-decoder safety, normalized Unicode grapheme limits, secret detection, or production-scale performance.

## Implementation-ready follow-up slices

1. **Recipe export:** pin envelope/profile schema and a canonical fixture corpus; export all retained Recipe history/source/media through a consistent repository snapshot. Add native document type/export integration, exclusion audit and incomplete-media preview. Acceptance: independent reader validates inventory/digests and reproduces complete known history plus unknown opaque bytes; no account/defaults/path leakage.
2. **Recipe import:** bounded staging/parser, domain validation, explicit copy mapping and persistent import receipt; retain original graph as provenance. Acceptance: exact retry, divergent UUID reuse, tombstone collision, foreign ownership, unsupported authority, cancellation and local transaction failure all leave existing evidence correct; adversarial corpus and local native file-picker workflow pass.
3. **Kitchen export:** extend inventory to all Session/organization/disposition/recovery evidence, authoritative ordering preferences and referenced media, with explicit exclusions/completeness report. Acceptance: synthetic deleted/pruned/concurrent/unfinished examples reconstruct independently; retained aliases and receipts survive; offline incompleteness is accurately reported.
4. **Kitchen import:** first implement isolated staging and read-only reconstruction, then separately authorize the single-Kitchen activation/replace policy. Acceptance: whole-archive dependency validation, bounded organization graphs, old/new/tombstone collision matrix, disk-full/cancellation/crash at every activation boundary, durable retry and rollback proof. Existing-Kitchen merge is not bundled into the initial restore slice.

Human judgments remaining: whether history-bearing Recipe export is the default sharing choice; handling sensitive source captures without false losslessness; first Kitchen activation/replace experience; support horizon for unknown versions and import receipts; useful large-Kitchen quotas measured on supported devices; whether encrypted user-owned archives merit a later interoperability/security design. These choices do not prevent the narrow export-format work but must be settled before the dependent behavior ships.
