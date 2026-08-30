# Swift tooling ecosystem survey

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors
SPDX-License-Identifier: GPL-3.0-only
-->

- Status: Research complete; selection policy adopted by
  [ADR 0014](../adr/0014-prefer-native-capabilities-and-evidence-based-dependencies.md);
  no dependency adoption proposed
- Survey date: 2026-08-29
- Scope: Apple and Swift tooling that may become useful after the current
  implementation work establishes a concrete need

## Recommendation

Kitchen Memory does not need another runtime dependency today. Its current
native stack already covers the next planned work: a hardened `URLSession`
retriever, bounded Foundation JSON parsing, SwiftData with personal CloudKit
sync, SwiftUI, XCTest, and unified logging. The project currently resolves only
Defaults as a runtime package; SwiftLintPlugins is a build tool, and
swift-syntax is a resolved transitive component of Defaults' unused macro
targets rather than a linked application dependency ([inventory](../../DEPENDENCIES.md),
[resolved pins](../../KitchenMemory.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved)).

Keep the default **native first, measured gap second, narrow package third**.
The strongest packages to keep on a watchlist are:

- **SwiftSoup** when import needs a real HTML DOM, CSS selection, or
  microdata/site-specific fallbacks that the current bounded script extractor
  cannot express safely.
- **Nuke** when an explicit media feature needs a cancellable image pipeline,
  cache policy, prefetching, and repeated transforms. Kingfisher is a credible
  alternative; choose one, never both.
- **Swift Collections, Swift Algorithms, and Swift Async Algorithms** when a
  named data-structure or sequencing requirement replaces hand-written,
  benchmarkable logic—not for general convenience.
- **SwiftUI-Flow** if a shipping tag editor proves that a small in-house
  `Layout` is insufficient. Use SwiftUI Introspect only for a precise,
  OS-version-tested AppKit/UIKit gap.
- **SnapshotTesting** after UI or export formats stabilize enough that snapshots
  express a durable contract.
- **ZIPFoundation** when a multi-file, portable Kitchen Memory archive becomes
  a product requirement.

The native frameworks worth designing seams for, but not prematurely wiring
in, are Image I/O/Core Image/vImage, Vision/VisionKit/PDFKit, Foundation Models,
Core ML/Natural Language, Core Spotlight, Core Transferable, Uniform Type
Identifiers, and SwiftUI document import/export support.

This survey ranks **fit for this project**, not ecosystem popularity. Support
signals below are limited to first-party documentation, repository releases,
tests, manifests, and license files. A release timestamp is evidence of recent
activity, not a guarantee of future maintenance or correctness.

## Project constraints that govern every choice

- `KitchenKit` is the one business framework. `Domain`, `Import`, `Logic`, and
  `Persistence` are internal responsibility areas, not new framework products
  ([implementation architecture](../implementation-architecture.md)). A
  package should sit behind a narrow `KitchenKit` adapter unless it is purely a
  presentation concern in an app target.
- Imported source evidence is retained and transformations remain explainable.
  External image loading is visible and controllable, and the initial parse
  must not bulk-fetch media ([web import contract](../web-import.md)).
- Assistance must be capability-based and replaceable. Original input remains
  available; proposed edits are visible, reversible, and optional
  ([AI policy](../../AI.md)).
- Folders locate a recipe in zero or one primary hierarchy; tags classify it
  many-to-many. A UI library must not redefine those domain semantics.
- The app collects no analytics, diagnostics, or recipe content. Logging and
  support artifacts must respect the project's no-data posture
  ([privacy policy](../privacy.md)).
