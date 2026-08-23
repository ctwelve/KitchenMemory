// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import KitchenMemoryLogic
import SwiftUI

struct RecipeEditorView: View {
  enum Mode {
    case create
    case revise
    case importReview

    func title(locale: Locale) -> String {
      switch self {
      case .create: String(localized: "New Recipe", locale: locale)
      case .revise: String(localized: "Edit Recipe", locale: locale)
      case .importReview: String(localized: "Review Import", locale: locale)
      }
    }

    func saveLabel(locale: Locale) -> String {
      self == .revise
        ? String(localized: "Save Revision", locale: locale)
        : String(localized: "Create Recipe", locale: locale)
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
      .navigationTitle(mode.title(locale: locale))
#if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
#endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(mode.saveLabel(locale: locale)) {
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
        Label("Import is ready for your review", systemImage: "eye")
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
      Text("Import Review")
    } footer: {
      // swiftlint:disable:next line_length
      Text("Check the imported wording and structure before saving. Review and save do not contact the source again. Saving keeps the final source URL and bounded JSON-LD metadata locally, including fields not shown here.")
    }
  }

  private var recipeSection: some View {
    Section("Recipe") {
      EditorTextField("Title", text: $session.title)
        .accessibilityIdentifier("recipe-editor-title")
      EditorTextField("Summary", text: $session.summary, multiline: true)
        .accessibilityIdentifier("recipe-editor-summary")
      EditorTextField("Recipe author", text: $session.authorName)
      RecipeYieldEditor(recipeYield: $session.recipeYield)
    }
  }

  private var timingSection: some View {
    Section("Times") {
      durationField("Prep minutes", text: $session.prepMinutes, field: .preparation)
      durationField("Cook minutes", text: $session.cookMinutes, field: .cooking)
      durationField("Total minutes", text: $session.totalMinutes, field: .total)
    }
  }

  private var sourceSection: some View {
    Section("Source") {
      Picker(selection: $session.sourceKind) {
        ForEach(RecipeSource.Kind.allCases, id: \.self) { Text($0.label).tag($0) }
      } label: {
        EditorFieldLabel("Source type")
      }
      EditorTextField("Source title", text: $session.sourceTitle)
      EditorTextField("Source author", text: $session.sourceAuthor)
      EditorTextField("Publisher", text: $session.sourcePublisher)
      EditorTextField("Source URL", text: $session.sourceURL)
      if session.validationIssues.contains(.invalidSourceURL) {
        Label(
          "Enter a complete http or https URL without embedded credentials.",
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
      Button("Add Ingredient Section", systemImage: "plus") {
        session.ingredientSections.append(IngredientSection(title: nil, ingredients: []))
      }
      .accessibilityIdentifier("add-ingredient-section")
    } header: { Text("Ingredients") } footer: {
      Text("Original wording is retained separately from the structured interpretation.")
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
      Button("Add Instruction Section", systemImage: "plus") {
        session.instructionSections.append(InstructionSection(title: nil, steps: []))
      }
      .accessibilityIdentifier("add-instruction-section")
    } header: { Text("Instructions") }
  }

  private func durationField(
    _ title: String,
    text: Binding<String>,
    field: RecipeEditDurationField
  ) -> some View {
    Group {
      EditorTextField(title, text: text)
      if session.validationIssues.contains(.invalidDuration(field)) {
        Label("Enter whole minutes from 0 through 527040.", systemImage: "exclamationmark.triangle")
          .foregroundStyle(.red)
      }
    }
  }
}

extension RecipeImportConcern {
  func reviewMessage(locale: Locale = .current) -> String {
    switch self {
    case .missingTitle:
      return localized("Title needs attention", locale: locale)
    case .missingIngredients:
      return localized("No ingredients were found", locale: locale)
    case .missingInstructions:
      return localized("No instructions were found", locale: locale)
    case .unparsedIngredients(let count):
      return localized("\(count) ingredient line is preserved but unparsed", locale: locale)
    case .provisionalIngredients(let count):
      return localized("\(count) ingredient interpretation needs review", locale: locale)
    case .ignoredSourceBlocks(let count):
      return localized("\(count) malformed or unsupported source block was ignored", locale: locale)
    case .preservedTaxonomy(let cuisines, let categories, let keywords):
      let summary = taxonomySummary(
        cuisines: cuisines,
        categories: categories,
        keywords: keywords,
        locale: locale
      )
      return localized("Preserved metadata — \(summary)", locale: locale)
    case .referencedImages(let count):
      return localized("\(count) source image is referenced but not downloaded", locale: locale)
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
      groups.append(String(
        localized: "Cuisine: \(cuisines.joined(separator: ", "))",
        bundle: .kitchenMemory(for: locale),
        locale: locale
      ))
    }
    if !categories.isEmpty {
      groups.append(String(
        localized: "Categories: \(categories.joined(separator: ", "))",
        bundle: .kitchenMemory(for: locale),
        locale: locale
      ))
    }
    if !keywords.isEmpty {
      groups.append(String(
        localized: "Keywords: \(keywords.joined(separator: ", "))",
        bundle: .kitchenMemory(for: locale),
        locale: locale
      ))
    }
    return groups.joined(separator: "; ")
  }

  private func localized(_ value: String.LocalizationValue, locale: Locale) -> String {
    String(localized: value, bundle: .kitchenMemory(for: locale), locale: locale)
  }
}

private extension RecipeSource.Kind {
  static var allCases: [Self] { [.original, .webpage, .book, .person, .imported] }
  var label: String {
    switch self {
    case .original: String(localized: "Original")
    case .webpage: String(localized: "Webpage")
    case .book: String(localized: "Book")
    case .person: String(localized: "Person")
    case .imported: String(localized: "Imported")
    }
  }
}
