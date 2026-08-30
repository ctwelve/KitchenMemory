// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct RecipeEditorView: View {
  enum Mode {
    case create
    case revise
    case importReview

    var title: LocalizedStringResource {
      switch self {
      case .create: .recipeEditorCreateTitle
      case .revise: .recipeEditorReviseTitle
      case .importReview: .recipeEditorImportReviewTitle
      }
    }

    var saveLabel: LocalizedStringResource {
      self == .revise
        ? .recipeEditorReviseActionSave
        : .recipeEditorCreateActionSave
    }
  }

  let mode: Mode
  let save: (RecipeDraft) -> Bool
  let reviewConcerns: [RecipeImportConcern]

  @Environment(\.dismiss) private var dismiss
  @Environment(\.locale) private var locale
  @State private var session: RecipeEditSession

  init(
    mode: Mode,
    draft: RecipeDraft = RecipeDraft(),
    reviewConcerns: [RecipeImportConcern] = [],
    save: @escaping (RecipeDraft) -> Bool
  ) {
    self.mode = mode
    self.save = save
    self.reviewConcerns = reviewConcerns
    _session = State(initialValue: RecipeEditSession(draft: draft))
  }

  var body: some View {
    NavigationStack {
      Group {
#if os(macOS)
        // Form adopts its content's ideal height in a macOS sheet, so bounding
        // the sheet alone can clip the content without creating a scrollable
        // viewport. List owns its scroll view and still provides native Section
        // presentation and form controls.
        List {
          editorSections
        }
        .listStyle(.inset)
        .accessibilityIdentifier("recipe-editor-scroll")
#else
        Form {
          editorSections
        }
        .accessibilityIdentifier("recipe-editor-scroll")
#endif
      }
      .navigationTitle(mode.title)
#if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
#endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button(.actionCancel) { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(mode.saveLabel) {
            if let draft = try? session.validatedDraft(), save(draft) { dismiss() }
          }
            .disabled(!session.canSave)
            .accessibilityIdentifier("recipe-editor-save")
        }
      }
#if os(macOS)
      .frame(
        minWidth: 680,
        idealWidth: 760,
        maxWidth: 900,
        minHeight: 520,
        idealHeight: 680,
        maxHeight: 760
      )
#endif
    }
  }
}

private extension RecipeEditorView {
  @ViewBuilder
  private var editorSections: some View {
    if mode == .importReview {
      importReviewSection
    }
    recipeSection
    timingSection
    sourceSection
    ingredientsSection
    instructionsSection
  }

  private var importReviewSection: some View {
    Section {
      if reviewConcerns.isEmpty {
        Label(.recipeEditorImportReviewReady, systemImage: "eye")
          .foregroundStyle(.secondary)
      } else {
        ForEach(Array(reviewConcerns.enumerated()), id: \.offset) { _, concern in
          if concern.isInformational {
            Label(concern.reviewMessage(locale: locale), systemImage: "info.circle")
              .foregroundStyle(.secondary)
          } else {
            Label(concern.reviewMessage(locale: locale), systemImage: "exclamationmark.triangle")
              .foregroundStyle(.orange)
          }
        }
      }
    } header: {
      Text(.recipeEditorImportReviewSection)
    } footer: {
      Text(.recipeEditorImportReviewFooter)
    }
  }

  private var recipeSection: some View {
    Section(.recipeEditorRecipeSection) {
      EditorTextField(.recipeEditorTitleField, text: $session.title)
        .accessibilityIdentifier("recipe-editor-title")
      EditorTextField(.recipeEditorSummaryField, text: $session.summary, multiline: true)
        .accessibilityIdentifier("recipe-editor-summary")
      EditorTextField(.recipeEditorAuthorField, text: $session.authorName)
      RecipeYieldEditor(recipeYield: $session.recipeYield)
    }
  }

  private var timingSection: some View {
    Section(.recipeEditorTimesSection) {
      durationField(.recipeEditorTimePreparationField, text: $session.prepMinutes, field: .preparation)
      durationField(.recipeEditorTimeCookingField, text: $session.cookMinutes, field: .cooking)
      durationField(.recipeEditorTimeTotalField, text: $session.totalMinutes, field: .total)
    }
  }

  private var sourceSection: some View {
    Section(.recipeEditorSourceSection) {
      Picker(selection: $session.sourceKind) {
        ForEach(RecipeSource.Kind.allCases, id: \.self) { Text($0.label).tag($0) }
      } label: {
        EditorFieldLabel(.recipeEditorSourceKindField)
      }
      EditorTextField(.recipeEditorSourceTitleField, text: $session.sourceTitle)
      EditorTextField(.recipeEditorSourceAuthorField, text: $session.sourceAuthor)
      EditorTextField(.recipeEditorSourcePublisherField, text: $session.sourcePublisher)
      EditorTextField(.recipeEditorSourceUrlField, text: $session.sourceURL)
      if session.validationIssues.contains(.invalidSourceURL) {
        Label(
          .recipeEditorSourceUrlValidation,
          systemImage: "exclamationmark.triangle"
        )
          .foregroundStyle(.red)
          .accessibilityIdentifier("recipe-editor-source-url-error")
      }
    }
  }

