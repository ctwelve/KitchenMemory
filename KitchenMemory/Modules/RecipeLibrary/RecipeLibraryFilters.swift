// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

/// Pinned native controls share the model's scope across list and detail navigation.
struct RecipeLibraryFilters: View {
  @Bindable var model: RecipeOrganizationModel
  let locale: Locale

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(scopeTitle)
        .font(.headline)
        .accessibilityAddTraits(.isHeader)
      TextField(.organizationSearch, text: $model.filter.search)
        .textFieldStyle(.roundedBorder)
        .accessibilityLabel(Text(.organizationSearch))
        .accessibilityIdentifier("organization-search")
      if model.preferences.tagsEnabled, let snapshot = model.snapshot {
        let tags = snapshot.tags.orderedTags(locale: locale).filter { model.filter.tagIDs.contains($0.id) }
        if !tags.isEmpty {
          Label(tags.map(\.name).joined(separator: ", "), systemImage: "tag")
            .font(.caption)
        }
        if model.filter.untagged { Label(.organizationUntagged, systemImage: "tag.slash").font(.caption) }
      }
      ViewThatFits(in: .horizontal) {
        HStack { filterActions }
        VStack(alignment: .leading) { filterActions }
      }
      Toggle(.organizationSelect, isOn: $model.selecting)
      if model.selecting {
        RecipeOrganizationMenus(model: model, recipeIDs: model.selectedRecipes)
          .disabled(model.selectedRecipes.isEmpty)
      }
    }
    .padding(12)
  }

  private var scopeTitle: String {
    guard model.preferences.foldersEnabled else {
      return LocalizedStringResource.organizationAll.localized(for: locale)
    }
    switch model.filter.location {
    case .all: return LocalizedStringResource.organizationAll.localized(for: locale)
    case .unfiled: return LocalizedStringResource.organizationUnfiled.localized(for: locale)
    case let .folder(id):
      return model.snapshot?.folders.destinations(locale: locale).first { $0.id == id }?.path
        ?? LocalizedStringResource.organizationAll.localized(for: locale)
    }
  }

  @ViewBuilder
  private var filterActions: some View {
    Button(.organizationResetFilters) { model.resetFilters() }
      .accessibilityIdentifier("reset-recipe-filters")
    if model.preferences.foldersEnabled, model.filter.location != .all {
      Button(.organizationAll) { model.showAllRecipes() }
    }
  }
}
