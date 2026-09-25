// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

/// The adaptive application shell for startup, library, and Cooking Session destinations.
///
/// The shell preserves library navigation on regular-width and Mac layouts and
/// uses compact navigation on iPhone. It routes already-derived presentation
/// state; KitchenKit remains responsible for business behavior and durable
/// Session lifecycle.
struct ContentView: View {
  let startupState: AppStartupState
  let retryStartup: () -> Void
  @Environment(\.locale) private var locale
  @State private var activeSheet: ActiveRecipeSheet?
  @State private var columnVisibility = LibraryNavigationPolicy.initialVisibility
  @State private var preferredCompactColumn: NavigationSplitViewColumn = .content
  @State private var temporaryOrganization = false
  @State private var isShowingResetConfirmation = false
#if !os(macOS)
  @State private var isShowingSettings = false
#endif

  var body: some View {
    Group {
      if let dependencies = preparedApp {
        persistentRecipeLibrary(dependencies)
      } else {
        phaseContent
      }
    }
    .task(id: shellPresentation) {
      preparedApp?.libraryModel.loadIfNeeded()
      preparedApp?.sessionModel.loadIfNeeded()
    }
    .tint(Color("AccentColor"))
    .alert(.sessionIssueTitle, isPresented: sessionIssueIsPresented) {
      if preparedApp?.sessionModel.issue != .clipboard {
        Button(.actionTryAgain) { preparedApp?.sessionModel.retryCurrentIssue() }
      }
      Button(.actionCancel, role: .cancel) {}
    } message: {
      if let issue = preparedApp?.sessionModel.issue {
        Text(issue.message)
      }
    }
    .confirmationDialog(
      .sessionEntryDetachedTitle,
      isPresented: detachedDraftIsPresented,
      titleVisibility: .visible
    ) {
      Button(.sessionEntryDetachedContinue) {
        preparedApp?.sessionModel.continueDetachedEntryDraft()
      }
      Button(.sessionEntryDetachedCopy) {
        preparedApp?.sessionModel.copyAndDiscardDetachedEntryDraft(using: CookingSessionClipboard.copy)
      }
      Button(.sessionEntryDetachedDiscard, role: .destructive) {
        preparedApp?.sessionModel.discardDetachedEntryDraft()
      }
      Button(.actionCancel, role: .cancel) {}
    } message: {
      Text(.sessionEntryDetachedMessage)
    }
    .modifier(RecipeDraftFailureAlert(model: preparedApp?.libraryModel))
    .alert(.organizationFailed, isPresented: Binding(
      get: { preparedApp?.libraryModel.organization?.failed == true },
      set: { preparedApp?.libraryModel.organization?.failed = $0 }
    )) { Button(.actionCancel, role: .cancel) {} } message: { Text(.organizationFailureMessage) }
    .modifier(LibraryMenuBridge(
      actions: libraryActions, isAvailable: activeSheet == nil && !isShowingResetConfirmation
    ))
  }

  private var shellPresentation: AppShellPresentation {
    AppShellPresentation(state: startupState)
  }

  private var preparedApp: PreparedApp? { startupState.preparedApp }

  @ViewBuilder
  private var phaseContent: some View {
    switch startupState {
    case .preparing:
      KitchenLoadingView()
    case .unavailable:
      KitchenUnavailableView(retry: retryStartup)
    case .ready(let dependencies):
      preparedContent(dependencies)
    }
  }

  private func preparedContent(_ dependencies: PreparedApp) -> some View {
    persistentRecipeLibrary(dependencies)
  }

