// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI
#if os(iOS)
import UIKit
#endif

/// The adaptive application shell for startup, library, and Cooking Session destinations.
///
/// The shell preserves library navigation on regular-width and Mac layouts and
/// uses compact navigation on iPhone. It routes already-derived presentation
/// state; KitchenKit remains responsible for business behavior and durable
/// Session lifecycle.
struct ContentView: View {
  let startupState: AppStartupState
  let retryStartup: () -> Void
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.locale) private var locale
  @State private var activeSheet: ActiveRecipeSheet?
  @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
  @State private var isShowingResetConfirmation = false
#if !os(macOS)
  @State private var isShowingSettings = false
#endif

  var body: some View {
    Group {
      if usesPersistentLibraryShell {
        persistentRecipeLibrary
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
      Button(.sessionEntryDetachedCopy) { copyAndDiscardDetachedDraft() }
      Button(.sessionEntryDetachedDiscard, role: .destructive) {
        preparedApp?.sessionModel.discardDetachedEntryDraft()
      }
      Button(.actionCancel, role: .cancel) {}
    } message: {
      Text(.sessionEntryDetachedMessage)
    }
    .onChange(of: preparedApp?.libraryModel.selectedRecipeID) { _, recipeID in
      if recipeID != nil {
        preparedApp?.libraryModel.isShowingDrafts = false
        preparedApp?.sessionModel.showRecipes()
      }
    }
    .alert(.recipeEditorDraftFailureTitle, isPresented: draftFailureIsPresented) {
      Button(.actionCancel, role: .cancel) {}
    } message: {
      Text(.recipeEditorDraftFailureMessage)
    }
  }

  private var shellPresentation: AppShellPresentation {
    AppShellPresentation(state: startupState)
  }

  private var preparedApp: PreparedApp? {
    startupState.preparedApp
  }

  private var usesPersistentLibraryShell: Bool {
#if os(iOS)
    horizontalSizeClass == .regular
      || (horizontalSizeClass == nil && UIDevice.current.userInterfaceIdiom == .pad)
#else
    preparedApp != nil
#endif
  }

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

  @ViewBuilder
  private func preparedContent(_ dependencies: PreparedApp) -> some View {
    switch dependencies.libraryModel.startupState {
    case .loading:
      KitchenLoadingView()
    case .choosingSamples:
      SampleRecipeDecisionView(
        accept: dependencies.libraryModel.acceptSampleRecipes,
        decline: dependencies.libraryModel.declineSampleRecipes
      )
    case .ready:
      if let currentSession = dependencies.sessionModel.currentSession,
         !dependencies.sessionModel.isShowingSessionHistory {
        CookingSessionView(model: dependencies.sessionModel, session: currentSession)
      } else {
        recipeLibrary(dependencies)
      }
    }
  }

  @ViewBuilder
  private var persistentRecipeLibrary: some View {
#if os(macOS)
    if let dependencies = preparedApp {
      persistentRecipeLibraryShell
        .focusedSceneValue(\.resetKitchenAction) {
          isShowingResetConfirmation = true
        }
        .kitchenResetConfirmation(
          isPresented: $isShowingResetConfirmation,
          model: dependencies.libraryModel,
          locale: locale
        )
    } else {
      persistentRecipeLibraryShell
    }
#else
    persistentRecipeLibraryShell
#endif
  }

  private var persistentRecipeLibraryShell: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      persistentSidebar
        .navigationTitle(.libraryTitle)
#if !os(macOS)
        .toolbar(removing: usesCustomSidebarToggle ? .sidebarToggle : nil)
        .toolbar { libraryToolbar }
#endif
    } detail: {
      if preparedApp?.libraryModel.editor != nil {
        persistentDetail
      } else {
        NavigationStack { persistentDetail }
      }
    }
#if os(macOS)
    .toolbar(removing: .sidebarToggle)
    .toolbar { libraryToolbar }
#endif
    .sheet(item: $activeSheet) { sheet in
      if let dependencies = preparedApp {
        RecipeLibrarySheetContent(
          sheet: sheet,
          model: dependencies.libraryModel,
          close: { activeSheet = nil }
        )
      }
    }
#if !os(macOS)
    .sheet(isPresented: $isShowingSettings) {
      if let dependencies = preparedApp {
        NavigationStack {
          KitchenSettingsView(
            model: dependencies.libraryModel,
            cloudSyncSettings: dependencies.cloudSyncSettings
          )
        }
      }
    }
#endif
  }

  @ViewBuilder
  private var persistentSidebar: some View {
    switch startupState {
    case .preparing:
      StartupRecipeLibrarySidebar(presentation: .loading)
    case .unavailable:
      StartupRecipeLibrarySidebar(presentation: .recovery)
    case .ready(let dependencies):
      recipeList(dependencies)
    }
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
        if let editor = dependencies.libraryModel.editor {
          RecipeEditingDestination(model: dependencies.libraryModel, editor: editor)
        } else if let currentSession = dependencies.sessionModel.currentSession,
           !dependencies.sessionModel.isShowingSessionHistory {
          CookingSessionView(
            model: dependencies.sessionModel,
            session: currentSession,
            embedsInNavigationStack: false
          )
        } else {
          LibraryDetailRouter(
            libraryModel: dependencies.libraryModel,
            sessionModel: dependencies.sessionModel,
            editRecipe: { dependencies.libraryModel.beginEditing($0) }
          )
        }
      }
    }
  }

  private func recipeLibrary(_ dependencies: PreparedApp) -> some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      recipeList(dependencies)
        .navigationTitle(.libraryTitle)
