# Recipe media

Private Recipe images are optional authored content. Reading reserves hero space
only for a decodable image explicitly assigned the hero role. Missing, delayed,
or unsupported images leave the textual Recipe available.

The native editor imports image files selected through the system picker. It
rejects inputs larger than 20 MB and decodes the first frame into an oriented
JPEG no larger than 2400 pixels on its longest edge. Encoding the decoded image
omits source metadata such as location. Errors reveal neither file paths nor
image contents. The person can preview, describe, replace, and remove the hero.

Recipe Editing Drafts retain selected bytes in their existing atomic local
document, including frozen Save commands. Close and failed publication preserve
that document; Discard removes the draft without changing shared authority.
Saving retains stable media identities and creates an immutable Recipe Revision.
An omitted media collection in an older draft preserves the original media;
an explicitly empty collection removes it from the new Revision.

`RecipeMedia.assetName` remains the logical image reference: bundled media uses
its existing resource name, while private media uses `private-image:sha256:`
followed by the selected bytes' digest. Private references never use bundle
lookup or remote URL fetching. The canonical Recipe Revision codec includes
this reference and accessibility description but excludes the optional local
`imageData`. Availability therefore cannot change authority digests. Resolved
bytes must match the reference before presentation.

Schema V6 adds only `RecipeImagePayloadRecord`, with scalar Revision and media
identities and optional externally stored image bytes. V1–V5 definitions remain
unchanged and V5 migrates through an additive lightweight stage. SwiftData's
private CloudKit configuration transports these records; image availability
makes no assertion of global synchronization completion. Exact Save retry can
replenish missing bytes without creating another Revision.

Replacement and removal do not erase older Revision payloads. Cooking Session
Execution Snapshots continue to contain only `SessionMediaReference`, never
image bytes. Dependency-aware reclamation remains governed by the Recipe
pruning work; this media slice introduces no automatic image garbage collection.
Production CloudKit schema promotion and signed cross-device acceptance remain
release operations, separate from deterministic local and hosted tests.
