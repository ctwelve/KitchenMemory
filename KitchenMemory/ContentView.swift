// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct ContentView: View {
  @Bindable var model: RecipeLibraryModel
  @Bindable var sessionModel: CookingSessionPresentationModel
  let cloudSyncSettings: CloudSyncSettings?
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
      switch model.startupState {
      case .loading:
        KitchenLoadingView()
      case .choosingSamples:
        SampleRecipeDecisionView(
          accept: model.acceptSampleRecipes,
          decline: model.declineSampleRecipes
        )
      case .ready:
        if let currentSession = sessionModel.currentSession {
          CookingSessionView(model: sessionModel, session: currentSession)
        } else {
          recipeLibrary
        }
      }
    }
    .task {
      model.loadIfNeeded()
      sessionModel.loadIfNeeded()
    }
    .tint(Color("AccentColor"))
    .alert(
      .sessionIssueTitle,
      isPresented: sessionIssueIsPresented
    ) {
      Button(.actionTryAgain) { sessionModel.retryCurrentIssue() }
      Button(.actionCancel, role: .cancel) {}
    } message: {
      if let issue = sessionModel.issue {
        Text(issue.message)
      }
    }
    .confirmationDialog(
      .sessionEntryDetachedTitle,
      isPresented: detachedDraftIsPresented,
      titleVisibility: .visible
    ) {
      Button(.sessionEntryDetachedContinue) {
        sessionModel.continueDetachedEntryDraft()
      }
      Button(.sessionEntryDetachedCopy) {
        copyAndDiscardDetachedDraft()
      }
      Button(.sessionEntryDetachedDiscard, role: .destructive) {
        sessionModel.discardDetachedEntryDraft()
      }
      Button(.actionCancel, role: .cancel) {}
    } message: {
      Text(.sessionEntryDetachedMessage)
    }
  }

  private var sessionIssueIsPresented: Binding<Bool> {
    Binding(
      get: { sessionModel.isShowingIssue },
      set: { isPresented in
        if !isPresented { sessionModel.dismissIssuePresentation() }
      }
    )
  }

  private var detachedDraftIsPresented: Binding<Bool> {
    Binding(
      get: { sessionModel.detachedEntryDraft != nil },
      set: { _ in }
    )
  }

  private func copyAndDiscardDetachedDraft() {
    guard let text = sessionModel.detachedEntryDraft?.text else { return }
    CookingSessionClipboard.copy(text)
    sessionModel.discardDetachedEntryDraft()
  }

  private var recipeLibrary: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      recipeList
        .navigationTitle(.libraryTitle)
#if os(macOS)
        .navigationSplitViewColumnWidth(min: 280, ideal: 320)
#endif
        // NavigationSplitView installs this item on its sidebar column, so
        // removal must be scoped to the same view rather than the split root.
        .toolbar(removing: usesCustomSidebarToggle ? .sidebarToggle : nil)
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            Button {
              activeSheet = .create
            } label: {
              ToolbarIconLabel(.libraryActionNewRecipe, systemImage: "plus")
            }
            .accessibilityIdentifier("new-recipe")
          }
          ToolbarItem(placement: .primaryAction) {
            Button {
              activeSheet = .importURL
            } label: {
              ToolbarIconLabel(.libraryActionImportRecipe, systemImage: "square.and.arrow.down")
            }
            .accessibilityIdentifier("import-recipe")
          }
          if usesCustomSidebarToggle {
            ToolbarItem(placement: sidebarTogglePlacement) {
              Button {
                toggleSidebar()
              } label: {
                ToolbarIconLabel(sidebarToggleTitle, systemImage: "sidebar.left")
              }
              .accessibilityIdentifier("toggle-sidebar")
              .help(Text(sidebarToggleTitle))
            }
          }
#if !os(macOS)
          ToolbarItem(placement: .primaryAction) {
            Button {
              isShowingSettings = true
            } label: {
              ToolbarIconLabel(.settingsTitle, systemImage: "gearshape")
            }
            .accessibilityIdentifier("open-settings")
          }
#endif
        }
    } detail: {
      detail
    }
    .sheet(item: $activeSheet) { sheet in
      sheetContent(sheet)
    }
#if os(macOS)
    .focusedSceneValue(\.resetKitchenAction) {
      isShowingResetConfirmation = true
    }
    .kitchenResetConfirmation(
      isPresented: $isShowingResetConfirmation,
      model: model,
      locale: locale
    )
#else
    .sheet(isPresented: $isShowingSettings) {
      NavigationStack {
        KitchenSettingsView(
          model: model,
          cloudSyncSettings: cloudSyncSettings
        )
      }
    }
