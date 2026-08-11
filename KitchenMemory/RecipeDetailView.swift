// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import KitchenMemoryPersistence
import SwiftUI

struct RecipeDetailView: View {
  let storedRecipe: StoredRecipe

  private var revision: RecipeRevision { storedRecipe.revision }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        hero
        header
        metadata
        source

        if !revision.equipment.isEmpty {
          recipeSection("Equipment", systemImage: "frying.pan") {
            VStack(alignment: .leading, spacing: 10) {
              ForEach(revision.equipment) { item in
                bullet(item.originalText)
              }
            }
          }
        }

        recipeSection("Ingredients", systemImage: "carrot") {
          VStack(alignment: .leading, spacing: 22) {
            ForEach(revision.ingredientSections) { section in
              VStack(alignment: .leading, spacing: 10) {
                if let title = section.title {
                  Text(title)
                    .font(.headline)
                    .foregroundStyle(Color("IconMark"))
                }
                ForEach(section.ingredients) { ingredient in
                  bullet(ingredient.displayText)
                }
              }
            }
          }
        }

        recipeSection("Instructions", systemImage: "list.number") {
          VStack(alignment: .leading, spacing: 24) {
            ForEach(revision.instructionSections) { section in
              VStack(alignment: .leading, spacing: 14) {
                if let title = section.title {
                  Text(title)
                    .font(.headline)
                    .foregroundStyle(Color("IconMark"))
                }
                ForEach(Array(section.steps.enumerated()), id: \.element.id) { index, step in
                  instructionStep(index + 1, step: step)
                }
              }
            }
          }
        }
      }
      .frame(maxWidth: 860, alignment: .leading)
      .padding(.horizontal, 24)
      .padding(.vertical, 28)
      .frame(maxWidth: .infinity)
    }
    .background(Color("AppBackground"))
    .navigationTitle(revision.title)
#if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
#endif
  }

  private var hero: some View {
    RecipeImage(
      media: revision.media.first { $0.role == .hero } ?? revision.media.first,
      contentMode: .fill
    )
    .frame(maxWidth: .infinity)
    .containerRelativeFrame(.vertical) { length, _ in
      min(max(length * 0.34, 240), 420)
    }
    .clipShape(.rect(cornerRadius: 20))
    .overlay {
      RoundedRectangle(cornerRadius: 20)
        .stroke(Color("SubtleBorder"), lineWidth: 1)
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(revision.title)
        .font(.largeTitle.bold())
        .foregroundStyle(.primary)
        .accessibilityIdentifier("recipe-title")

      if let summary = revision.summary {
        Text(summary)
          .font(.title3)
          .foregroundStyle(.secondary)
      }

      if let authorName = revision.authorName {
        Text("By \(authorName)")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
    }
  }

  @ViewBuilder
  private var metadata: some View {
    let values = metadataValues
    if !values.isEmpty {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], spacing: 12) {
        ForEach(values) { value in
          VStack(alignment: .leading, spacing: 5) {
            Label(value.label, systemImage: value.systemImage)
              .font(.caption.weight(.semibold))
              .foregroundStyle(Color("IconMark"))
            Text(value.value)
              .font(.body)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(14)
          .background(Color("SubtleFill"), in: .rect(cornerRadius: 12))
        }
      }
    }
  }

  private var metadataValues: [MetadataValue] {
    var values: [MetadataValue] = []
    if let recipeYield = revision.recipeYield {
      values.append(.init(label: "Yield", value: recipeYield.originalText, systemImage: "person.2"))
    }
    if let prepDuration = revision.prepDuration {
      values.append(.init(label: "Prep", value: duration(prepDuration), systemImage: "clock"))
    }
    if let cookDuration = revision.cookDuration {
      values.append(.init(label: "Cook", value: duration(cookDuration), systemImage: "flame"))
    }
    if let totalDuration = revision.totalDuration {
      values.append(.init(label: "Total", value: duration(totalDuration), systemImage: "timer"))
    }
    return values
  }

  @ViewBuilder
  private var source: some View {
    if let recipeSource = revision.source {
      LabeledContent {
        if let url = recipeSource.canonicalURL {
          Link(recipeSource.title ?? url.host() ?? "Open Source", destination: url)
        } else {
          Text(recipeSource.title ?? recipeSource.kind.rawValue.capitalized)
        }
      } label: {
        Label("Source", systemImage: "link")
          .foregroundStyle(Color("IconMark"))
      }
      .padding(16)
      .background(Color("ContentSurface"), in: .rect(cornerRadius: 12))
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color("SubtleBorder"), lineWidth: 1)
      }
    }
  }

  private func duration(_ duration: RecipeDuration) -> String {
    let hours = duration.seconds / 3_600
    let minutes = (duration.seconds % 3_600) / 60
    if hours > 0, minutes > 0 { return "\(hours) hr \(minutes) min" }
    if hours > 0 { return "\(hours) hr" }
    return "\(minutes) min"
  }

  private func recipeSection<Content: View>(
    _ title: String,
    systemImage: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      Label(title, systemImage: systemImage)
        .font(.title2.bold())
        .foregroundStyle(Color("IconMark"))
      content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .background(Color("ContentSurface"), in: .rect(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color("SubtleBorder"), lineWidth: 1)
    }
  }

  private func bullet(_ text: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: "circle.fill")
        .font(.system(size: 5))
        .foregroundStyle(Color("AccentColor"))
      Text(text)
        .textSelection(.enabled)
    }
    .accessibilityElement(children: .combine)
  }

  private func instructionStep(_ number: Int, step: InstructionStep) -> some View {
    HStack(alignment: .top, spacing: 14) {
      Text(number, format: .number)
        .font(.headline)
        .foregroundStyle(Color("ContentSurface"))
        .frame(width: 30, height: 30)
        .background(Color("AccentColor"), in: Circle())

      VStack(alignment: .leading, spacing: 5) {
        if let name = step.name {
          Text(name)
            .font(.headline)
        }
        Text(step.text)
          .textSelection(.enabled)
        if let duration = step.duration {
          Label(self.duration(duration), systemImage: "timer")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("Step \(number). \(step.text)")
  }
}

private struct MetadataValue: Identifiable {
  let label: String
  let value: String
  let systemImage: String

  var id: String { label }
}
