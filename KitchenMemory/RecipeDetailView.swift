// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import KitchenMemoryPersistence
import SwiftUI

struct RecipeDetailView: View {
  let storedRecipe: StoredRecipe

  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @ScaledMetric(relativeTo: .headline) private var stepNumberSize = 30

  private var revision: RecipeRevision { storedRecipe.revision }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        hero
        header
        metadata
        source

        if !revision.equipment.isEmpty {
          recipeSection(
            "Equipment",
            systemImage: "frying.pan",
            accessibilityIdentifier: "equipment-section"
          ) {
            VStack(alignment: .leading, spacing: 10) {
              ForEach(revision.equipment) { item in
                bullet(item.originalText)
              }
            }
          }
        }

        recipeSection(
          "Ingredients",
          systemImage: "carrot",
          accessibilityIdentifier: "ingredients-section"
        ) {
          VStack(alignment: .leading, spacing: 22) {
            ForEach(revision.ingredientSections) { section in
              VStack(alignment: .leading, spacing: 10) {
                if let title = section.title {
                  Text(title)
                    .font(.headline)
                    .foregroundStyle(Color("IconMark"))
                    .accessibilityHeading(.h3)
                    .accessibilityIdentifier(
                      "ingredient-subsection-\(section.id.rawValue.uuidString)"
                    )
                }
                ForEach(section.ingredients) { ingredient in
                  bullet(ingredient.displayText)
                }
              }
              .accessibilityElement(children: .contain)
            }
          }
        }
        recipeSection(
          "Instructions",
          systemImage: "list.number",
          accessibilityIdentifier: "instructions-section"
        ) {
          VStack(alignment: .leading, spacing: 24) {
            ForEach(revision.instructionSections) { section in
              VStack(alignment: .leading, spacing: 14) {
                if let title = section.title {
                  Text(title)
                    .font(.headline)
                    .foregroundStyle(Color("IconMark"))
                    .accessibilityHeading(.h3)
                    .accessibilityIdentifier(
                      "instruction-subsection-\(section.id.rawValue.uuidString)"
                    )
                }
                ForEach(Array(section.steps.enumerated()), id: \.element.id) { index, step in
                  instructionStep(index + 1, step: step)
                }
              }
              .accessibilityElement(children: .contain)
            }
          }
        }
      }
      .frame(maxWidth: 860, alignment: .leading)
      .padding(.horizontal, 24)
      .padding(.vertical, 28)
      .frame(maxWidth: .infinity)
    }
    .accessibilityIdentifier("recipe-detail")
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
        .accessibilityHeading(.h1)
        .accessibilityIdentifier("recipe-title")

      if let summary = revision.summary {
        Text(summary)
          .font(.title3)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("recipe-summary")
      }

      if let authorName = revision.authorName {
        Text("By \(authorName)")
          .font(.subheadline)
          .foregroundStyle(.primary)
          .accessibilityIdentifier("recipe-author")
      }
    }
    .accessibilityElement(children: .contain)
  }

  @ViewBuilder
  private var metadata: some View {
    let values = metadataValues
    if !values.isEmpty {
      LazyVGrid(columns: metadataColumns, spacing: 12) {
        ForEach(values) { value in
          VStack(alignment: .leading, spacing: 5) {
            // Treat the decorative symbol and its label as one phrase so
            // VoiceOver announces "Yield" rather than "person.2, Yield."
            // Keep identifiers on the text nodes because XCTest associates
            // its Dynamic Type findings with those inner nodes.
            HStack(spacing: 5) {
              Image(systemName: value.systemImage)
              Text(value.label)
                .accessibilityIdentifier("recipe-metadata-label-\(value.label.lowercased())")
            }
            .foregroundStyle(Color("IconMark"))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(value.label)
            Text(value.value)
              .accessibilityIdentifier("recipe-metadata-value-\(value.label.lowercased())")
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(14)
          .background(Color("SubtleFill"), in: .rect(cornerRadius: 12))
        }
      }
    }
  }

  private var metadataColumns: [GridItem] {
    if dynamicTypeSize.isAccessibilitySize {
      return [GridItem(.flexible(), alignment: .leading)]
    }
    return [GridItem(.adaptive(minimum: 130), alignment: .leading)]
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
            .foregroundStyle(.primary)
        }
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "link")
            .accessibilityHidden(true)
          Text("Source")
        }
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
    accessibilityIdentifier: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(spacing: 8) {
        Image(systemName: systemImage)
          .accessibilityHidden(true)
        Text(title)
          .accessibilityHeading(.h2)
          .accessibilityIdentifier(accessibilityIdentifier)
      }
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
    .accessibilityElement(children: .contain)
  }

  private func bullet(_ text: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: "circle.fill")
        .font(.system(size: 5))
        .foregroundStyle(Color("AccentColor"))
        .accessibilityHidden(true)
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
        .frame(width: stepNumberSize, height: stepNumberSize)
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
    .accessibilityLabel(instructionAccessibilityLabel(number, step: step))
  }

  private func instructionAccessibilityLabel(_ number: Int, step: InstructionStep) -> String {
    var parts = ["Step \(number)."]
    if let name = step.name {
      parts.append(accessibilitySentence(name))
    }
    parts.append(accessibilitySentence(step.text))
    if let duration = step.duration {
      parts.append("Duration \(self.duration(duration)).")
    }
    return parts.joined(separator: " ")
  }

  private func accessibilitySentence(_ text: String) -> String {
    guard let lastCharacter = text.last, ".!?".contains(lastCharacter) else {
      return "\(text)."
    }
    return text
  }
}

private struct MetadataValue: Identifiable {
  let label: String
  let value: String
  let systemImage: String

  var id: String { label }
}
