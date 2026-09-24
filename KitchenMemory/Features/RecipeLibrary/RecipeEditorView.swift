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
  }

  let organization: RecipeOrganizationModel?
  let mode: Mode
  let save: () -> Bool
  let close: () -> Void
  let discard: () -> Void
  let reviewConcerns: [RecipeImportConcern]

  @Environment(\.locale) private var locale
  @Bindable var editor: RecipeEditingModel

  init(
    mode: Mode,
    editor: RecipeEditingModel,
    organization: RecipeOrganizationModel? = nil,
    close: @escaping () -> Void,
    discard: @escaping () -> Void,
    save: @escaping () -> Bool
  ) {
    self.organization = organization
    self.mode = mode
    self.save = save
    self.reviewConcerns = editor.concerns
    self.editor = editor
    self.close = close
    self.discard = discard
  }

  var body: some View {
    NavigationStack {
      Group {
#if os(macOS)
        // List owns the scrolling viewport as the detail column resizes.
        List {
          editorSections
        }
        .disabled(editor.pendingSave != nil)
        .listStyle(.inset)
        .accessibilityIdentifier("recipe-editor-scroll")
#else
        Form {
          editorSections
        }
        .disabled(editor.pendingSave != nil)
        .accessibilityIdentifier("recipe-editor-scroll")
#endif
      }
      .textFieldStyle(.roundedBorder)
      .navigationTitle(mode.title)
#if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
#endif
      .toolbar {
        ToolbarItem(placement: .automatic) {
          if mode != .importReview {
          Button(editor.usesAdvancedEditor ? .recipeEditorSimpleMode : .recipeEditorAdvancedMode) {
            editor.setAdvancedEditor(!editor.usesAdvancedEditor, locale: locale)
          }
          .accessibilityIdentifier("recipe-editor-mode")
          }
        }
        ToolbarItem(placement: .cancellationAction) {
          Button(.recipeEditorActionClose) {
            editor.draft.finishIngredientText(locale: locale)
            close()
          }.help(Text(.recipeEditorActionClose))
        }
        ToolbarItem(placement: .destructiveAction) {
          Button(.recipeEditorActionDiscard, role: .destructive) { editor.confirmsDiscard = true }
            .help(Text(.recipeEditorActionDiscard))
            .disabled(editor.pendingSave != nil)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(editor.isImportCandidate ? .recipeImportAcceptDraft : .recipeEditorReviseActionSave) {
            editor.draft.finishIngredientText(locale: locale)
            _ = save()
          }
            .disabled(!editor.isImportCandidate && !editor.canSaveRevision)
            .accessibilityIdentifier("recipe-editor-save")
            .help(Text(editor.isImportCandidate ? .recipeImportAcceptDraft : .recipeEditorReviseActionSave))
        }
      }
      .confirmationDialog(.recipeEditorDiscardConfirmation, isPresented: $editor.confirmsDiscard) {
        Button(.recipeEditorActionDiscard, role: .destructive, action: discard)
        Button(.actionCancel, role: .cancel) {}
      }
    }
  }
}