  private var ingredientsSection: some View {
    Section {
      ForEach(session.ingredientSections.indices, id: \.self) { sectionIndex in
        IngredientSectionEditor(
          section: $session.ingredientSections[sectionIndex],
          moveUp: { session.moveIngredientSection(at: sectionIndex, by: -1) },
          moveDown: { session.moveIngredientSection(at: sectionIndex, by: 1) },
          delete: { session.ingredientSections.remove(at: sectionIndex) }
        )
        .id("ingredient-section-\(session.ingredientSections[sectionIndex].id.rawValue.uuidString)")
      }
      Button(.recipeEditorIngredientsActionAddSection, systemImage: "plus") {
        session.ingredientSections.append(IngredientSection(title: nil, ingredients: []))
      }
      .accessibilityIdentifier("add-ingredient-section")
    } header: { Text(.recipeEditorIngredientsSection) } footer: {
      Text(.recipeEditorIngredientsOriginalWordingNote)
    }
  }

  private var instructionsSection: some View {
    Section {
      ForEach(session.instructionSections.indices, id: \.self) { sectionIndex in
        InstructionSectionEditor(
          section: $session.instructionSections[sectionIndex],
          moveUp: { session.moveInstructionSection(at: sectionIndex, by: -1) },
          moveDown: { session.moveInstructionSection(at: sectionIndex, by: 1) },
          delete: { session.instructionSections.remove(at: sectionIndex) }
        )
        .id("instruction-section-\(session.instructionSections[sectionIndex].id.rawValue.uuidString)")
      }
      Button(.recipeEditorInstructionsActionAddSection, systemImage: "plus") {
        session.instructionSections.append(InstructionSection(title: nil, steps: []))
      }
      .accessibilityIdentifier("add-instruction-section")
    } header: { Text(.recipeEditorInstructionsSection) }
  }

  private func durationField(
    _ title: LocalizedStringResource,
    text: Binding<String>,
    field: RecipeEditDurationField
  ) -> some View {
    Group {
      EditorTextField(title, text: text)
      if session.validationIssues.contains(.invalidDuration(field)) {
        Label(.recipeEditorTimeValidation, systemImage: "exclamationmark.triangle")
          .foregroundStyle(.red)
      }
    }
  }
}

extension RecipeImportConcern {
  func reviewMessage(locale: Locale = .current) -> String {
    switch self {
    case .missingTitle:
      return LocalizedStringResource.recipeImportConcernMissingTitle.localized(for: locale)
    case .missingIngredients:
      return LocalizedStringResource.recipeImportConcernMissingIngredients.localized(for: locale)
    case .missingInstructions:
      return LocalizedStringResource.recipeImportConcernMissingInstructions.localized(for: locale)
    case .unparsedIngredients(let count):
      return LocalizedStringResource.recipeImportConcernUnparsedIngredientCount(count: count)
        .localized(for: locale)
    case .provisionalIngredients(let count):
      return LocalizedStringResource.recipeImportConcernProvisionalIngredientCount(count: count)
        .localized(for: locale)
    case .ignoredSourceBlocks(let count):
      return LocalizedStringResource.recipeImportConcernIgnoredSourceBlockCount(count: count)
        .localized(for: locale)
    case .preservedTaxonomy(let cuisines, let categories, let keywords):
      let summary = taxonomySummary(
        cuisines: cuisines,
        categories: categories,
        keywords: keywords,
        locale: locale
      )
      return LocalizedStringResource.recipeImportConcernPreservedMetadata(summary: summary)
        .localized(for: locale)
    case .referencedImages(let count):
      return LocalizedStringResource.recipeImportConcernReferencedImageCount(count: count)
        .localized(for: locale)
    }
  }

  private func taxonomySummary(
    cuisines: [String],
    categories: [String],
    keywords: [String],
    locale: Locale
  ) -> String {
    var groups: [String] = []
    if !cuisines.isEmpty {
      groups.append(
        LocalizedStringResource.recipeImportTaxonomyCuisine(
          values: cuisines.joined(separator: ", ")
        ).localized(for: locale)
      )
    }
    if !categories.isEmpty {
      groups.append(
        LocalizedStringResource.recipeImportTaxonomyCategories(
          values: categories.joined(separator: ", ")
        ).localized(for: locale)
      )
    }
    if !keywords.isEmpty {
      groups.append(
        LocalizedStringResource.recipeImportTaxonomyKeywords(
          values: keywords.joined(separator: ", ")
        ).localized(for: locale)
      )
    }
    return groups.joined(separator: "; ")
  }
}

private extension RecipeSource.Kind {
  static var allCases: [Self] { [.original, .webpage, .book, .person, .imported] }
  var label: LocalizedStringResource {
    switch self {
    case .original: .recipeSourceKindOriginal
    case .webpage: .recipeSourceKindWebpage
    case .book: .recipeSourceKindBook
    case .person: .recipeSourceKindPerson
    case .imported: .recipeSourceKindImported
    }
  }
}