- The source is `GPL-3.0-only`. Every package still needs a license and notice
  review before adoption ([licensing decision](../adr/0002-gpl-3-only.md)). GNU's
  compatibility guidance describes GPLv3 as compatible with Apache License 2.0
  and permissive Expat/MIT-style licenses, but this is a screening aid rather
  than legal advice ([GNU compatibility guide](https://www.gnu.org/licenses/license-compatibility.en.html)).
- A dependency change requires source, release, license, privacy, product,
  transitive-dependency, executable, resolved-file, SBOM, and signed-product
  review under the existing inventory procedure
  ([dependency inventory procedure](../../DEPENDENCIES.md)).

## Staged shortlist

| Stage | Default | Candidate held in reserve | Concrete adoption trigger |
| --- | --- | --- | --- |
| Current import and session work | Foundation, `URLSession`, current JSON parser | None | Do not expand scope before current session work lands. |
| Richer web import | Current bounded extraction | SwiftSoup | Representative failures require DOM repair, CSS selection, microdata, or safe malformed-HTML recovery. |
| Media | `URLSession` plus Image I/O; explicit user action | Nuke; Kingfisher as alternative | A designed media slice needs cache policy, request coalescing, cancellation, prefetching, or repeated processing. |
| Search and organization | Domain models plus native SwiftUI | Core Spotlight, SwiftUI-Flow, isolated SwiftUI Introspect | Search/folders/tags enter the roadmap and native prototypes reveal a measured gap. |
| Capture and OCR | File/image import plus Vision | VisionKit and PDFKit | A bounded scan/import workflow is specified with correction UX and source preservation. |
| Assistance | Deterministic parsing and native language/vision APIs | Foundation Models; later Core ML or MLX | A narrow optional capability has a quality rubric, availability fallback, privacy disclosure, and reversible review flow. |
| Durable export | Codable/Foundation, `UTType`, SwiftUI import/export | ZIPFoundation | A versioned multi-file interchange format is specified, including limits and migration behavior. |
| Test presentation/serialization contracts | Swift Testing/XCTest and focused assertions | SnapshotTesting | A stable output would be clearer as a reviewed snapshot than as semantic assertions. |

## Decision matrix

| Area | Native-first choice | Third-party candidate | Fit and seam | Primary risk | Do not add until… |
| --- | --- | --- | --- | --- | --- |
| HTTP retrieval | Foundation `URLSession` | Alamofire | Existing `KitchenKit/Import` retriever already has the correct policy seam | A wrapper can obscure redirect, caching, credential, and byte-limit policy | Several broader HTTP workflows need shared auth, retry, upload/download, or instrumentation |
| HTML/XML/JSON-LD | Foundation JSON/XML plus current extractor | SwiftSoup | DOM implementation behind an Import parser protocol | Full trees increase memory/CPU exposure; parser behavior can change extraction | Failing fixtures prove DOM repair or selector support is necessary |
| Image decode/process | Image I/O, Core Image, vImage | None initially | Media service behind an Import/Logic contract; UI owns display | Metadata leakage, decompression bombs, memory/energy use | A media slice defines byte/pixel limits and metadata policy |
| Remote image pipeline | Explicit `URLSession` loads | Nuke; Kingfisher alternative | App/media adapter configured with Kitchen Memory's session and cache policy | Silent network access or persistent cache would violate product expectations | Users can control loading and a measured pipeline problem exists |
| OCR/scanning | Vision, VisionKit, PDFKit | None | Platform capture adapter feeds an Import draft | Device/platform availability and low-confidence text | Review/correction UX and bounded processing budgets exist |
| On-device assistance | Foundation Models, Natural Language, Vision, Core ML | MLX Swift only for a custom-model gap | Provider-neutral capability behind Logic/Import; never embedded in Domain | Model drift, device availability, nondeterminism, resource cost | Evaluation fixtures, fallbacks, disclosure, and reversible suggestions exist |
| Hosted assistance | Direct HTTPS through a controlled service boundary | Provider API/SDK only after architecture review | Replaceable provider adapter; secrets never in the app | User data leaves device; retention, keys, cost, and changing provider terms | Explicit opt-in, server/key custody, retention policy, and provider review exist |
| Tags/chips | SwiftUI search tokens and custom `Layout` | SwiftUI-Flow | App UI only; Domain owns tag identity and relationships | UI package can leak presentation types into business logic | Repeated wrapping/layout complexity survives a native prototype |
| Folders/outlines | `OutlineGroup`; `NSOutlineView` for a Mac-only gap | SwiftUI Introspect only for an isolated bridge | App UI; KitchenKit owns one-primary-folder invariant | OS-backed view details change; cross-platform behavior diverges | Native SwiftUI cannot meet an identified interaction/accessibility need |
| Drag/drop | Core Transferable and SwiftUI drag/drop | None | Transfer representations in app adapter; mutation command in Logic | A drop can bypass validation or imply unsupported multi-folder semantics | Reorder/move semantics and undo behavior are specified |
| Collections/streams | Standard library and AsyncSequence | Swift Collections/Algorithms/Async Algorithms | Import only the specific product into the relevant internal area | Dependency for convenience; subtle ordering/backpressure semantics | A named algorithm/data structure removes tested custom machinery |
| Persistence/sync/search | SwiftData, CloudKit, Core Spotlight | GRDB only as an alternative store | Persistence adapters; Spotlight is a rebuildable projection | Two stores create competing authority and migration burden | A deliberate storage replacement or isolated SQLite artifact is approved |
| Logging | `Logger`, signposts, Xcode diagnostics | swift-log only for a non-Apple runtime | Infrastructure adapter, never recipe payloads | Telemetry creep or sensitive log persistence | KitchenKit must run in a non-Apple CLI/server with a backend abstraction |
| Tests/stubs | Swift Testing, XCTest, custom `URLProtocol` | SnapshotTesting | Test target only | Brittle pixels and large fixtures | Stable visual/text contracts justify snapshot review |
| Files/archives | `UTType`, SwiftUI import/export, Foundation, PDFKit | ZIPFoundation | Versioned import/export adapter | Zip-slip, expansion bombs, nondeterminism, migration | A portable multi-file format and security budgets are specified |

## Networking and HTTP policy

### Keep `URLSession`

Foundation's `URLSession` supports asynchronous data, download, and byte
delivery; delegates cover authentication, redirects, and task lifecycle.
Ephemeral configurations avoid persistent caches, cookies, and credential
storage ([Apple documentation](https://developer.apple.com/documentation/foundation/urlsession)).
That directly matches Kitchen Memory's existing HTTPS-only, ephemeral,
redirect-controlled, bounded streaming retriever and its custom `URLProtocol`
tests. Replacing it would add migration risk without removing the need to own
those policies.

### Hold Alamofire

The existing focused evaluation found Alamofire 5.12.0 to be an actively
maintained MIT-licensed `URLSession` wrapper with useful retry, authentication,
upload/download, validation, and monitoring APIs, but no benefit for the
current single bounded retrieval workflow
([project evaluation](alamofire-for-recipe-retrieval.md)). Keep that conclusion.
Reconsider only if several HTTP capabilities share policy that is becoming
costly to maintain. Even then, keep redirect approval, allowed schemes,
credentials, byte/time budgets, and response validation in a KitchenKit-owned
adapter; never expose Alamofire types in Domain.

## HTML, XML, and JSON-LD

### SwiftSoup: the leading HTML candidate

SwiftSoup is an MIT-licensed, pure-Swift HTML DOM parser with CSS-selector APIs
([repository](https://github.com/scinfu/SwiftSoup),
[license](https://github.com/scinfu/SwiftSoup/blob/master/LICENSE)). Its package
manifest currently declares Swift tools 6.0, Apple deployment targets below
Kitchen Memory's, and no package dependencies
([manifest](https://github.com/scinfu/SwiftSoup/blob/master/Package.swift)). The
project released 2.13.9 on 2026-08-27 after multiple 2026 releases, a strong
recent-maintenance signal
([releases](https://github.com/scinfu/SwiftSoup/releases)).

Do not add it merely to replace the current script scan. Adopt it behind an
Import parser protocol when fixture evidence requires malformed-HTML recovery,
DOM traversal, CSS selection, microdata, or reusable site fallbacks. Enforce
response byte limits before parsing and introduce element/depth/time budgets
around traversal. Preserve the original HTML and JSON-LD evidence so a parser
upgrade cannot silently rewrite recipe history.

### Native XML and bounded JSON-LD

Foundation's event-driven `XMLParser` is sufficient for feeds or simple XML
where a DOM is unnecessary
([Apple documentation](https://developer.apple.com/documentation/foundation/xmlparser)).
Foundation decoding remains the correct first choice for JSON. JSON-LD 1.1 has
substantially broader expansion, compaction, context, and graph semantics than
Kitchen Memory's recipe-oriented subset
([W3C specification](https://www.w3.org/TR/json-ld11/)); do not claim general
JSON-LD conformance unless the importer implements and tests that specification.

Fuzi provides XML/HTML parsing through libxml2 and is MIT-licensed, but its
front-page requirements still cite iOS 8, macOS 10.9, Xcode 8, and Swift 3, and
the repository exposes no current GitHub release history
([repository](https://github.com/cezheng/Fuzi)). Treat it cautiously: SwiftSoup's
pure-Swift implementation and current toolchain/release evidence are the better
fit unless XPath or a measured libxml2 advantage becomes decisive.

## Images and media

### Native processing first

- **Image I/O** reads and writes common image formats, supports incremental
  sources and thumbnails, and exposes image properties/metadata
  ([Apple documentation](https://developer.apple.com/documentation/imageio)). It
  should own bounded decode, downsampling, format validation, and deliberate
  metadata inspection/removal.
- **Core Image** provides a GPU/CPU-backed filter graph; Apple recommends
  reusing `CIContext` rather than repeatedly creating one
  ([framework](https://developer.apple.com/documentation/coreimage),
  [processing guidance](https://developer.apple.com/documentation/coreimage/processing-an-image-using-built-in-filters)).
  Use it for composable filters, orientation, or color work.
- **vImage** in Accelerate provides CPU-vectorized resizing, conversion, and
  image arithmetic
  ([Apple documentation](https://developer.apple.com/documentation/accelerate/vimage-library)).
  Consider it only after profiling identifies a hot CPU transform.

Before media exists, specify maximum source bytes, decoded pixels, dimensions,
frames, pages, cache lifetime, and metadata retention. The importer should
record references during the initial parse, not download every external image.

### Nuke versus Kingfisher

Nuke is an MIT-licensed modular image pipeline with separate NukeUI support,
caching, request coalescing, processing, prefetching, and Swift concurrency
([repository](https://github.com/kean/Nuke),
[license](https://github.com/kean/Nuke/blob/main/LICENSE)). Its current manifest
uses Swift tools 6.0 and declares no external package dependencies for its core
products ([manifest](https://github.com/kean/Nuke/blob/main/Package.swift));
13.2.0 was released on 2026-08-15 after the concurrency-focused Nuke 13 release
([releases](https://github.com/kean/Nuke/releases)). This makes Nuke the leading
candidate for a future Swift-concurrency-native pipeline.

Kingfisher is an equally serious alternative: an MIT-licensed Swift package for
downloading, caching, and processing images, with UIKit, AppKit, and SwiftUI
support and deployment requirements below Kitchen Memory's
([repository and requirements](https://github.com/onevcat/Kingfisher),
[license](https://github.com/onevcat/Kingfisher/blob/master/LICENSE)). Version
8.12.0 was released on 2026-08-25
([releases](https://github.com/onevcat/Kingfisher/releases)).

Evaluate the two with the same synthetic workload only after a media design
exists. Compare cancellation, request policy injection, cache control,
downsampling, animation policy, accessibility behavior, memory/energy use, and
the signed dependency inventory. Whichever wins must use Kitchen Memory's
explicit network and cache policy. Loading a remote URL on view appearance must
never bypass user control or turn initial import into bulk media retrieval.

## OCR and document capture

Vision's `RecognizeTextRequest` produces text observations and exposes language,
recognition-level, and language-correction controls
([Apple documentation](https://developer.apple.com/documentation/vision/recognizetextrequest)).
VisionKit's `DataScannerViewController` combines live camera text/barcode
recognition, but callers must check support and availability and request camera
permission ([Apple documentation](https://developer.apple.com/documentation/visionkit/datascannerviewcontroller)).
For still-document capture on iOS/iPadOS, VisionKit also provides
`VNDocumentCameraViewController`
([Apple documentation](https://developer.apple.com/documentation/visionkit/vndocumentcameraviewcontroller)).
PDFKit can inspect, render, and manipulate imported PDF documents and pages
([Apple documentation](https://developer.apple.com/documentation/pdfkit)).

This should be a platform adapter: iOS can host VisionKit through UIKit while
macOS accepts images/PDFs and runs Vision directly. Both feed the same bounded
Import draft. Preserve the source image/PDF, confidence, and OCR evidence;
require visible correction before committing a recipe revision. Adopt only
with page/byte/pixel/time budgets, cancellation, and synthetic fixtures for
columns, handwriting, low contrast, rotation, and unsupported languages.

## AI and language assistance

### Apple frameworks

The Foundation Models framework provides structured generation and tool calling
through Apple's system models
([framework documentation](https://developer.apple.com/documentation/FoundationModels)).
The on-device model is designed for tasks such as summarization, extraction,
and classification, works offline, and requires an availability check and
fallback on unsupported devices
([WWDC25 session](https://developer.apple.com/videos/play/wwdc2025/286/)). Apple's
2026 update notes make model and prompt behavior across OS versions an explicit
testing concern and add broader model abstractions
([updates](https://developer.apple.com/documentation/Updates/FoundationModels)).

That is a good eventual fit for an optional “propose ingredient fields from
this retained source” capability, not for authority over canonical recipes.
Pin evaluation fixtures to OS/model availability; expose why assistance is
unavailable; preserve input and generated proposal; and make acceptance
field-by-field, visible, reversible, and optional.

Use narrower deterministic/native tools first:

- **Natural Language** for language identification, tokenization, linguistic
  tagging, and named-entity recognition
  ([Apple documentation](https://developer.apple.com/documentation/naturallanguage)).
- **Vision** for image/document understanding and OCR.
- **Core ML** for packaged models that make predictions and, where supported,
  update on device
  ([Apple documentation](https://developer.apple.com/documentation/coreml)).

All belong behind capability protocols in Import or Logic. Domain stores
evidence and accepted results, never a framework session or vendor response
type.

### MLX Swift: only for a measured custom-model gap

MLX Swift is Apple's MIT-licensed array and machine-learning framework for Apple
silicon, with Swift and Metal/C++ implementation layers
([repository](https://github.com/ml-explore/mlx-swift),
[license](https://github.com/ml-explore/mlx-swift/blob/main/LICENSE)). The
project released 0.31.6 on 2026-07-02
([releases](https://github.com/ml-explore/mlx-swift/releases)). Its own build
instructions call out Metal-shader and linking constraints, while the companion
MLX Swift LM package adds model downloading/tokenization dependencies and
tracks its own frequent releases
([MLX Swift instructions](https://github.com/ml-explore/mlx-swift),
[MLX Swift LM](https://github.com/ml-explore/mlx-swift-lm)).

Do not add MLX for experimentation inside the production app. First show that
Foundation Models/Core ML cannot meet a narrow offline capability, then
benchmark model-license compatibility, binary/model size, download integrity,
RAM, latency, energy, thermal behavior, build time, and older-device fallback.
Model weights require a separate license and supply-chain review from the MLX
code.

### Hosted providers: a separate privacy architecture

There is no official OpenAI Swift SDK in OpenAI's generated SDK list; the
officially listed languages are Python, JavaScript, .NET, Java, Go, and Ruby
([OpenAI SDK repository](https://github.com/openai/openai-openapi)). OpenAI also
states that API keys are secrets and must not be exposed in client-side code
([authentication documentation](https://platform.openai.com/docs/api-reference/authentication)).
Its API data controls describe endpoint-specific retention and eligibility
requirements for Modified Abuse Monitoring and Zero Data Retention
([data controls](https://platform.openai.com/docs/models/default-usage-policies-by-endpoint)).

Therefore, neither a community client nor a direct provider REST call belongs
in the app today. Any hosted feature needs a separately approved opt-in product
and privacy design: server-side key custody, explicit preview of transmitted
content, provider/region/retention disclosure, deletion and failure behavior,
cost/rate-limit policy, and a provider-neutral capability adapter. Never send
recipe history or source evidence implicitly.

## Tags, folders, outlines, and drag/drop

Native SwiftUI should establish the interaction before a UI dependency:

- SwiftUI search supports tokenized queries, suggestions, and scopes
  ([search APIs](https://developer.apple.com/documentation/swiftui/search),
  [search guidance](https://developer.apple.com/documentation/swiftui/performing-a-search-operation)).
- The `Layout` protocol supports a project-owned wrapping tag layout when the
  built-in stacks are insufficient
  ([Apple documentation](https://developer.apple.com/documentation/swiftui/custom-layout)).
- `OutlineGroup` renders recursive tree data
  ([Apple documentation](https://developer.apple.com/documentation/swiftui/outlinegroup)).
  A richer Mac-only hierarchy can bridge to `NSOutlineView`
  ([AppKit documentation](https://developer.apple.com/documentation/appkit/nsoutlineview),
  [Apple outline sample](https://developer.apple.com/documentation/appkit/navigating-hierarchical-data-using-outline-and-split-views)).
- Core Transferable defines representations shared by drag/drop, copy/paste,
  and sharing; SwiftUI supplies drag/drop integration
  ([Core Transferable](https://developer.apple.com/documentation/coretransferable),
  [SwiftUI sample](https://developer.apple.com/documentation/swiftui/adopting-drag-and-drop-using-swiftui)).

The app target owns views, focus, selection, menus, and accessibility. KitchenKit
owns tag identity, many-to-many classification, the zero-or-one primary folder
rule, move/reorder commands, validation, and undoable changes. A drop should
call those commands rather than mutate persistence directly.

SwiftUI-Flow is a focused MIT-licensed package of wrapping horizontal/vertical
flow layouts, including line limits and right-to-left layout. It requires iOS
16/macOS 13 and Swift 5.9, and released 3.4.0 on 2026-06-10
([repository](https://github.com/tevelee/SwiftUI-Flow),
[releases](https://github.com/tevelee/SwiftUI-Flow/releases)). It is the best
package-shaped fallback if tag wrapping becomes surprisingly complex, but it
should remain app-UI-only.

SwiftUI Introspect is MIT-licensed and deliberately requires callers to opt in
to supported OS versions because underlying UIKit/AppKit view types can change
([repository and design](https://github.com/siteline/swiftui-introspect),
[releases](https://github.com/siteline/swiftui-introspect/releases)). Use it for
one isolated, tested platform gap—not as a general UI foundation.

Avoid adopting broad SwiftUIX today. It is MIT-licensed and actively developed,
but spans hundreds of controls/extensions and its installation guidance
recommends tracking the `master` branch
([repository](https://github.com/SwiftUIX/SwiftUIX)). That breadth and branch
coupling are poor fits while Kitchen Memory's shared UI is intentionally
provisional.

## Collections, algorithms, and asynchronous sequences

Apple's Swift packages are the first third-party-like tools to consider because
they are narrow, source-available, tested across Swift toolchains, and licensed
under Apache License 2.0 with the Swift Runtime Library Exception:

- **Swift Collections** supplies focused data structures such as ordered
  collections, deque, heap, bitset, and tree-based persistent collections
  ([repository](https://github.com/apple/swift-collections),
  [license](https://github.com/apple/swift-collections/blob/main/LICENSE.txt),
  [releases](https://github.com/apple/swift-collections/releases)).
- **Swift Algorithms** supplies lazy/eager sequence algorithms such as
  combinations, chunks, products, and windows
  ([repository](https://github.com/apple/swift-algorithms),
  [license](https://github.com/apple/swift-algorithms/blob/main/LICENSE.txt)).
- **Swift Async Algorithms** supplies operations such as merge, combineLatest,
  debounce, throttle, and asynchronous channels
  ([repository](https://github.com/apple/swift-async-algorithms),
  [license](https://github.com/apple/swift-async-algorithms/blob/main/LICENSE.txt)).

Import only the product that answers a named need. Examples of valid triggers
are preserving stable user-defined tag order with efficient membership, using
a heap for a measured scheduler, or merging/debouncing several asynchronous
state feeds with defined cancellation/backpressure. A one-off helper is not a
dependency trigger.

## Persistence, sync, and search adjuncts

SwiftData's CloudKit integration already follows Kitchen Memory's personal-sync
direction; Apple's guidance describes automatic model-data sync through the
CloudKit-backed persistent container and its schema constraints
([Apple documentation](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)).
Do not add a second database to “help” it.

Core Spotlight is a useful future **projection**: Apple describes its indexes as
private, stored on-device, and not synchronized between devices
([framework documentation](https://developer.apple.com/documentation/corespotlight)).
Its modern search APIs can support both lexical and semantic in-app search
([search interface guidance](https://developer.apple.com/documentation/corespotlight/building-a-search-interface-for-your-app)).
Adopt with the search slice, index only deliberately selected recipe fields,
and make the index disposable/rebuildable from repository truth. Exclude raw
HTML, OCR sources, and unaccepted assistance.

GRDB is an actively maintained MIT-licensed SQLite toolkit with migrations,
observation, full-text search, Codable records, a privacy manifest, and no
ordinary external package dependency
([repository](https://github.com/groue/GRDB.swift),
[manifest](https://github.com/groue/GRDB.swift/blob/master/Package.swift),
[license](https://github.com/groue/GRDB.swift/blob/master/LICENSE),
[releases](https://github.com/groue/GRDB.swift/releases)). It is a credible
**alternative** persistence engine, not an adjunct to add beside SwiftData.
Revisit only after an ADR deliberately replaces the store or specifies a
separate portable/search SQLite artifact with one-way rebuild semantics.

Defaults already owns the small app-preference role. Adding another preferences
package would duplicate the current dependency without a demonstrated gap.

## Logging and diagnostics

Use Apple's unified logging APIs and signposts for local diagnosis
([logging documentation](https://developer.apple.com/documentation/os/logging)).
Apple's privacy guidance distinguishes public, private, and sensitive log data
and documents redaction behavior
([OSLog privacy](https://developer.apple.com/documentation/os/oslogprivacy),
[message guidance](https://developer.apple.com/documentation/os/generating-log-messages-from-your-code)).
Kitchen Memory should be stricter: log static event codes, bounded counts,
durations, and typed error classes—never recipe text, recipe/source URLs,
identifiers, account data, OCR text, model prompts, or responses.

SwiftLog is an Apache-2.0 logging API that delegates output to an installed
backend
([repository](https://github.com/apple/swift-log),
[license](https://github.com/apple/swift-log/blob/main/LICENSE.txt)). It becomes
useful only if KitchenKit gains a supported non-Apple CLI/server runtime that
cannot use unified logging directly. It adds no value to the current Apple-only
applications.

Do not add analytics, crash-upload, session-replay, or remote telemetry SDKs
under a diagnostics label. Any such system would be a new data-collection
product decision requiring explicit consent, privacy documentation, inventory,
and a demonstrated inability to support users locally.

## Testing, snapshots, and network stubbing

Swift Testing supports parameterized tests, traits/tags, concurrency, and
parallel execution
([Apple documentation](https://developer.apple.com/documentation/testing)).
Apple recommends Swift Testing for new unit/integration tests while XCTest
remains necessary for UI and performance tests, and the two can coexist
([Xcode testing guidance](https://developer.apple.com/documentation/xcode/adding-tests-to-your-xcode-project)).
That permits gradual, evidence-driven use; it does not justify rewriting the
current exact-coverage XCTest suite.

The current custom `URLProtocol` test double is still the best network stub for
the single `URLSession` retriever because it exercises Foundation's real task
and delegate behavior. Add no network-stubbing package until multiple clients
duplicate material infrastructure.

SnapshotTesting is an MIT-licensed test-only package that can snapshot images,
text, data, Codable values, and custom formats. Its repository warns that the
package should be linked only to test targets; release 1.19.4 shipped on
2026-07-28
([repository](https://github.com/pointfreeco/swift-snapshot-testing),
[license](https://github.com/pointfreeco/swift-snapshot-testing/blob/main/LICENSE),
[releases](https://github.com/pointfreeco/swift-snapshot-testing/releases)).
Adopt after the shared UI stabilizes, or sooner for a stable textual export/
normalization contract. Pixel snapshots must pin device, OS, locale, dynamic
type, appearance, and animation state; they complement semantic assertions and
identifier-driven UI smoke tests rather than replacing them.

Quick/Nimble-style assertion frameworks are not indicated: XCTest and Swift
Testing already express current tests without another DSL, dependency graph,
or migration.

## Archives, export, and file formats

Uniform Type Identifiers supplies declared content types and conformance
relationships for import/export
([Apple documentation](https://developer.apple.com/documentation/uniformtypeidentifiers)).
SwiftUI's document APIs support readable/writable file and package formats and
document import/export workflows
([Apple documentation](https://developer.apple.com/documentation/swiftui/documents)).
Use those presentation hooks without turning this library-style application
into a document-based app.

Start a future interchange format as a versioned manifest with deterministic
encoding, explicit provenance, stable identifiers, and lossless unknown fields.
Use a directory/file package if that meets interoperability needs. If a single
portable ZIP becomes a requirement, ZIPFoundation is a focused MIT-licensed
Swift API for reading, creating, and modifying ZIP archives using Apple's
compression facilities, with progress/cancellation support and no external
package dependencies
([repository](https://github.com/weichsel/ZIPFoundation),
[license](https://github.com/weichsel/ZIPFoundation/blob/master/LICENSE)).

Before adopting it, recheck the latest tag/toolchain and test path traversal,
absolute/symlink entries, duplicate names, entry count, compressed and expanded
size, compression ratio, cancellation, partial output cleanup, deterministic
ordering/timestamps, and migration. Archive parsing is an Import adapter; it
must never write unchecked paths or bypass immutable revision creation.

## Candidates to avoid or treat cautiously

| Candidate/class | Posture | Reason |
| --- | --- | --- |
| Alamofire today | Hold | Strong package, but duplicates an already-small and security-specific `URLSession` seam. |
| Fuzi | Caution | Useful XPath/libxml2 functionality, but public toolchain guidance and release signals are stale compared with SwiftSoup. |
| Nuke plus Kingfisher | Exclude combination | They solve the same pipeline problem; two caches and request models create policy ambiguity. |
| SwiftUIX | Hold | Broad UI surface and recommended branch tracking create coupling while UI is provisional. |
| SwiftUI Introspect as a foundation | Caution | It relies on OS-specific UIKit/AppKit backing details; use only for one measured gap. |
| GRDB beside SwiftData | Exclude | Creates dual persistence authorities, migrations, observation, and sync reconciliation. |
| MLX/MLX Swift LM without a benchmark | Hold | Large code/model/resource and supply-chain surface before a custom-model requirement exists. |
| Community hosted-AI SDKs | Hold | No provider-neutral architecture, official support assurance, or solved key/privacy model today. |
| Analytics/crash/session-replay SDKs | Exclude by default | Networked collection conflicts with the no-data posture and requires a separate product decision. |
| General “utility” or broad UI packages | Caution | Large API/dependency surface without a named capability makes replacement and auditing harder. |

Also exclude any package with an unresolvable license, undeclared executable or
plugin, opaque binary artifact, unexpected telemetry/network behavior, or an
unreviewable dependency tree, regardless of functionality.

## Adoption checklist

For any future proposal, record all of the following in its focused decision
note or ADR:

1. The failing fixture, benchmark, accessibility need, or repeated code that
   proves the native implementation is insufficient.
2. The narrow capability boundary and whether it lives in a KitchenKit adapter
   or only in an app UI target.
3. Current release, supported Swift/Xcode and deployment targets, repository
   activity, tests/CI, maintainers, license, notices, privacy manifest, products,
   transitive dependencies, plugins/executables, and binary artifacts.
4. GPL-3.0-only compatibility reviewed by the appropriate person; do not infer
   legal approval from this survey.
5. Network, cache, filesystem, metadata, prompt, model, and diagnostic behavior
   under Kitchen Memory's privacy rules.
6. Deterministic fixtures for failure, cancellation, resource limits, upgrades,
   and dependency removal/replacement.
7. Updated `Package.resolved`, `DEPENDENCIES.md`, SBOM, privacy documentation if
   applicable, inventory tests, exact coverage, and signed-product inspection.

The outcome should be a smaller Kitchen Memory-owned interface, not a package's
API spreading through Domain. If the package cannot be removed without
rewriting product concepts, its seam is too deep.
