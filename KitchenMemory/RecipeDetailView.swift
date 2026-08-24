// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import KitchenMemoryLogic
import KitchenMemoryPersistence
import SwiftUI

struct RecipeDetailView: View {
  let storedRecipe: StoredRecipe

  @State private var scalingSelection: RecipeScalingState

  // The metadata grid collapses before large text makes its cards cramped.
  // @ScaledMetric separately keeps the numbered instruction badge in step
  // with the text size instead of clipping a larger numeral in a fixed circle.
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(\.locale) private var locale
  @ScaledMetric(relativeTo: .headline) private var stepNumberSize = 30

  private var revision: RecipeRevision { storedRecipe.revision }

  init(storedRecipe: StoredRecipe) {
    self.storedRecipe = storedRecipe
    _scalingSelection = State(
      initialValue: RecipeScalingState(recipeYield: storedRecipe.revision.recipeYield)
    )
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        hero
        header
        metadata
        RecipeScalingControls(selection: $scalingSelection)
        source
        if !revision.equipment.isEmpty {
          recipeSection(
            .recipeDetailEquipmentSection,
            systemImage: "frying.pan",
            accessibilityIdentifier: "equipment-section"
          ) {
            VStack(alignment: .leading, spacing: 10) {
              HStack(spacing: 6) {
                Image(systemName: "info.circle").accessibilityHidden(true)
                Text(.recipeDetailEquipmentScalingNote)
                  .accessibilityIdentifier("equipment-scaling-help")
              }
              .font(.caption)
              .foregroundStyle(.secondary)
              ForEach(revision.equipment) { item in
                bullet(item.originalText)
              }
            }
          }
        }

        recipeSection(
          .recipeDetailIngredientsSection,
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
                  ScaledIngredientRow(ingredient: ingredient, scale: scalingSelection.scale)
                }
              }
              .accessibilityElement(children: .contain)
            }
          }
        }
        recipeSection(
          .recipeDetailInstructionsSection,
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
    .accessibilityLabel(Text(.recipeDetailAccessibilityLabel(title: revision.title)))
    .background(Color("AppBackground"))
    .navigationTitle(revision.title)
#if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
#endif
  }
}

private extension RecipeDetailView {
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
        Text(.recipeDetailAuthor(author: authorName))
          .font(.subheadline)
          .foregroundStyle(.primary)
          .accessibilityLabel(Text(.recipeDetailAuthor(author: authorName)))
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
            Text(.recipeMetadataAccessibilityValue(label: value.label, value: value.value))
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
    if revision.recipeYield != nil {
      values.append(
        .init(
          label: LocalizedStringResource.recipeMetadataYield.localized(for: locale),
          value: scalingSelection.displayedYield(locale: locale),
          systemImage: "person.2"
        )
      )
    }
    if let prepDuration = revision.prepDuration {
      values.append(
        .init(
          label: LocalizedStringResource.recipeMetadataPrep.localized(for: locale),
          value: duration(prepDuration),
          systemImage: "clock"
        )
      )
    }
    if let cookDuration = revision.cookDuration {
      values.append(
        .init(
          label: LocalizedStringResource.recipeMetadataCook.localized(for: locale),
          value: duration(cookDuration),
          systemImage: "flame"
        )
      )
    }
    if let totalDuration = revision.totalDuration {
      values.append(
        .init(
          label: LocalizedStringResource.recipeMetadataTotal.localized(for: locale),
          value: duration(totalDuration),
          systemImage: "timer"
        )
      )
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
              Text(
                recipeSource.title
                  ?? LocalizedStringResource.recipeSourceActionOpen.localized(for: locale)
              )
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
              Text(.recipeSourceLinkUnavailable)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "link")
            .accessibilityHidden(true)
          Text(.recipeSourceLabel)
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
    RecipePresentationFormatter(locale: locale).duration(duration)
  }

  private func recipeSection<Content: View>(
    _ title: LocalizedStringResource,
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
          .accessibilityLabel(Text(title))
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
    .accessibilityLabel(
      RecipeInstructionAccessibilityFormatter(locale: locale).label(number: number, step: step)
    )
  }
}
