// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import SwiftUI

struct RecipeEditorView: View {
  enum Mode {
    case create
    case revise
    case importReview

    var title: String {
      switch self {
      case .create: "New Recipe"
      case .revise: "Edit Recipe"
      case .importReview: "Review Import"
      }
    }

    var saveLabel: String {
      self == .revise ? "Save Revision" : "Create Recipe"
    }
  }

  let mode: Mode
  let save: (RecipeDraft) -> Bool
  let reviewConcerns: [RecipeImportConcern]
  private let preservedSourceCapture: RecipeSourceCapture?
  private let preservedCuisines: [String]
  private let preservedCategories: [String]
  private let preservedKeywords: [String]

  @Environment(\.dismiss) private var dismiss
  @State private var title: String
  @State private var summary: String
  @State private var authorName: String
  @State private var recipeYield: RecipeYield?
  @State private var prepMinutes: String
  @State private var cookMinutes: String
  @State private var totalMinutes: String
  @State private var sourceKind: RecipeSource.Kind
  @State private var sourceTitle: String
  @State private var sourceAuthor: String
  @State private var sourcePublisher: String
  @State private var sourceURL: String
  @State private var ingredientSections: [IngredientSection]
  @State private var instructionSections: [InstructionSection]

  init(
    mode: Mode,
    draft: RecipeDraft = RecipeDraft(),
    reviewConcerns: [RecipeImportConcern] = [],
    save: @escaping (RecipeDraft) -> Bool
  ) {
    self.mode = mode
    self.save = save
    self.reviewConcerns = reviewConcerns
    preservedSourceCapture = draft.sourceCapture
    preservedCuisines = draft.cuisines
    preservedCategories = draft.categories
    preservedKeywords = draft.keywords
    _title = State(initialValue: draft.title)
    _summary = State(initialValue: draft.summary ?? "")
    _authorName = State(initialValue: draft.authorName ?? "")
    _recipeYield = State(initialValue: draft.recipeYield)
    _prepMinutes = State(initialValue: Self.minutes(draft.prepDuration))
    _cookMinutes = State(initialValue: Self.minutes(draft.cookDuration))
    _totalMinutes = State(initialValue: Self.minutes(draft.totalDuration))
    _sourceKind = State(initialValue: draft.source?.kind ?? .original)
    _sourceTitle = State(initialValue: draft.source?.title ?? "")
    _sourceAuthor = State(initialValue: draft.source?.authorName ?? "")
    _sourcePublisher = State(initialValue: draft.source?.publisherName ?? "")
    _sourceURL = State(initialValue: draft.source?.canonicalURL?.absoluteString ?? "")
    _ingredientSections = State(initialValue: draft.ingredientSections)
    _instructionSections = State(initialValue: draft.instructionSections)
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
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(mode.saveLabel) { if save(draft) { dismiss() } }
            .disabled(
              title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                sourceURLValidationMessage != nil
            )
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
            Label(concern.reviewMessage, systemImage: "info.circle")
              .foregroundStyle(.secondary)
          } else {
            Label(concern.reviewMessage, systemImage: "exclamationmark.triangle")
              .foregroundStyle(.orange)
          }
        }
      }
    } header: {
      Text("Import Review")
    } footer: {
      Text(
        "Check the imported wording and structure before saving. Review and save do not "
          + "contact the source again. Saving keeps the final source URL and bounded JSON-LD "
          + "metadata locally, including fields not shown here."
      )
    }
  }

  private var recipeSection: some View {
    Section("Recipe") {
      EditorTextField("Title", text: $title)
        .accessibilityIdentifier("recipe-editor-title")
      EditorTextField("Summary", text: $summary, multiline: true)
        .accessibilityIdentifier("recipe-editor-summary")
      EditorTextField("Recipe author", text: $authorName)
      RecipeYieldEditor(recipeYield: $recipeYield)
    }
  }

  private var timingSection: some View {
    Section("Times") {
      EditorTextField("Prep minutes", text: $prepMinutes)
      EditorTextField("Cook minutes", text: $cookMinutes)
      EditorTextField("Total minutes", text: $totalMinutes)
    }
  }

  private var sourceSection: some View {
    Section("Source") {
      Picker(selection: $sourceKind) {
        ForEach(RecipeSource.Kind.allCases, id: \.self) { Text($0.label).tag($0) }
      } label: {
        EditorFieldLabel("Source type")
      }
      EditorTextField("Source title", text: $sourceTitle)
      EditorTextField("Source author", text: $sourceAuthor)
      EditorTextField("Publisher", text: $sourcePublisher)
      EditorTextField("Source URL", text: $sourceURL)
      if let sourceURLValidationMessage {
        Label(sourceURLValidationMessage, systemImage: "exclamationmark.triangle")
          .foregroundStyle(.red)
          .accessibilityIdentifier("recipe-editor-source-url-error")
      }
    }
  }

  private var ingredientsSection: some View {
    Section {
      ForEach(ingredientSections.indices, id: \.self) { sectionIndex in
        IngredientSectionEditor(
          section: $ingredientSections[sectionIndex],
          moveUp: { moveIngredientSection(sectionIndex, by: -1) },
          moveDown: { moveIngredientSection(sectionIndex, by: 1) },
          delete: { ingredientSections.remove(at: sectionIndex) }
        )
        .id("ingredient-section-\(ingredientSections[sectionIndex].id.rawValue.uuidString)")
      }
      Button("Add Ingredient Section", systemImage: "plus") {
        ingredientSections.append(IngredientSection(title: nil, ingredients: []))
      }
      .accessibilityIdentifier("add-ingredient-section")
    } header: { Text("Ingredients") } footer: {
      Text("Original wording is retained separately from the structured interpretation.")
    }
  }

  private var instructionsSection: some View {
    Section {
      ForEach(instructionSections.indices, id: \.self) { sectionIndex in
        InstructionSectionEditor(
          section: $instructionSections[sectionIndex],
          moveUp: { moveInstructionSection(sectionIndex, by: -1) },
          moveDown: { moveInstructionSection(sectionIndex, by: 1) },
          delete: { instructionSections.remove(at: sectionIndex) }
        )
        .id("instruction-section-\(instructionSections[sectionIndex].id.rawValue.uuidString)")
      }
      Button("Add Instruction Section", systemImage: "plus") {
        instructionSections.append(InstructionSection(title: nil, steps: []))
      }
      .accessibilityIdentifier("add-instruction-section")
    } header: { Text("Instructions") }
  }

  private var draft: RecipeDraft {
    RecipeDraft(
      title: title, summary: summary, authorName: authorName, source: source,
      sourceCapture: preservedSourceCapture,
      recipeYield: cleanedRecipeYield,
      prepDuration: duration(prepMinutes), cookDuration: duration(cookMinutes), totalDuration: duration(totalMinutes),
      cuisines: preservedCuisines, categories: preservedCategories, keywords: preservedKeywords,
      ingredientSections: ingredientSections, instructionSections: instructionSections
    )
  }

  private var cleanedRecipeYield: RecipeYield? {
    guard var recipeYield else { return nil }
    recipeYield.unitText = recipeYield.unitText.flatMap(text)
    let originalText = text(recipeYield.originalText)
    if let originalText {
      recipeYield.originalText = originalText
    } else if let quantityText = recipeYield.quantity?.renderedText {
      recipeYield.originalText = [quantityText, recipeYield.unitText]
        .compactMap { $0 }
        .joined(separator: " ")
    } else {
      return nil
    }
    return recipeYield
  }

  private var source: RecipeSource? {
    let canonicalURL = RecipeSourceURLPolicy.validatedURL(from: sourceURL)
    guard
      text(sourceTitle) != nil ||
        text(sourceAuthor) != nil ||
        text(sourcePublisher) != nil ||
        canonicalURL != nil
    else { return nil }
    return RecipeSource(
        kind: sourceKind,
        title: text(sourceTitle),
        authorName: text(sourceAuthor),
        publisherName: text(sourcePublisher),
        canonicalURL: canonicalURL
    )
  }

  private var sourceURLValidationMessage: String? {
    guard text(sourceURL) != nil else { return nil }
    guard RecipeSourceURLPolicy.validatedURL(from: sourceURL) == nil else { return nil }
    return "Enter a complete http or https URL without embedded credentials."
  }

  private func moveIngredientSection(_ index: Int, by offset: Int) {
    let destination = index + offset
    guard ingredientSections.indices.contains(destination) else { return }
    ingredientSections.swapAt(index, destination)
  }
  private func moveInstructionSection(_ index: Int, by offset: Int) {
    let destination = index + offset
    guard instructionSections.indices.contains(destination) else { return }
    instructionSections.swapAt(index, destination)
  }
  private func text(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
  private func duration(_ minutes: String) -> RecipeDuration? {
    let maximumMinutes = ImportEditorLimits.maximumDurationSeconds / 60
    guard let value = Int(minutes), value >= 0, value <= maximumMinutes else { return nil }
    return RecipeDuration(seconds: value * 60)
  }
  private static func minutes(_ duration: RecipeDuration?) -> String {
    duration.map { String($0.seconds / 60) } ?? ""
  }
}

