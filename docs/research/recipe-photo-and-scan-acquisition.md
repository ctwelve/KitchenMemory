# Recipe photograph and scan acquisition

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: Research complete; proposed experiments and follow-ups, no OCR shipped
- Researched: 2026-09-06
- Origin: [Issue #94](https://github.com/ctwelve/KitchenMemory/issues/94)
- Scope: A family recipe card, printed or handwritten, becomes a recoverable Recipe Editing Draft without losing its source or disguising guesses.

## Competing hypotheses, before choosing a direction

These are hypotheses to test, not measured outcomes.

| Hypothesis | Plausible benefit | Evidence that would reject it |
| --- | --- | --- |
| H1: Saved image plus ordinary Vision text recognition and manual grouping is enough for the first useful slice. | Small, private, understandable pipeline; handwriting can remain a photograph with optional transcription. | Correction takes as long as manual transcription on clean printed cards, or important quantity errors routinely escape review. |
| H2: Vision document recognition materially improves structure over line OCR. | Native paragraph/list/table evidence avoids homemade column inference. | Paired corpus shows no correction-time improvement, or ordering errors increase and are not exposed. |
| H3: Live scanning is the best default acquisition. | Immediate positioning feedback reduces poor captures. | More canceled captures, omitted margins, or slower acquisition than taking/selecting a photograph; unavailable hardware excludes an otherwise supported device. |
| H4: A focused second OCR engine earns its dependency cost. | Different language/model strengths might fill a demonstrated native gap. | No meaningful held-out improvement after including binary/model size, latency, integration, maintenance, and licensing costs. |
| H5: Generative image interpretation is necessary. | Might interpret difficult cursive or layouts. | Ordinary OCR plus review succeeds; or generated quantities/ordering cannot be traced to pixels and correction burden rises. |

## Recommendation

Prototype H1 and H2 behind one KitchenKit-owned evidence boundary. Start with selected images and an explicit review; add the native document camera as an optional acquisition adapter. Preserve the acquired source before recognition, retain every recognition run independently, and treat structured Recipe fields as reviewable interpretations. Manual transcription and image-only retention must remain useful when OCR fails. Do not make generative AI, Apple Intelligence eligibility, or a live scanner prerequisites.

This follows [ADR 0014](../adr/0014-prefer-native-capabilities-and-evidence-based-dependencies.md). The decision is conditional on the experiments below, rather than an assertion that Apple OCR reads every family recipe card reliably.

## Documented capabilities and limits

| Surface | Verified capability | Consequence for this project |
| --- | --- | --- |
| PhotosUI `PhotosPicker` | Available on iOS, iPadOS, and macOS; the out-of-process picker gives the app only selected photos, without broad library authorization. [Apple privacy session](https://developer.apple.com/videos/play/wwdc2025/246/) | Preferred selection path. Loading a selection can fail or require obtaining a cloud-backed item; distinguish selection from durable acquisition. |
| Picker representation | `.current` plus generic image content avoids automatic format conversion; requesting a specific JPEG type can still transcode. [Apple picker session](https://developer.apple.com/videos/play/wwdc2023/10107/) | Preserve the exact representation actually delivered. Do not promise the camera sensor original or all Photos edits/metadata. Record representation and acquisition method; never silently recompress the preserved bytes. |
| VisionKit document camera | `VNDocumentCameraViewController` provides camera UI and ordered scanned page images; runtime support must be checked. [Document camera](https://developer.apple.com/documentation/visionkit/vndocumentcameraviewcontroller) | iOS/iPadOS acquisition, not the native macOS path. The returned scan is the original *acquired scan*, not an uncropped sensor photograph. If retaining the full card/margins is essential, offer ordinary photo/file selection. |
| Live data scanner | `DataScannerViewController` recognizes camera text/codes and can capture a high-resolution photo. It requires camera permission and both support/availability checks. [Scanner](https://developer.apple.com/documentation/visionkit/datascannerviewcontroller) | Optional iOS/iPadOS convenience, not the authoritative transcript. [Hardware support](https://developer.apple.com/documentation/visionkit/datascannerviewcontroller/issupported) requires A12 Bionic or later and explicitly excludes visionOS; do not apply this requirement to all Vision OCR. |
| Native macOS capture | AppKit documents Continuity Camera integration. [Apple integration guide](https://developer.apple.com/documentation/appkit/supporting-continuity-camera-in-your-mac-app) | A later optional adapter. Selected files/photos remain the baseline without a nearby eligible phone; prototype permissions, delivered representation, page order, cancellation, and device availability before promising parity. |
| Vision text recognition | On-device image text recognition has accurate/fast modes, optional correction, preferred languages and runtime supported-language queries. [Apple recognition guide](https://developer.apple.com/documentation/vision/recognizing-text-in-images) | Use accurate mode as the experimental baseline. Capture its settings; compare correction enabled/disabled because an ingredient or family name can be “corrected” incorrectly. Runtime language support depends on request configuration/revision. |
| Recognition evidence | Candidates expose strings, normalized confidence, and range geometry; top-candidate requests are bounded to ten. [RecognizedText](https://developer.apple.com/documentation/vision/recognizedtext), [candidate API](https://developer.apple.com/documentation/vision/recognizedtextobservation/topcandidates(_:)) | Preserve returned strings and scores verbatim. Confidence is a model score, not a calibrated probability that a quantity or instruction is correct. An absent candidate/box is explicit absence. |
| Vision document recognition | `RecognizeDocumentsRequest` adds containers, paragraphs, lists and tables. Apple described one document observation per image and 26 recognition languages in WWDC25; word-level output is not universal across scripts. [Apple document session](https://developer.apple.com/videos/play/wwdc2025/272/) | Valuable H2 candidate, not proof that two cards in one photo are one Recipe. Preserve the hierarchy as model evidence; person confirms card boundaries and page/step order. Do not turn a dated language count into a product promise. |

The repository currently targets iOS/macOS 26.0. Read-only inspection of the installed Xcode MacOSX SDK `Vision.swiftinterface` confirmed `RecognizeTextRequest` availability at macOS 15/iOS 18 and `RecognizeDocumentsRequest` at macOS/iOS 26. No build or runtime experiment was performed for this research. Verify the selected SDK and runtime again in the implementation slice; platform availability is not an accuracy or hardware-performance guarantee. [Project settings](../../KitchenMemory.xcodeproj/project.pbxproj), [document API](https://developer.apple.com/documentation/vision/recognizedocumentsrequest).

### Handwriting and current OS 27 developments

Public evidence does not establish reliable recognition of arbitrary historical cursive in every supported language. Test raster handwriting with the same image-recognition adapters; label the result unreviewed and preserve the image when no readable text emerges. Do not substitute a claim about Apple Pencil input for photographed handwriting support.

WWDC26 introduces `PKStrokeRecognizer` on iOS, iPadOS, macOS and visionOS 27. It works from drawings/strokes, exposes supported languages and recognizer version, and runs on device with an included offline model. The session describes 29 languages and a Simulator restriction to Latin-character languages. This is a promising future *authored ink* capability, but not a documented raster-to-stroke conversion or photo OCR replacement, and it lies above this project's OS 26 baseline. [Apple PencilKit session](https://developer.apple.com/videos/play/wwdc2026/203/).

WWDC26 also describes Foundation Models image input with optional Vision OCR tools. That is a separate optional interpretation hypothesis, not a reason to remove ordinary OCR or to claim the OS 26 configuration has these capabilities. Any experiment must separately verify supported OS, device/model availability, privacy behavior and language support. [Apple image understanding session](https://developer.apple.com/videos/play/wwdc2026/237/).

### Focused third-party and project-owned alternatives

Tesseract is an Apache-2.0 OCR engine with maintained first-party documentation, model choices, and a broad language/script catalog. It is a reasonable *comparison candidate*, not an adopted Swift dependency or proven cursive solution. A mobile integration would own native wrapping, image dependencies, model distribution, memory, cancellation and license/SBOM review. Its [manual](https://tesseract-ocr.github.io/tessdoc/), [source repository](https://github.com/tesseract-ocr/tesseract), and [quality guidance](https://tesseract-ocr.github.io/tessdoc/ImproveQuality.html) are the evidence owners. Adoption requires a pinned-version audit and demonstrated held-out improvement for a specific native failure cohort; no package was installed or benchmarked here.

A project-owned component should own acquisition budgets, immutable evidence, review state and conservative field mapping, not train a new general OCR engine. Simple grouping can be deterministic and testable, but must retain competing orderings when geometry is ambiguous. A broad generative stack is deferred unless H5 survives a separate privacy and correction-cost experiment.

## Proposed evidence and publication boundary

The existing [web-import workflow](../web-import.md) already separates captured evidence, device-local review, Recipe Editing Draft, and explicit Recipe Save. Current [RecipeSourceCapture](../../KitchenKit/Domain/RecipeSourceCapture.swift) is specifically JSON-LD, while [RecipeMedia](../../KitchenKit/Domain/RecipeContent.swift) currently has hero/thumbnail/gallery roles. Neither should be overloaded with image OCR masquerading as JSON-LD or a decorative hero image. The following names describe proposed storage responsibilities, not newly accepted Domain terms:

1. **Acquired source:** immutable delivered bytes, content digest, media type, dimensions, orientation metadata, acquisition method/time, page identity/order as acquired, and an honest representation description. Retain full selected bytes before preprocessing; scanner-delivered image encoding is recorded as such. Display derivatives never replace this evidence.
2. **Recognition run:** source digest/page ID, engine/request revision, OS build, recognition settings/languages actually requested, exact returned strings, ordered observations, candidates/scores, normalized geometry with coordinate convention, and complete/partial/canceled/failed status. Store language identity only when provided or explicitly selected; an inferred language is labeled inferred. Exact OCR means exact *engine output*, not exact source truth. Do not normalize Unicode, whitespace, fractions or punctuation in the retained strings.
3. **Interpretation:** proposed fields referencing run/observation/string ranges; proposed grouping/order; missing/ambiguous/unreadable concerns; extractor version. An added quantity, ingredient, instruction, attribution or ordering has no accepted authority until reviewed. Never fill a gap merely because a conventional recipe would contain it.
4. **Review decisions:** user corrections and selected alternatives separate from original output, source-region associations, reviewed/unresolved state and accepted page/card boundaries. Rerunning OCR creates new evidence and a comparison; it never overwrites earlier output or the person's corrections.
5. **Publication:** acceptance produces a recoverable local draft. Recipe Save freezes a stable retryable command and publishes the reviewed Revision with retained source references only after its required source bytes are durably available. Unknown source-evidence versions remain retained and unavailable for reinterpretation, not silently dropped.

Use native acquisition in the app; place recognition behind a narrow adapter returning serializable KitchenKit values. Let KitchenKit own evidence validation, review transitions, publication and retention rules. Vision, UIKit, AppKit, PhotosUI and SwiftData types do not become Domain vocabulary. Add a deliberately versioned source-evidence codec and dependency edges through the normal immutable-schema/migration review; this note does not select a production CloudKit schema. [ADR 0004](../adr/0004-apple-persistence-and-portability.md).

Proposed initial admission budgets for measurement: 10 pages, 25 MiB encoded per page, 100 MiB total, 40 megapixels per page, one decode/recognition at a time, 200 KiB UTF-8 OCR output per page and at most three candidates per observation. These are tunable product limits, not Apple API limits. Reject an oversized acquisition visibly before accepting it; never truncate an apparently complete transcript. Preserve already accepted pages on later failure. Derive bounded OCR-resolution images, record all transforms, and retain originals separately. Deadline/cancellation stops publication of a stale result; incremental saves survive process death. Measure peak decode/recognition memory before fixing shipping ceilings.

## Review behavior

| Input or uncertainty | Required proposed behavior |
| --- | --- |
| Low confidence or conflicting candidates | Show original region plus selectable text alternatives and an uncertainty label. Numeric tokens receive explicit review even when confidence is high. |
| No text, unreadable, occluded or missing edge | Keep the source and any partial evidence; offer rescan, manual transcription or keep for later. Never call empty OCR an empty recipe or manufacture text. |
| Rotated, skewed or perspective-distorted | Preserve original orientation and bytes. Record derivative transforms and offer rotation/crop controls with an accessible alternative; recognition from each chosen transform is a distinct run. |
| Two cards or recipes in one frame | Ask the person to split/select regions. Retain shared original plus region references; do not silently concatenate recipes or discard margins. |
| Multiple pages/front and back | Preserve acquisition order separately from reviewed order. Provide page labels, reorder controls, duplicate warnings and missing-page concerns; never infer a missing instruction as fact. |
| Mixed print and handwriting, marginal notes or strike-through | Keep spatial evidence, let the person classify annotations and exclusions. A crossed-out quantity and its replacement remain visible; “which wins” is a review decision. |
| Mixed/unsupported languages | Let people choose supported language settings per page/region and retry. Preserve original scripts; no automatic translation or unit conversion. Unsupported remains an explicit limitation, not a request to a cloud service. |
| Ambiguous quantities, fractions or ordering | Keep literal text such as `1/2`, `½`, `l`, or `1`; highlight mismatch and retain competing interpretations. Structured quantity remains absent until supported or confirmed. |

## Privacy, retention and accessibility

These are proposed requirements grounded in [PRIVACY.md](../../PRIVACY.md), the [draft contract](../web-import.md), [Recipe deletion](../recipe-disposition.md), and [dependency-aware retention](../recipe-retention.md).

- Acquisition/review stays device-local outside CloudKit, like existing drafts. Explain before Recipe Save which original images and OCR evidence will be retained with the Recipe and synchronized only when the person's existing private-iCloud setting permits. Recognition itself does not upload images. System Photos or file-provider acquisition may fetch the selected item; do not falsely promise the whole acquisition path is network-free.
- Preserve bytes in private application storage with owner-scoped manifests, atomic file installation and digest verification. References alone or temporary picker URLs are not durable evidence. Do not expose thumbnails/text in diagnostics, shared caches or public filenames. Confirm local backup policy separately; “device-local” does not mean excluded from OS backups.
- Original photos may include location metadata, handwriting, names, addresses and background content. Disclose that retained originals can contain these. A sanitized export is a separate derivative and must not silently replace the original. Do not infer or publish attribution from incidental handwriting or metadata.
- Canceling a picker before acceptance discards only temporary app copies. Confirmed draft Discard releases that draft's references; saved Recipe deletion follows restoration windows, not immediate physical erasure. Media referenced by another Revision, retained draft, source-evidence object or Cooking Session stays pinned. Incomplete/unreadable dependency evidence blocks pruning. Do not weaken the agreed Session-preservation boundary; a later policy may authorize deeper cleanup.
- Private iCloud delivery may be partial: distinguish unavailable source bytes from corruption and from a completed sync. Do not delete local originals because a general successful sync event occurred. Test interrupted delivery, restore, delayed replicas, reset and retry before shipping retention.
- Keep images/OCR out of telemetry and public debugging material. Private family cards must never enter fixtures, issue comments or commits; recreate defects using synthetic material. No public cloud OCR fallback is implied.
- Offer selectable native text alongside magnifiable images, with page/region names, explicit uncertainty and review state read by VoiceOver. Every crop, rotation, split, reorder and alternative choice needs keyboard and accessible control equivalents; color or drag alone is insufficient. Preserve text language for speech where known, Dynamic Type, focus after correction and resumable progress. Apple's [reading accessibility guidance](https://developer.apple.com/videos/play/wwdc2026/219/) favors standard selectable text and continuous navigation; OS 27-only additions need availability guards, not a raised baseline by accident.

## Synthetic corpus and falsifiable prototypes

No corpus was generated and no OCR, performance or usability experiment was run in this ticket. The following is an implementation-ready evaluation plan, not validation evidence.

Create 24 original fictional cards (four each in en-US, fr-CA, es-MX, de-DE, it-IT and a mixed-script cohort). Add separately labeled challenge cards for Arabic/right-to-left, Hindi/Devanagari, Chinese, Japanese and unsupported runtime languages; inclusion does not promise recognition support. A fluent reviewer checks non-English ground truth. Use only invented recipes without personal details, and licensed fonts whose redistribution terms are recorded. Font-rendered cursive is synthetic print, not evidence of real handwriting performance: add volunteered handwriting of these same fictional texts with explicit fixture permission, or report handwriting as unevaluated.

For each card retain original generated/consented source, exact Unicode transcript, line/region polygons, partial ordering constraints, ingredient/instruction/attribution mappings, and explicit intentionally missing/ambiguous fields. Derive reproducible rotations, perspective, shadows, blur, glare/occlusion, JPEG damage, low contrast, tiny text, two-card scenes and multi-page variants using recorded seeds/transforms. Split by base card and writer so transformed siblings never cross development/held-out splits.

| Measure | Definition and decision use |
| --- | --- |
| Preservation | Byte digest equality for acquired sources and exact Unicode equality for stored engine output after save/relaunch/export/reimport. Required: 100%; any loss blocks adoption. |
| Recognition | Character error rate using a documented Unicode segmentation policy; word error rate only where word segmentation is meaningful. Report substitutions/deletions/insertions separately and per language/input cohort. |
| Critical tokens | Exact match for quantities, units, temperatures, times, negation and attribution; separately count confidently wrong tokens. Averages must not hide a changed amount. |
| Structure | Ingredient/instruction boundary precision/recall, source-region coverage, and pairwise ordering accuracy against allowed partial orders. Separately score card splitting and page assignment. |
| Correction cost | Paired time, edits and navigation actions to a correct draft versus manual entry, including accessibility users and abandoned reviews. Report median and tail, not only successful examples. |
| Failure honesty | Fraction of known unreadable/missing/ambiguous cases flagged, false reassurance rate, unsupported-field invention count and accepted source-unlinked suggestions. Required: zero silently invented accepted facts. |
| Resource behavior | Median/p95 latency, peak memory, disk expansion, cancellation latency and recoverability under termination, low storage and unavailable selected cloud items, by physical device/OS. |

P1 compares accurate line OCR (correction off/on) with document recognition on the same held-out images and a manual-entry baseline. Pre-register a provisional usefulness gate: at least 25% lower median correction time for clean printed cards, no worse p95 than manual entry, and all preservation/honesty gates satisfied. Report handwriting and each language separately; failing one cohort narrows advertised scope instead of inviting fabricated output. Use small confidence bins to measure observed error and choose review thresholds on development data only.

P2 compares selected photographs against document camera and optional live scanner using the same synthetic physical cards. Reject a default scanner if capture losses/cancellations increase or unsupported hardware loses the fallback. Explicitly compare returned margins, representation and page order.

P3 exercises evidence/draft/publication failure boundaries with synthetic data: kill after source installation, OCR completion, acceptance and frozen Save; duplicate retry, orphan cleanup, partial personal-iCloud media delivery and retained Session references. Every accepted source and correction must remain reconstructible; no source deletion based only on elapsed time or a coarse sync observation.

Only if P1 identifies a specific unsolved cohort should P4 compare pinned Tesseract or separately authorized generative interpretation. Keep the same evidence/review contract and evaluate total integration cost. Stop if improvement is not meaningful, privacy changes are unacceptable, or invented content cannot be surfaced reliably.

## Narrow follow-up slices

1. **Versioned image-source evidence and local recovery:** implement immutable bytes/manifests, recognition-run codec and draft references with admission bounds; prove crash/retry/round-trip preservation. No OCR UI or sync schema promotion.
2. **Selected-image acquisition and manual review:** Photos/file adapters, page/card review, accessible corrections and image-only drafts; prove cancel/discard/resume and exact delivered-byte preservation.
3. **Vision comparison harness:** synthetic corpus and P1, runtime language matrix and physical-device results. Select line/document mode only from recorded evidence; no generative prerequisite.
4. **Reviewed OCR to Recipe Save:** conservative source-linked field proposals, uncertainty/correction UI and atomic publication with private media; explicitly review schema, privacy disclosure and retention edges before shipping sync.
5. **Optional capture adapters:** document camera first, live scanner/Continuity Camera only when P2 supports their benefit and fallback/accessibility remain complete.

These are proposed issue boundaries, not newly opened tracker tickets. Research satisfies #94 without adopting a dependency, promising arbitrary handwriting accuracy, changing product authority, or claiming experiments that have not happened.