  private func persistentRecipeLibrary(_ dependencies: PreparedApp) -> some View {
    AdaptiveLibraryShell(visibility: $columnVisibility, preferredColumn: $preferredCompactColumn,
                         temporarySidebar: $temporaryOrganization) {
      recipeList(dependencies)
#if !os(macOS)
        .toolbar { libraryToolbar }
#endif
    } content: {
      LibraryContentRouter(libraryModel: dependencies.libraryModel, sessionModel: dependencies.sessionModel,
                           applyNavigationFocus: applyAcceptedNavigationFocus)
        .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 480)
#if !os(macOS)
        .toolbar { libraryToolbar }
#endif
    } detail: {
      Group {
        if dependencies.libraryModel.editor != nil {
          persistentDetail
        } else {
          NavigationStack { persistentDetail }
        }
      }
#if !os(macOS)
      .toolbar { libraryToolbar }
#endif
    }
#if os(macOS)
    .toolbar { libraryToolbar }
    .focusedSceneValue(\.resetKitchenAction) { isShowingResetConfirmation = true }
    .kitchenResetConfirmation(isPresented: $isShowingResetConfirmation,
                             model: dependencies.libraryModel, locale: locale)
#endif
    .onChange(of: dependencies.libraryModel.startupState, initial: true) { _, startup in
      preferredCompactColumn = LibraryNavigationPolicy.initialColumn(
        startup: startup, focus: dependencies.libraryModel.navigation.focus)
    }
    .onChange(of: dependencies.libraryModel.navigation.destination) { _, _ in
      applyAcceptedNavigationFocus()
    }
    .sheet(item: $activeSheet) { _ in
      RecipeLibrarySheetContent(model: dependencies.libraryModel, close: { activeSheet = nil })
    }
#if !os(macOS)
    .sheet(isPresented: $isShowingSettings) {
      NavigationStack {
        KitchenSettingsView(model: dependencies.libraryModel, cloudSyncSettings: dependencies.cloudSyncSettings)
      }
    }
#endif
  }

  @ViewBuilder
  private var persistentDetail: some View {
    switch startupState {
    case .preparing:
      KitchenLoadingView()
    case .unavailable:
      KitchenUnavailableView(retry: retryStartup)
    case .ready(let dependencies):
      switch dependencies.libraryModel.startupState {
      case .loading:
        KitchenLoadingView()
      case .choosingSamples:
        SampleRecipeDecisionView(
          accept: dependencies.libraryModel.acceptSampleRecipes,
          decline: dependencies.libraryModel.declineSampleRecipes
        )
      case .ready:
        LibraryDetailRouter(libraryModel: dependencies.libraryModel, sessionModel: dependencies.sessionModel)
      }
    }
  }

}

private extension ContentView {
  @ToolbarContentBuilder
  var libraryToolbar: some ToolbarContent {
    LibraryToolbar(
      showsKitchenActions: preparedApp != nil,
      actions: libraryActions,
      showSettings: showSettings
    )
  }

  var libraryActions: LibraryCommandActions? {
    preparedApp.map {
      LibraryCommandActions(library: $0.libraryModel, sessions: $0.sessionModel,
                            openImport: { activeSheet = .importURL }, focusDestination: applyNavigationFocus)
    }
  }

  func recipeList(_ dependencies: PreparedApp) -> some View {
    RecipeLibrarySidebar(
      model: dependencies.libraryModel,
      sessionModel: dependencies.sessionModel,
      showSessionHistory: {
        libraryActions?.perform(.sessions)
      },
      showDeletedItems: {
        libraryActions?.perform(.deletedItems)
      },
      showRecovery: {
        libraryActions?.perform(.recovery)
      },
      showDrafts: {
        libraryActions?.perform(.drafts)
      },
      browse: { change in
        if dependencies.libraryModel.navigation.browseRecipes(changingFilter: change) {
          applyAcceptedNavigationFocus()
        }
      }
    )
  }

  func applyNavigationFocus(_ focus: RecipeLibraryNavigation.Focus) {
    preferredCompactColumn = LibraryNavigationPolicy.column(for: focus)
  }

  func applyAcceptedNavigationFocus() {
    guard let navigation = preparedApp?.libraryModel.navigation else { return }
    applyNavigationFocus(navigation.focus)
  }

  var sessionIssueIsPresented: Binding<Bool> {
    Binding(
      get: { preparedApp?.sessionModel.isShowingIssue ?? false },
      set: { isPresented in
        if !isPresented { preparedApp?.sessionModel.dismissIssuePresentation() }
      }
    )
  }

  var detachedDraftIsPresented: Binding<Bool> {
    Binding(
      get: { preparedApp?.sessionModel.detachedEntryDraft != nil },
      set: { _ in }
    )
  }

  func showSettings() {
#if !os(macOS)
    isShowingSettings = true
#endif
  }
}