#if os(macOS)
        .navigationSplitViewColumnWidth(min: 280, ideal: 320)
#endif
        .toolbar(removing: usesCustomSidebarToggle ? .sidebarToggle : nil)
        .toolbar { libraryToolbar }
    } detail: {
      NavigationStack {
        LibraryDetailRouter(
          libraryModel: dependencies.libraryModel,
          sessionModel: dependencies.sessionModel,
          editRecipe: { dependencies.libraryModel.beginEditing($0) }
        )
      }
    }
    .sheet(item: $activeSheet) { sheet in
      RecipeLibrarySheetContent(
        sheet: sheet,
        model: dependencies.libraryModel,
        close: { activeSheet = nil }
      )
    }
#if !os(macOS)
    .fullScreenCover(isPresented: compactEditorIsPresented) {
      if let editor = dependencies.libraryModel.editor {
        RecipeEditingDestination(model: dependencies.libraryModel, editor: editor)
      }
    }
    .sheet(isPresented: $isShowingSettings) {
      NavigationStack {
        KitchenSettingsView(
          model: dependencies.libraryModel,
          cloudSyncSettings: dependencies.cloudSyncSettings
        )
      }
    }
#endif
  }
}

private extension ContentView {
  var draftFailureIsPresented: Binding<Bool> {
    Binding(
      get: { preparedApp?.libraryModel.editingStorageFailed ?? false },
      set: { preparedApp?.libraryModel.editingStorageFailed = $0 }
    )
  }

  var compactEditorIsPresented: Binding<Bool> {
    Binding(
      get: { !usesPersistentLibraryShell && preparedApp?.libraryModel.editor != nil },
      set: { if !$0 { preparedApp?.libraryModel.closeEditor() } }
    )
  }

  @ToolbarContentBuilder
  var libraryToolbar: some ToolbarContent {
    LibraryToolbar(
      showsKitchenActions: preparedApp != nil,
      actionsAreAvailable: preparedApp.map(kitchenActionsAreAvailable) ?? false,
      showsSidebarToggle: usesCustomSidebarToggle,
      sidebarToggleTitle: sidebarToggleTitle,
      sidebarTogglePlacement: sidebarTogglePlacement,
      createRecipe: { preparedApp?.libraryModel.beginEditing() },
      importRecipe: { activeSheet = .importURL },
      toggleSidebar: toggleSidebar,
      showSettings: showSettings
    )
  }

  func kitchenActionsAreAvailable(in dependencies: PreparedApp) -> Bool {
    shellPresentation.permitsKitchenActions
      && dependencies.libraryModel.startupState == .ready
  }

  func recipeList(_ dependencies: PreparedApp) -> some View {
    RecipeLibrarySidebar(
      model: dependencies.libraryModel,
      sessionModel: dependencies.sessionModel,
      locale: locale,
      showSessionHistory: {
        dependencies.libraryModel.isShowingDrafts = false
        dependencies.libraryModel.closeEditor()
        dependencies.libraryModel.selectedRecipeID = nil
        dependencies.sessionModel.showSessionHistory()
        focusSelectedDestination()
      },
      showDeletedItems: {
        dependencies.libraryModel.isShowingDrafts = false
        dependencies.libraryModel.closeEditor()
        dependencies.libraryModel.selectedRecipeID = nil
        dependencies.sessionModel.showDeletedItems()
        focusSelectedDestination()
      },
      showRecovery: {
        dependencies.libraryModel.isShowingDrafts = false
        dependencies.libraryModel.closeEditor()
        dependencies.libraryModel.selectedRecipeID = nil
        dependencies.sessionModel.showRecovery()
        focusSelectedDestination()
      },
      showDrafts: {
        dependencies.libraryModel.closeEditor()
        dependencies.libraryModel.selectedRecipeID = nil
        dependencies.sessionModel.leaveCurrentSession()
        dependencies.sessionModel.showRecipes()
        dependencies.libraryModel.isShowingDrafts = true
        focusSelectedDestination()
      },
      selectSession: { sessionID in
        dependencies.libraryModel.isShowingDrafts = false
        dependencies.libraryModel.closeEditor()
        if dependencies.sessionModel.selectSession(sessionID) {
          focusSelectedDestination()
        }
      }
    )
  }

  func focusSelectedDestination() {
    columnVisibility = LibraryNavigationPolicy.destinationSelectionVisibility(
      current: columnVisibility,
      preservesSidebar: usesPersistentLibraryShell
    )
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

  func copyAndDiscardDetachedDraft() {
    preparedApp?.sessionModel.copyAndDiscardDetachedEntryDraft(using: CookingSessionClipboard.copy)
  }

  var usesCustomSidebarToggle: Bool {
#if os(iOS)
    horizontalSizeClass == .regular
#else
    true
#endif
  }

  var sidebarToggleTitle: LocalizedStringResource {
    columnVisibility == .detailOnly
      ? .librarySidebarActionShow
      : .librarySidebarActionHide
  }

  var sidebarTogglePlacement: ToolbarItemPlacement {
#if os(macOS)
    columnVisibility == .detailOnly ? .navigation : .primaryAction
#else
    .navigation
#endif
  }

  func toggleSidebar() {
    withAnimation {
      columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
    }
  }

  func showSettings() {
#if !os(macOS)
    isShowingSettings = true
#endif
  }
}
