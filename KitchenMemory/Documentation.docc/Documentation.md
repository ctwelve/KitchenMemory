# ``KitchenMemory``

The native application that composes KitchenKit into a private, local-first
recipe library and cooking companion.

## Overview

Start at the source-root `KitchenMemoryApp.swift`. `Interface/` collects the
application's callable preference, Cooking Session, and sample catalog contracts;
`Modules/` contains the corresponding presentation and native implementation.
`Resources/` owns bundled assets, catalogs, and platform configuration. Internal
contracts remain internal; these folders do not create separate Swift modules.


KitchenMemory is the presentation and application-composition layer. It owns
the SwiftUI experience, platform adapters, preferences, localized resources,
and bundled sample content. Presentation-independent concepts and product
operations live in the `KitchenKit` framework.

For a first safari through the source, follow the runtime from
``KitchenMemoryApp`` to ``AppStartupCoordinator``, then through ``AppRuntime``
to ``PreparedApp``. Once preparation succeeds, ``ContentView`` presents two
observable projections: ``RecipeLibraryModel`` for maintained recipes and
``CookingSessionPresentationModel`` for cooking activity and history.
Its app-owned ``CookingSessionDelivery`` owns pending command storage, ordered
retry, and acceptance-required Entry draft effects. Presentation consumes
results and owns navigation and dialogs.

```text
KitchenMemoryApp
└── AppStartupCoordinator
    └── AppRuntime
        └── PreparedApp
            ├── RecipeLibraryModel
            └── CookingSessionPresentationModel
```

Views should translate these projections into native presentation. They should
not reconstruct domain truth, coordinate persistence transactions, or infer
Cooking Session lifecycle from process state.

### Where the caller lives

Much of the application is called by SwiftUI or a native framework. Searching
for callers in this repository therefore shows only part of the path:

| Entry point | Who invokes it | What our code supplies |
| --- | --- | --- |
| `KitchenMemoryApp.body` | SwiftUI's application and scene machinery | Scene declarations and shared startup ownership |
| A view's `body` | SwiftUI during evaluation | A description of presentation for the observed state |
| `.task` and `.onChange` closures | SwiftUI for the installed view or observed change | A bounded effect, with cancellation and lifetime handled explicitly |
| `makeNSView` / `makeUIView` | SwiftUI when creating a native representable | The native control and delegate wiring |
| `updateNSView` / `updateUIView` | SwiftUI when updating that representable | Synchronization into an existing control |
| Text delegate methods | AppKit or UIKit while processing editing | Validation, semantic updates, and composition-aware reconciliation |
| Menu action closures | SwiftUI's command system, with AppKit focus underneath | An intention routed to the appropriate application model |
| Persistent-store observer closures | The notification adapter after store activity | Main-actor refresh of retained projections |

`body` should describe presentation, because SwiftUI can evaluate it repeatedly.
Keep persistence, command delivery, and observers in retained objects with
explicit ownership. A useful breakpoint belongs in the callback or operation
that performs an effect, rather than in every view's `body`.

### Follow startup into the retained graph

`@main` selects SwiftUI's `App` entry point. SwiftUI creates scenes from the
application declaration; this project does not implement its own event loop.
The app's `@StateObject` retains ``AppStartupCoordinator`` across reevaluation.
The coordinator publishes startup state using Combine's `ObservableObject`
and `@Published`, while feature models also use Observation's `@Observable`.
These are two actual observation mechanisms in the current application.

``StartupFrameObserver`` reports the first visible startup surface through a
native view callback. The coordinator then starts preparation, allowing loading
presentation to appear before storage work. Background maintenance can request
preparation without a visible window. Cancellation and retry retire stale
attempts before their dependencies reach presentation.

``AppRuntime`` chooses one launch plan and creates ``PreparedApp``. That object
retains the container, repositories, models, preferences, and observers. A local
temporary observer would stop observing when it was released; a view recomposing
should not create a second observer or repository graph.

For a first debugging exercise, set breakpoints in
`AppStartupCoordinator.startupSurfacePresented()` and `AppRuntime.prepare()`.
Their call stacks expose the native first-frame and asynchronous preparation
handoffs that a text search alone cannot show.

### Separate shared navigation from window focus

The prepared graph is shared by library windows and Settings. Each
``ContentView`` retains its window's split-view state in `@State`;
``AdaptiveLibraryShell`` consumes bindings to that state. The shared
``RecipeLibraryNavigation`` accepts a destination and focus intention; the
window maps that intention to its native layout. An explicit repeat action
applies focus in its originating window rather than broadcasting window effects.

