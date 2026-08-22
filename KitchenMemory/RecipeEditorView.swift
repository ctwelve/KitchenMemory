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

  @Environment(\.dismiss) private var dismiss
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
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
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
