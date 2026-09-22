// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct RecipeLibraryList: View {
  @Bindable var model: RecipeLibraryModel
  @Bindable var sessionModel: CookingSessionPresentationModel
  let locale: Locale
  let focusDetail: () -> Void
  let selectSession: (CookingSession.ID) -> Void

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 8) {
        if let organization = model.organization {
          Section {
            TextField(.organizationSearch, text: Binding(get: { organization.filter.search },
                                                       set: { organization.filter.search = $0 }))
              .accessibilityIdentifier("organization-search")
            Toggle(.organizationSelect, isOn: Binding(get: { organization.selecting },
                                                    set: { organization.selecting = $0 }))
            if organization.selecting {
              RecipeOrganizationMenus(model: organization, recipeIDs: organization.selectedRecipes)
                .disabled(organization.selectedRecipes.isEmpty)
            }
          }
        }
        recipeSection
      }
      .scrollTargetLayout()
      .padding(12)
    }
    .scrollPosition(id: Binding(get: { model.navigation.recipeListAnchor },
                                set: { model.navigation.recipeListAnchor = $0 }), anchor: .top)
    .accessibilityIdentifier("recipe-list")
    .accessibilityLabel(Text(.libraryAccessibilityLabel))
    .navigationTitle(.libraryTitle)
    .overlay { if !model.hasLoaded { ProgressView(.libraryLoading) } }
    .alert(.recipeComparisonUnavailable, isPresented: $model.reconciliationFailed) {
      Button(.actionCancel, role: .cancel) {}
    } message: { Text(model.reconciliationFailureMessage) }
    .onChange(of: model.recipes.map(\.recipe.id), initial: true) { _, ids in
      sessionModel.refreshSidebarAssociations(for: ids)
    }
    .onChange(of: sessionModel.sessions.map(\.id)) { _, _ in
      sessionModel.refreshSidebarAssociations(for: model.recipes.map(\.recipe.id))
    }
  }

  @ViewBuilder
  private var recipeSection: some View {
    Section {
      if let issue = model.issue {
        unavailableLibrary(issue)
      } else if model.hasLoaded, model.recipes.isEmpty, model.visibleReconciliations.isEmpty {
        emptyLibrary
      } else {
        ForEach(model.visibleReconciliations, id: \.recipeID) { comparison in
          Button {
            model.beginReconciliation(comparison)
            if model.editor != nil { focusDetail() }
          } label: {
            VStack(alignment: .leading) {
              Label(.recipeComparisonTitle, systemImage: "arrow.triangle.branch")
              Text(comparison.revisions.map(\.title).joined(separator: " / "))
                .font(.caption).foregroundStyle(.secondary)
            }
          }
          .accessibilityIdentifier("reconcile-recipe-\(comparison.recipeID.rawValue.uuidString)")
        }
        ForEach(
          model.organization?.recipes(model.recipes, locale: locale) ?? model.recipes, id: \.recipe.id
        ) { storedRecipe in
          if let organization = model.organization, organization.selecting {
            Toggle(storedRecipe.revision.title, isOn: Binding(get: {
              organization.selectedRecipes.contains(storedRecipe.id)
            }, set: { selected in
              if selected {
                organization.selectedRecipes.insert(storedRecipe.id)
              } else {
                organization.selectedRecipes.remove(storedRecipe.id)
              }
            }))
          }
          Button {
            if model.selectRecipeForReading(storedRecipe.id) { focusDetail() }
          } label: {
            RecipeRow(storedRecipe: storedRecipe)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(6)
              .background(model.selectedRecipeID == storedRecipe.id ? Color.accentColor.opacity(0.15) : .clear,
                          in: .rect(cornerRadius: 6))
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(model.selectedRecipeID == storedRecipe.id ? .isSelected : [])
          .id(storedRecipe.id)
          .draggable("km-recipe:" + storedRecipe.id.rawValue.uuidString)
          .contextMenu {
            if let organization = model.organization {
              RecipeOrganizationMenus(model: organization, recipeIDs: [storedRecipe.id])
            }
          }
          .accessibilityIdentifier("recipe-row-\(storedRecipe.recipe.id.rawValue.uuidString)")
          ForEach(sessionModel.sidebarSessions(for: storedRecipe.recipe.id), id: \.id) { session in
            Button {
              selectSession(session.id)
            } label: {
              CookingSessionRow(session: session)
                .padding(.leading, 24)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("session-row-\(session.id.rawValue.uuidString)")
          }
        }
      }
    } header: {
      Text(.sessionDiscoveryRecipes)
        .accessibilityIdentifier("recipe-library-ready")
    }
  }

  private func unavailableLibrary(_ issue: RecipeLibraryIssue) -> some View {
    ContentUnavailableView {
      Label(.libraryUnavailableTitle, systemImage: "exclamationmark.triangle")
    } description: {
      Text(issue.message(locale: locale))
    } actions: {
      Button(.actionTryAgain) { model.retryCurrentIssue() }
    }
  }

  private var emptyLibrary: some View {
    ContentUnavailableView(
      .libraryEmptyTitle,
      systemImage: "book.closed",
      description: Text(.libraryEmptyMessage)
    )
  }
}