``RecipeLibraryCommands`` connects menu actions to that graph. Focused editor
commands use the focused command capability supplied by the current view.
``LibraryMenuBridge`` publishes scene-focused actions and a library-window
presence marker so a modal window cannot fall through to app-level actions. A focused native text editor retains its own responder priority and
text undo behavior; a menu shortcut must not reinterpret typing as a library
operation.

Leaving an editor checks local draft persistence. A rejected navigation request
preserves the accepted destination. Navigation does not emit Session Stop or
Finish, and it cannot roll back a command that delivery already accepted.

### Trace one native ingredient edit

``NativeIngredientText`` is a SwiftUI wrapper around `NSTextView` on Mac
and `UITextView` on iOS. The representable creates a control and a retained
``IngredientTextCoordinator``; the native framework sends text-editing callbacks
to that coordinator. SwiftUI's update callback synchronizes later model changes
into the same control.

The coordinator retains one KitchenKit semantic editing interface and reports
native ranges in UTF-16 units. The control owns selection, input-method marked
text, undo grouping, and undo delivery. KitchenKit owns line identity,
interpretation, and rebasing precision changes over those native outcomes.
The two halves must observe the same edit without recursively treating a
programmatic refresh as another user edit.

Completing a mode or replacing contents retires the interface and changes the
draft's editor identity. The SwiftUI identity causes the old native control to
be replaced. Teardown ends its interface; late callbacks from the old control
must not reach the new draft contents.

Set a breakpoint in a coordinator text delegate method, type one character,
then Undo. Follow the call into KitchenKit's `RecipeIngredientTextEditing` to
see where native editing becomes a semantic draft update. Keep test text
disposable: the retained draft collection persists ordinary editing changes.

### Distinguish delivery from presentation

``CookingSessionPresentationModel`` owns selection, dialogs, visits, and
optimistic presentation. ``CookingSessionDelivery`` owns pending command and
Entry draft storage. The delivery layer stages final identities before
submission, retries the same intentions in order, and persists accepted draft
effects before retiring commands.

A write attempt, navigation change, and displayed optimistic value answer
different questions. Read the typed delivery outcome before deciding whether
to retain a pending command, offer recovery, or change presentation. A later
navigation veto cannot re-stage an already retired command. Exact Entry text
can remain recoverable even after its impossible command identity is cleared.

### Follow external changes back into values

SwiftData manages storage and CloudKit transport. The app receives store-change
and account-status signals through platform adapters. The store-change path
reconciles Kitchen ownership, refreshes repository reads, and reloads retained
library and Session projections on the main actor. It never passes managed
records into views or treats a notification as proof of global convergence.

To understand a refreshed screen, follow `makePersistentStoreChangeObserver`
and `performExternalStoreRefresh` into the models' reload methods. Their
resulting values determine presentation. The framework notification tells us
to look again; KitchenKit's evidence classification tells us what can be shown.

### Framework references

For the framework contracts behind this source tour, see Apple's
[StateObject](https://developer.apple.com/documentation/swiftui/stateobject),
[NSViewRepresentable](https://developer.apple.com/documentation/swiftui/nsviewrepresentable),
[UIViewRepresentable](https://developer.apple.com/documentation/swiftui/uiviewrepresentable),
and [focus cookbook](https://developer.apple.com/videos/play/wwdc2023/10162/).
The source comments explain how this application uses those mechanisms.

## Topics

### Start Here

- ``KitchenMemoryApp``
- ``AppStartupCoordinator``
- ``AppRuntime``
- ``PreparedApp``
- ``ContentView``
- ``StartupFrameObserver``

### Feature Projections

- ``RecipeLibraryModel``
- ``CookingSessionPresentationModel``
- ``CookingSessionDelivery``

### Window and Command Routing

- ``AdaptiveLibraryShell``
- ``RecipeLibraryNavigation``
- ``RecipeLibraryCommands``
- ``LibraryMenuBridge``

### Native Editing

- ``NativeIngredientText``
- ``IngredientTextCoordinator``

### Application Resources and Preferences

- ``BundledSampleRecipeProvider``
- ``KitchenPreferencesStoring``
- ``DefaultsKitchenPreferencesStore``
- ``OrganizationPreferencesStoring``
