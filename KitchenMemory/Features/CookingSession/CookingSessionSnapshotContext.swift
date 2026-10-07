// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

/// Read retained cooking context without reconstructing a live Recipe revision.
struct CookingSessionSnapshotContext: View {
  let snapshot: ExecutionSnapshot
  @Environment(\.locale) private var locale

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      if let summary = snapshot.summary { Text(summary).font(.title3) }
      if let author = snapshot.authorName { Text(.recipeDetailAuthor(author: author)) }
      durations
      if let yield = snapshot.baseYield {
        LabeledContent(.recipeMetadataYield,
          value: RecipeScalingState(recipeYield: yield).displayedYield(locale: locale))
      }
      source
      if !snapshot.equipment.isEmpty {
        CookingSessionCard(title: .recipeDetailEquipmentSection, symbol: "frying.pan") {
          ForEach(snapshot.equipment) { item in
            Text(item.originalText.isEmpty
              ? [RecipePresentationFormatter(locale: locale).quantity(item.quantity), item.name]
                .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
              : item.originalText)
          }
        }
      }
      ForEach(snapshot.media) { reference in
        if let description = reference.accessibilityDescription, !description.isEmpty {
          Text(description).foregroundStyle(.secondary)
        }
      }
    }
    .textSelection(.enabled)
    .accessibilityElement(children: .contain)
  }

  private var durations: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let duration = snapshot.prepDuration {
        LabeledContent(.recipeMetadataPrep, value: RecipePresentationFormatter(locale: locale).duration(duration))
      }
      if let duration = snapshot.cookDuration {
        LabeledContent(.recipeMetadataCook, value: RecipePresentationFormatter(locale: locale).duration(duration))
      }
      if let duration = snapshot.totalDuration {
        LabeledContent(.recipeMetadataTotal, value: RecipePresentationFormatter(locale: locale).duration(duration))
      }
    }
  }

  @ViewBuilder private var source: some View {
    if let source = snapshot.source {
      LabeledContent {
        if let url = RecipeSourceURLPolicy.validatedURL(source.canonicalURL),
           let host = RecipeSourceURLPolicy.displayHost(for: url) {
          Link(destination: url) {
            VStack(alignment: .leading, spacing: 4) {
              Text(source.title ?? LocalizedStringResource.recipeSourceActionOpen.localized(for: locale))
              Text(host).font(.caption).foregroundStyle(.secondary)
            }
          }
        } else {
          VStack(alignment: .leading, spacing: 4) {
            Text(source.title ?? source.kind.rawValue.capitalized)
            if source.canonicalURL != nil { Text(.recipeSourceLinkUnavailable).font(.caption) }
          }
        }
      } label: { Text(.recipeSourceLabel) }
    }
  }
}
