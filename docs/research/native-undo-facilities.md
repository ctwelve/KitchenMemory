# Native undo facilities

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: Primary-source evidence and adoption constraints; not an accepted product policy
- Researched: 2026-09-25
- Scope: Foundation, SwiftUI, AppKit, and UIKit support for #191

## Finding

`UndoManager` supplies native action stacks, grouping, naming, and responder
integration. It does not decide whether a synchronized domain operation remains
safe to reverse. Its registration handler is a synchronous, nonthrowing
`@MainActor` closure returning `Void`; the public interface has no asynchronous
acceptance callback or failure result. A Kitchen Memory adapter must therefore
make domain acceptance and invalidation explicit instead of treating invocation
of a native undo handler as proof that reversal succeeded.
[Registration contract](https://developer.apple.com/documentation/foundation/undomanager/registerundo(withtarget:handler:))

The recommendations below are deductions from these API contracts. No runtime
prototype, multiwindow validation, or mobile gesture test was performed for this
record. The installed Foundation SDK header and Swift interface were inspected
to corroborate the handler signature, grouping, removal, and localization APIs.

## Verified platform behavior

| Facility | Verified behavior | Consequence for adoption |
| --- | --- | --- |
| Undo and redo registration | Operations registered while undo is executing become redo operations; those registered during redo become undo operations. An ordinary new registration clears the redo stack. Groups, rather than individual callbacks, are the units reversed. [Apple's undo architecture](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/UndoArchitecture/Articles/UndoManager.html) | Register an accepted inverse during the native callback when synchronous acceptance is possible. A deferred task does not preserve the documented undo-in-progress registration context. |
| Grouping | `groupsByEvent` defaults to `true`, grouping around each run-loop pass. With it disabled, callers must explicitly close groups before undo. `undo()` can close the outer group, but raises an inconsistency exception when multiple groups remain open. [Automatic grouping](https://developer.apple.com/documentation/foundation/undomanager/groupsbyevent), [undo](https://developer.apple.com/documentation/foundation/undomanager/undo()) | A UI event is not a domain transaction. Prove logical-command grouping without changing native text clients' grouping behavior. Do not leave groups open across asynchronous work. |
| Availability | `canUndo` reports whether actions exist, not whether their domain preconditions still hold; it does not even guarantee open groups permit an immediate call. [canUndo](https://developer.apple.com/documentation/foundation/undomanager/canundo) | Revalidate the current authoritative state when executing a compensation. Native menu availability alone cannot certify safety after synchronization. |
| Invalidation | `removeAllActions()` clears both stacks and reenables registration. `removeAllActions(withTarget:)` removes both undo and redo operations addressed to that target, without reenabling registration. [All actions](https://developer.apple.com/documentation/foundation/undomanager/removeallactions()), [Target actions](https://developer.apple.com/documentation/foundation/undomanager/removeallactions(withtarget:)) | Public removal is manager-wide or target-wide, not a predicate over domain command identifiers. One adapter target means invalidating that target's entire history. Do not clear unrelated native text history accidentally. |
| Lifetime | Closure registration does not strongly retain its target; captured references can still cause retain cycles. [Registration contract](https://developer.apple.com/documentation/foundation/undomanager/registerundo(withtarget:handler:)) | Keep a defined adapter lifetime and clear its registrations before teardown; do not leave callbacks referring to retired scenes or Kitchen state. |
| SwiftUI | `EnvironmentValues.undoManager` is a read-only optional value; unsupported environments return `nil`, where registration may be skipped. [SwiftUI environment](https://developer.apple.com/documentation/swiftui/environmentvalues/undomanager) | Read the manager from the relevant scene/view environment. Do not assume a process-wide manager or a writable environment key for replacing it. |
| AppKit routing | `NSResponder.undoManager` asks the next responder. A window asks its delegate for a manager and otherwise creates one. A text view can use a delegate-provided manager instead. [Responder property](https://developer.apple.com/documentation/appkit/nsresponder/undomanager), [AppKit undo architecture](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/UndoArchitecture/Articles/AppKitUndo.html) | A custom app command must coexist with the focused text control's manager. Multiple windows sharing a model do not automatically acquire one shared history. |
| UIKit routing | The request finds the nearest manager up the responder chain; windows provide a shared manager. Responders can supply their own. `UITextField` has its own manager, cleared when the field resigns first responder. [UIResponder undoManager](https://developer.apple.com/documentation/uikit/uiresponder/undomanager) | Test both editing focus and non-text focus. Text-history lifetime is not an app-history contract. |
| Action names | `setActionName(LocalizedStringResource?)` resolves names using the current locale and supports inflection; `nil` removes the name. Apple recommends names describing the person's action. [Localized action names](https://developer.apple.com/documentation/foundation/undomanager/setactionname(_:)-cci9), [Action naming guidance](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/UndoArchitecture/Articles/AppKitUndo.html) | Use localized intent names such as Move Recipe, rather than low-level storage names or a manually concatenated English “Undo” prefix. |
| System affordances | macOS expects Edit-menu Undo/Redo with Command-Z/Shift-Command-Z. iOS/iPadOS support three-finger undo/redo gestures and shake; Apple advises preserving standard gestures and showing results clearly. Dedicated toolbar buttons are conditional, not universally required. [Undo and redo HIG](https://developer.apple.com/design/human-interface-guidelines/undo-and-redo), [Gesture HIG](https://developer.apple.com/design/human-interface-guidelines/gestures) | Validate keyboard, touch, accessibility, focus, and visible feedback separately. A registered callback alone is not mobile acceptance evidence. |

## Limits relevant to Kitchen Memory

**Compensation is a new domain intention.** Foundation can call code that sends
an inverse request, but cannot supply Recipe ancestry, observed deletion consent,
Session lifecycle rules, or conflict checks. Its own overview includes network
requests as a possible use; this is not a promise of distributed rollback or
failure-aware stack transactions.
[UndoManager overview](https://developer.apple.com/documentation/foundation/undomanager)

**Failure needs an app policy.** A callback cannot return rejection to the native
manager. If local persistence fails or domain validation rejects compensation,
the app must report the failure and deliberately decide what history remains.
Do not register redo for a compensation that never became accepted, or call a
later retry's registration an automatic native redo transition. The API supplies
no documented operation to restore exactly the consumed group at its previous
stack position. This is an interface limitation, not evidence that a particular
recovery adapter has been tested.
[Registration contract](https://developer.apple.com/documentation/foundation/undomanager/registerundo(withtarget:handler:)),
[UndoManager API surface](https://developer.apple.com/documentation/foundation/undomanager)

**Group atomicity is separate from domain atomicity.** Several callbacks in one
native group do not establish one atomic database write or make partial failure
safe. Prefer one domain operation with a complete precondition check for a
multi-object action; independently prove its persistence boundary. This follows
from the platform's description of a group as collected undo operations.
[Undo groups](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/UndoArchitecture/Articles/UndoManager.html)

**Native history is not durable history.** The reviewed interface records
callbacks and exposes neither a serialized stack format nor synchronization
semantics. Do not promise restoration after relaunch or transfer between devices
based on `UndoManager`. Durable retry records, if required by a later policy,
would be separate app/domain data rather than serialization of native callbacks.
[UndoManager API surface](https://developer.apple.com/documentation/foundation/undomanager)

**Automatic storage undo is not semantic undo.** SwiftData can attach the window
manager to a container's main context and register model mutations. This does not
establish a valid inverse for immutable Recipe revisions or Session facts. The
recommended direction is domain compensation through Logic, leaving storage
rollback as an implementation concern, not enabling `isUndoEnabled` as an
app-wide shortcut.
[SwiftData automatic undo](https://developer.apple.com/documentation/swiftdata/reverting-data-changes-using-the-undo-manager)

## Proposed proof before adoption

1. Demonstrate one accepted synchronous domain compensation and its redo, plus
   persistence failure and rejected preconditions, without inventing acceptance
   from native stack movement.
2. Demonstrate one logical user action per expected group while native text undo
   continues to preserve its existing editing identities and grouping.
3. Demonstrate two windows with separate focus/history ownership against the
   same Kitchen: a change in either window must trigger the chosen precondition
   revalidation or invalidation behavior in the other.
4. Demonstrate targeted cleanup when an adapter closes or a Kitchen resets,
   distinguishing app command history from still-valid text history.
5. Verify actual menu routing, localized action names, mobile gestures, hardware
   keyboard shortcuts, and accessible failure feedback on supported platforms.

These are recommended adoption gates. They do not settle which Kitchen Memory
operations should be reversible or whether scene-local history is the final
product policy; #191's operation matrix and policy review must decide those.

## Focused helper comparison

The package/release snapshot below was checked on 2026-09-25 using official
repositories, tagged source, manifests, and release metadata. Recent releases
are maintenance evidence, not proof of correctness. Dispositions are
recommendations for this application, not upstream claims. The existing
[dependency inventory](../../DEPENDENCIES.md) and
[tooling survey](swift-tooling-ecosystem-survey.md) remain the adoption rules.

| Candidate and maintenance snapshot | Complexity it removes | Fit and adoption trigger |
| --- | --- | --- |
| **Foundation `UndoManager`**, supplied by the platform SDK | Native undo/redo stacks, grouping, action names, responder integration, and system affordances. No new source package. [API](https://developer.apple.com/documentation/foundation/undomanager) | **Use as the native adapter foundation.** It does not implement domain acceptance, failure recovery, causality, or synchronization policy; those limits are detailed above. |
| **Swift Collections**, already pinned at 1.7.0; upstream 1.7.1 released September 25, 2026. [Release](https://github.com/apple/swift-collections/releases/tag/1.7.1) | `Deque` provides a tested circular buffer with efficient insertion/removal at both ends; useful for bounded history that evicts its oldest entries. [Tagged Deque documentation](https://github.com/apple/swift-collections/blob/1.7.0/Documentation/Deque.md) | **Reuse when a concrete history container is needed.** `Array` remains sufficient for a simple last-in/first-out stack. Neither is an undo policy engine. Apache-2.0 with Swift exception; already inventoried, no new dependency. The new patch is a separate dependency-review opportunity, not adopted here. [Tagged license](https://github.com/apple/swift-collections/blob/1.7.0/LICENSE.txt) |
| **CaptureContext Resettable 0.3.3**, released September 3, 2026. [Release](https://github.com/CaptureContext/swift-resettable/releases/tag/0.3.3) | Records reversible value/key-path mutations, supports explicit inverse closures and amend/insert/inject history operations. It warns that snapshot-based undo does not capture reference mutations. [Tagged implementation](https://github.com/CaptureContext/swift-resettable/blob/0.3.3/Sources/Resettable/Resettable.swift) | **Watch for an isolated unsaved value editor.** It replaces manual mutation history, but its nonthrowing closures do not solve accepted/failed domain compensation or native responder routing. MIT. The Swift 6 manifest adds KeyPathsExtensions; CustomDump supports its separate debugging product. [Manifest](https://github.com/CaptureContext/swift-resettable/blob/0.3.3/Package@swift-6.0.swift), [license](https://github.com/CaptureContext/swift-resettable/blob/0.3.3/LICENSE) |
| **Tunous SwiftUIUndo 1.0.0**, latest release May 24, 2025; no newer release observed. [Release](https://github.com/Tunous/SwiftUIUndo/releases/tag/1.0.0) | Wraps a SwiftUI binding with native manager registration and shake/menu integration. Its undo handler writes the old bound value, then immediately registers the inverse. [Tagged handler](https://github.com/Tunous/SwiftUIUndo/blob/1.0.0/Sources/SwiftUIUndo/Internal/UndoHandler.swift), [README](https://github.com/Tunous/SwiftUIUndo/tree/1.0.0) | **Only consider for a small independent value editor** after proving focus, cleanup, and gesture behavior. The handler cannot establish success of fallible Logic writes; using it directly for shared projections would bypass the needed acceptance boundary. MIT; Swift 6.1, iOS 17/macOS 14 minimum; no declared package dependencies. [Manifest](https://github.com/Tunous/SwiftUIUndo/blob/1.0.0/Package.swift), [license](https://github.com/Tunous/SwiftUIUndo/blob/1.0.0/LICENSE) |
| **Point-Free Swift Navigation 2.11.2**, released August 31, 2026. [Release](https://github.com/pointfreeco/swift-navigation/releases/tag/2.11.2) | State-driven navigation and binding tools. The reviewed product/source inventory provides no `UndoManager` integration; repository code searches found no `UndoManager` match and only an undo mention in an alert example. [Tagged source](https://github.com/pointfreeco/swift-navigation/tree/2.11.2/Sources) | **Do not add for #191.** No verified undo complexity is removed. MIT; its Swift 6.2 manifest includes macros and several package/trait dependencies, so this is not a tiny undo adapter. Reconsider only for an independently demonstrated navigation need. [Manifest](https://github.com/pointfreeco/swift-navigation/blob/2.11.2/Package@swift-6.2.swift), [license](https://github.com/pointfreeco/swift-navigation/blob/2.11.2/LICENSE) |
| **Yjs `Y.UndoManager` / YSwift**, Yjs stable 13.6.33 released September 23, 2026; YSwift 0.2.1 released April 4, 2024. [Yjs release](https://github.com/yjs/yjs/releases/tag/v13.6.33), [YSwift release](https://github.com/y-crdt/yswift/releases/tag/0.2.1) | Selective undo over Yjs shared types with transaction-origin filtering, capture intervals, explicit capture boundaries, and stack metadata. YSwift exposes origin-scoped undo/redo over Y collections through its Rust-backed bridge. [Yjs API](https://docs.yjs.dev/api/undo-manager), [YSwift implementation](https://github.com/y-crdt/yswift/blob/0.2.1/Sources/YSwift/YUndoManager.swift) | **Reconsider only if a future collaborative editor deliberately adopts a Y document model.** This is not an adapter over Kitchen Memory's current immutable evidence model. Both root licenses are MIT; YSwift adds a checksum-pinned binary XCFramework and a Rust build path, plus DocC tooling. Its last repository push was July 20, 2024, so current Swift/toolchain compatibility is unproven here. [Manifest](https://github.com/y-crdt/yswift/blob/0.2.1/Package.swift), [repository metadata](https://api.github.com/repos/y-crdt/yswift), [Yjs license](https://github.com/yjs/yjs/blob/v13.6.33/LICENSE), [YSwift license](https://github.com/y-crdt/yswift/blob/0.2.1/LICENSE) |

**Recommendation:** start with native `UndoManager` and existing Collections
where a named container requirement warrants it. Keep the history entry's
identity, inverse intention, observed preconditions, and acceptance outcome
under Kitchen Memory ownership. No reviewed helper supplies the application's
failed-write and synchronization-aware compensation contract. Native text
history should also retain its existing implementation unless a separate editor
problem demonstrates a benefit from a value-history package.

This comparison inspected source and metadata; it did not resolve, build, or
add any candidate. A new dependency still requires the inventory's full
transitive-license, artifact, privacy, and signed-product review. A prototype
must demonstrate a measurable reduction in adapter or history complexity while
passing the same acceptance, failure, multiwindow, and native-routing tests
before adoption.