private enum ImportEditorLimits {
  // Match the importer's generous one-year ceiling. Bounding before
  // multiplication prevents pasted numeric text from trapping on overflow.
  static let maximumDurationSeconds = 366 * 24 * 60 * 60
}

private extension RecipeImportConcern {
  var reviewMessage: String {
    switch self {
    case .missingTitle: "Title needs attention"
    case .missingIngredients: "No ingredients were found"
    case .missingInstructions: "No instructions were found"
    case .unparsedIngredients(let count):
      "\(count) ingredient \(count == 1 ? "line is" : "lines are") preserved but unparsed"
    case .provisionalIngredients(let count):
      "\(count) ingredient \(count == 1 ? "interpretation needs" : "interpretations need") review"
    case .ignoredSourceBlocks(let count):
      "\(count) malformed or unsupported source \(count == 1 ? "block was" : "blocks were") ignored"
    case .preservedTaxonomy(let cuisines, let categories, let keywords):
      "Preserved metadata — \(taxonomySummary(cuisines: cuisines, categories: categories, keywords: keywords))"
    case .referencedImages(let count):
      "\(count) source \(count == 1 ? "image is" : "images are") referenced but not downloaded"
    }
  }

  private func taxonomySummary(
    cuisines: [String],
    categories: [String],
    keywords: [String]
  ) -> String {
    var groups: [String] = []
    if !cuisines.isEmpty { groups.append("cuisine: \(cuisines.joined(separator: ", "))") }
    if !categories.isEmpty { groups.append("categories: \(categories.joined(separator: ", "))") }
    if !keywords.isEmpty { groups.append("keywords: \(keywords.joined(separator: ", "))") }
    return groups.joined(separator: "; ")
  }
}

private extension RecipeSource.Kind {
  static var allCases: [Self] { [.original, .webpage, .book, .person, .imported] }
  var label: String { rawValue.capitalized }
}
