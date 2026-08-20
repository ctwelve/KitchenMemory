// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import KitchenMemoryPersistence
import SwiftUI

struct RecipeDetailView: View {
  let storedRecipe: StoredRecipe

  // The metadata grid collapses before large text makes its cards cramped.
  // @ScaledMetric separately keeps the numbered instruction badge in step
  // with the text size instead of clipping a larger numeral in a fixed circle.
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
                    .accessibilityLabel(title)
                    .accessibilityHeading(.h3)
                    .accessibilityIdentifier(
                      "ingredient-subsection-\(section.id.rawValue.uuidString)"
                    )
                }
                ForEach(section.ingredients) { ingredient in
                  bullet(ingredient.effectiveDisplayText)
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
                    .accessibilityLabel(title)
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
    // The detail identifier marks the navigation destination for UI tests.
    // The label describes the screen as a whole; children remain contained
    // and navigable rather than being collapsed into one enormous utterance.
    .accessibilityIdentifier("recipe-detail")
    .accessibilityLabel("\(revision.title) recipe")
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
        .accessibilityLabel(revision.title)
        .accessibilityHeading(.h1)
        // Tests locate this semantic title instead of depending on SwiftUI's
        // platform-specific navigation-bar hierarchy.
        .accessibilityIdentifier("recipe-title")

      if let summary = revision.summary {
        Text(summary)
          .font(.title3)
          .foregroundStyle(.primary)
          .accessibilityLabel(summary)
          .accessibilityIdentifier("recipe-summary")
      }

      if let authorName = revision.authorName {
        Text("By \(authorName)")
          .font(.subheadline)
          .foregroundStyle(.primary)
          .accessibilityLabel("By \(authorName)")
          .accessibilityIdentifier("recipe-author")
      }
    }
    // Explicit containment preserves the heading hierarchy while preventing
    // SwiftUI from flattening the title, summary, and author into one element.
    .accessibilityElement(children: .contain)
  }


  @ViewBuilder
  private var metadata: some View {
    let values = metadataValues
    if !values.isEmpty {
      LazyVGrid(columns: metadataColumns, spacing: 12) {
        ForEach(values) { value in
          VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
              Image(systemName: value.systemImage)
                .accessibilityHidden(true)
              Text(value.label)
            }
            .foregroundStyle(Color("IconMark"))
            Text(value.value)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(14)
          .background(Color("SubtleFill"), in: .rect(cornerRadius: 12))
          // The card is visually two Text views plus a decorative symbol, but
          // semantically it is one fact. A native Text representation gives a
          // predictable spoken phrase and role on both platforms. Combining
          // the visual children directly produced unstable macOS roles and
          // different label/value exposure between iOS and macOS.
          .accessibilityRepresentation {
            Text("\(value.label), \(value.value)")
              // The identifier names the concept, while the spoken value may
              // change with recipe content. Tests can therefore find Yield
              // without encoding its current wording into the query.
              .accessibilityIdentifier("recipe-metadata-\(value.label.lowercased())")
          }
        }
      }
    }
  }

  private var metadataColumns: [GridItem] {
    // Adaptive cards work well at ordinary sizes. Accessibility sizes use one
    // column so long localized labels and values can reflow without competing
    // horizontally for space.
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
        if let url = RecipeSourceURLPolicy.validatedURL(recipeSource.canonicalURL),
           let host = RecipeSourceURLPolicy.displayHost(for: url) {
          Link(destination: url) {
            VStack(alignment: .trailing, spacing: 2) {
              Text(recipeSource.title ?? "Open Source")
              // Imported titles are untrusted display text. Keeping the actual
              // destination host visible prevents a title from disguising a
              // cross-origin link and remains useful for ordinary attribution.
              Text(host)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        } else {
          VStack(alignment: .trailing, spacing: 2) {
            Text(recipeSource.title ?? recipeSource.kind.rawValue.capitalized)
              .foregroundStyle(.primary)
            if recipeSource.canonicalURL != nil {
              Text("Link unavailable")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
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
          // The adjacent heading supplies the section name; announcing the SF
          // Symbol would duplicate it and expose an implementation detail.
          .accessibilityHidden(true)
        Text(title)
          .accessibilityLabel(title)
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
    // Each section is a navigable landmark whose headings and content remain
    // separate descendants. `.combine` would turn an entire ingredient or
    // instruction section into one unwieldy accessibility element.
    .accessibilityElement(children: .contain)
  }

  private func bullet(_ text: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: "circle.fill")
        .font(.system(size: 5))
        .foregroundStyle(Color("AccentColor"))
        // This dot conveys list styling only. The ingredient/equipment Text is
        // already a complete description and retains its native static-text
        // role, which is especially important to macOS accessibility audits.
        .accessibilityHidden(true)
      Text(text)
        .textSelection(.enabled)
    }
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
    // A cooking step is one idea even though its visual treatment uses several
    // views. Supply an explicit sentence so VoiceOver reads the step number,
    // optional name, instruction, and duration in the intended order.
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
    // Separators alone do not reliably create a pause in synthesized speech.
    // Preserve authored punctuation and add a period only when one is absent.
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