private extension RecipeEditorView {
  @ViewBuilder
  private var editorSections: some View {
    if !editor.usesAdvancedEditor && mode != .importReview
      && (editor.draft.reconciliation == nil || editor.draft.reconciliation?.draft != nil) {
      RecipeSimpleEditor(editor: editor)
    } else if editor.session.ingredientText?.conflicts.isEmpty == false {
      IngredientInterpretationReview(editor: editor)
    }
    if let organization {
      RecipeOrganizationEditor(model: organization, draft: editor.draft)
      OrganizationManagementButton(model: organization)
    }
    if editor.draft.reconciliation != nil {
      RecipeReconciliationView(editor: editor)
    }
    if mode == .importReview {
      importReviewSection
    }
    if (editor.usesAdvancedEditor || mode == .importReview)
      && (editor.draft.reconciliation == nil || editor.draft.reconciliation?.draft != nil) {
    recipeSection
    timingSection
    sourceSection
    RecipeMediaEditorView(session: $editor.session)
    RecipeEquipmentEditorView(session: $editor.session)
    ingredientsSection
    instructionsSection
    }
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
      EditorTextField(.recipeEditorTitleField, text: $editor.session.title)
        .accessibilityIdentifier("recipe-editor-title")
      if editor.session.validationIssues.contains(.missingTitle) {
        Label(.recipeEditorTitleValidation, systemImage: "exclamationmark.triangle")
          .foregroundStyle(.red)
      }
      EditorTextField(.recipeEditorSummaryField, text: $editor.session.summary, multiline: true)
        .accessibilityIdentifier("recipe-editor-summary")
      EditorTextField(.recipeEditorAuthorField, text: $editor.session.authorName)
      RecipeYieldEditor(recipeYield: $editor.session.recipeYield)
    }
  }

  private var timingSection: some View {
    Section(.recipeEditorTimesSection) {
      durationField(.recipeEditorTimePreparationField, text: $editor.session.prepMinutes, field: .preparation)
      durationField(.recipeEditorTimeCookingField, text: $editor.session.cookMinutes, field: .cooking)
      durationField(.recipeEditorTimeTotalField, text: $editor.session.totalMinutes, field: .total)
    }
  }

  private var sourceSection: some View {
    Section(.recipeEditorSourceSection) {
      sourceKindField
      EditorTextField(.recipeEditorSourceTitleField, text: $editor.session.sourceTitle)
      EditorTextField(.recipeEditorSourceAuthorField, text: $editor.session.sourceAuthor)
      EditorTextField(.recipeEditorSourcePublisherField, text: $editor.session.sourcePublisher)
      EditorTextField(.recipeEditorSourceUrlField, text: $editor.session.sourceURL)
      if editor.session.validationIssues.contains(.invalidSourceURL) {
        Label(
          .recipeEditorSourceUrlValidation,
          systemImage: "exclamationmark.triangle"
        )
          .foregroundStyle(.red)
          .accessibilityIdentifier("recipe-editor-source-url-error")
      }
    }
  }

  private var sourceKindPicker: some View {
    Picker(selection: $editor.session.sourceKind) {
      ForEach(RecipeSource.Kind.allCases, id: \.self) { Text($0.label).tag($0) }
    } label: {
      EditorFieldLabel(.recipeEditorSourceKindField)
    }
  }

  @ViewBuilder
  private var sourceKindField: some View {
#if os(macOS)
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 12) {
        EditorFieldLabel(.recipeEditorSourceKindField)
        sourceKindPicker.labelsHidden().fixedSize()
      }
      VStack(alignment: .leading, spacing: 6) {
        EditorFieldLabel(.recipeEditorSourceKindField)
        sourceKindPicker.labelsHidden()
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
#else
    sourceKindPicker
#endif
  }

  private var ingredientsSection: some View {
    Section {
      ForEach(Array(editor.session.ingredientSections.enumerated()), id: \.element.id) { sectionIndex, section in
        IngredientSectionEditor(
          editor: editor,
          section: section,
          moveUp: { editor.draft.moveIngredientSection(section.id, by: -1) },
          moveDown: { editor.draft.moveIngredientSection(section.id, by: 1) },
          delete: { editor.draft.removeIngredientSection(section.id) }
        )
        .modifier(EditorGroupSurface(index: sectionIndex))
      }
      Button(.recipeEditorIngredientsActionAddSection, systemImage: "plus") {
        editor.draft.addIngredientSection()
      }
      .accessibilityIdentifier("add-ingredient-section")
    } header: { Text(.recipeEditorIngredientsSection) } footer: {
      Text(.recipeEditorIngredientsOriginalWordingNote)
    }
  }

  private var instructionsSection: some View {
    Section {
      ForEach(editor.session.instructionSections.indices, id: \.self) { sectionIndex in
        InstructionSectionEditor(
          section: $editor.session.instructionSections[sectionIndex],
          moveUp: { editor.session.moveInstructionSection(at: sectionIndex, by: -1) },
          moveDown: { editor.session.moveInstructionSection(at: sectionIndex, by: 1) },
          delete: { editor.session.instructionSections.remove(at: sectionIndex) }
        )
        .id("instruction-section-\(editor.session.instructionSections[sectionIndex].id.rawValue.uuidString)")
        .modifier(EditorGroupSurface(index: sectionIndex))
      }
      Button(.recipeEditorInstructionsActionAddSection, systemImage: "plus") {
        editor.session.instructionSections.append(InstructionSection(title: nil, steps: []))
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
      if editor.session.validationIssues.contains(.invalidDuration(field)) {
        Label(.recipeEditorTimeValidation, systemImage: "exclamationmark.triangle")
          .foregroundStyle(.red)
      }
    }
  }
}

// Pure wording generation must not inherit the app's default MainActor isolation.
nonisolated extension RecipeImportConcern {
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