#endif
  }

  private var usesCustomSidebarToggle: Bool {
#if os(iOS)
    horizontalSizeClass == .regular
#else
    true
#endif
  }

  private var sidebarToggleTitle: LocalizedStringResource {
    columnVisibility == .detailOnly
      ? .librarySidebarActionShow
      : .librarySidebarActionHide
  }

  private var sidebarTogglePlacement: ToolbarItemPlacement {
#if os(macOS)
    columnVisibility == .detailOnly ? .navigation : .primaryAction
#else
    .navigation
#endif
  }

  private func toggleSidebar() {
    withAnimation {
      columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
    }
  }

  @ViewBuilder
  private var recipeList: some View {
    RecipeLibrarySidebar(model: model, sessionModel: sessionModel, locale: locale)
  }

  @ViewBuilder
  private var detail: some View {
    if let selectedRecipe = model.selectedRecipe {
      RecipeDetailView(storedRecipe: selectedRecipe)
        // A revision is immutable, but this view owns reading-only state such
        // as the selected scaling basis. Give each new revision fresh state so
        // a just-saved yield is reflected immediately.
        .id(selectedRecipe.revision.id)
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            Button {
              sessionModel.start(from: selectedRecipe)
            } label: {
              Label(.sessionActionStart, systemImage: "flame")
            }
            .accessibilityIdentifier("start-cooking")
          }
          ToolbarItem(placement: .primaryAction) {
            Button { activeSheet = .edit(selectedRecipe) } label: {
              Label(.recipeActionEdit, systemImage: "pencil")
            }
              .accessibilityIdentifier("edit-recipe")
          }
        }
    } else {
      ContentUnavailableView(
        .librarySelectionEmptyTitle,
        systemImage: "book.pages",
        description: Text(.librarySelectionEmptyMessage)
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color("AppBackground"))
    }
  }

  @ViewBuilder
  private func sheetContent(_ sheet: ActiveRecipeSheet) -> some View {
    switch sheet {
    case .create:
      RecipeEditorView(mode: .create) { draft in
        model.createRecipe(from: draft)
      }
    case .edit(let storedRecipe):
      RecipeEditorView(mode: .revise, draft: RecipeDraft(revision: storedRecipe.revision)) { draft in
        model.reviseRecipe(id: storedRecipe.recipe.id, from: draft)
      }
    case .importURL:
      RecipeURLImportView(
        load: { url in try await model.importRecipe(from: url) },
        select: { activeSheet = .review($0) }
      )
    case .review(let option):
      RecipeEditorView(
        mode: .importReview,
        draft: option.draft,
        reviewConcerns: option.concerns
      ) { draft in
        model.createRecipe(from: draft)
      }
    }
  }
}

private struct ToolbarIconLabel: View {
  let title: LocalizedStringResource
  let systemImage: String

  init(_ title: LocalizedStringResource, systemImage: String) {
    self.title = title
    self.systemImage = systemImage
  }

  var body: some View {
    Label(title, systemImage: systemImage)
      .labelStyle(.iconOnly)
      // SF Symbols have different intrinsic heights. A shared box keeps their
      // visible lower edges aligned without changing the toolbar button target.
      .frame(width: 20, height: 20, alignment: .bottom)
      .accessibilityLabel(Text(title))
  }
}

private enum ActiveRecipeSheet: Identifiable {
  case create
  case edit(StoredRecipe)
  case importURL
  case review(RecipeImportOption)

  var id: String {
    switch self {
    case .create: "create"
    case .edit(let recipe): "edit-\(recipe.recipe.id.rawValue.uuidString)"
    case .importURL: "import-url"
    case .review(let option):
      "review-\(option.id.blockIndex)-\(option.id.objectIndex)"
    }
  }
}

struct RecipeRow: View {
  let storedRecipe: StoredRecipe

  var body: some View {
    HStack(spacing: 12) {
      RecipeImage(
        media: storedRecipe.revision.media.first { $0.role == .thumbnail }
          ?? storedRecipe.revision.media.first,
        contentMode: .fill
      )
      .frame(width: 56, height: 56)
      .clipShape(.rect(cornerRadius: 10))
      // The image repeats the recipe represented by the NavigationLink. If it
      // remained exposed, VoiceOver would announce an extra image before the
      // title without adding information or an independent action.
      .accessibilityHidden(true)

      VStack(alignment: .leading, spacing: 3) {
        Text(storedRecipe.revision.title)
          .font(.headline)
        if let summary = storedRecipe.revision.summary {
          Text(summary)
            .font(.caption)
            .foregroundStyle(.primary)
        }
      }
    }
    .padding(.vertical, 4)
  }
}

#Preview {
  ContentView(
    model: PreparedApp.preview.libraryModel,
    sessionModel: PreparedApp.preview.sessionModel,
    cloudSyncSettings: nil
  )
}
