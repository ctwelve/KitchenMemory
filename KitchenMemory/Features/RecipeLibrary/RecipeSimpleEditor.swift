// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct RecipeSimpleEditor: View {
  @Bindable var editor: RecipeEditingModel
  @Environment(\.locale) private var locale
  @State private var textActions = IngredientTextActions()
  @ScaledMetric(relativeTo: .body) private var textHeight = 240

  var body: some View {
    Section {
      EditorTextField(.recipeEditorTitleField, text: $editor.session.title)
        .accessibilityIdentifier("recipe-editor-title")
    }
    Section {
      VStack(alignment: .leading, spacing: 0) {
        if editor.session.ingredientText != nil {
          NativeIngredientText(draft: editor.draft, actions: textActions)
            .frame(height: textHeight)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.4)))
        }
        IngredientInterpretationReview(editor: editor)
      }
      Button(.recipeEditorIngredientsActionAddSection, systemImage: "plus") {
        textActions.addSection(LocalizedStringResource.recipeEditorSectionDefault.localized(for: locale))
      }
      DisclosureGroup(.recipeEditorPrecision) {
        ForEach(editor.session.ingredientSections) { section in
          ForEach(section.ingredients) { ingredient in
            IngredientEditor(ingredient: editor.ingredientBinding(ingredient),
                             moveUp: { editor.draft.moveIngredient(ingredient.id, by: -1) },
                             moveDown: { editor.draft.moveIngredient(ingredient.id, by: 1) },
                             delete: { editor.draft.removeIngredient(ingredient.id) })
          }
        }
      }
      VStack(alignment: .leading) {
        Text(.recipeEditorSimpleHelp)
          .font(.caption)
          .lineLimit(nil)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    } header: { Text(.recipeEditorIngredientsSection).accessibilityHeading(.h2) }
    Section {
      ForEach(editor.session.instructionSections.indices, id: \.self) { section in
        instructionSection(section)
          .id(editor.session.instructionSections[section].id)
          .modifier(EditorGroupSurface(index: section))
      }
      Button(.recipeEditorInstructionsActionAddStep, systemImage: "plus") {
        if editor.session.instructionSections.isEmpty {
          editor.session.instructionSections = [InstructionSection(title: nil, steps: [])]
        }
        let last = editor.session.instructionSections.count - 1
        editor.session.instructionSections[last].steps.append(InstructionStep(text: ""))
      }
    } header: { Text(.recipeEditorInstructionsSection).accessibilityHeading(.h2) }
    .onAppear { prepareText() }
  }

  private func instructionSection(_ section: Int) -> some View {
    let title = editor.session.instructionSections[section].title
      ?? LocalizedStringResource.recipeEditorInstructionSectionFallbackTitle.localized(for: locale)
    return VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.title3.weight(.semibold))
        .accessibilityHeading(.h3)
      ForEach(editor.session.instructionSections[section].steps.indices, id: \.self) { step in
        VStack(alignment: .leading, spacing: 8) {
          if let name = editor.session.instructionSections[section].steps[step].name {
            Text(name)
              .font(.headline)
              .accessibilityHeading(.h4)
          }
          EditorTextField(.recipeEditorInstructionTextField,
                          text: $editor.session.instructionSections[section].steps[step].text, multiline: true)
        }
        .accessibilityElement(children: .contain)
        .id(editor.session.instructionSections[section].steps[step].id)
        .modifier(EditorGroupSurface(index: step, level: .item))
      }
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel(title)
  }

  private func prepareText() {
    let formatter = RecipePresentationFormatter(locale: locale)
    let wording = Dictionary(uniqueKeysWithValues: editor.session.ingredientSections.flatMap(\.ingredients)
      .map { ($0.id, formatter.ingredient($0)) })
    editor.draft.prepareIngredientText(displayWording: wording)
  }
}

/// Keeps interpretation choices after the native text field without replacing or refocusing it.
struct IngredientInterpretationReview: View {
  @Bindable var editor: RecipeEditingModel
  @Environment(\.locale) private var locale
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorSchemeContrast) private var contrast

  private var hasConflicts: Bool { editor.session.ingredientText?.conflicts.isEmpty == false }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let text = editor.session.ingredientText, !text.conflicts.isEmpty {
        VStack(alignment: .leading, spacing: 12) {
          Label(.recipeEditorInterpretationReview, systemImage: "info.circle")
            .font(.headline)
            .accessibilityHeading(.h3)
          Text(.recipeEditorInterpretationExplanation)
            .fixedSize(horizontal: false, vertical: true)
          ForEach(text.conflicts) { conflict in
            Divider()
            VStack(alignment: .leading, spacing: 8) {
              Text(conflict.proposed.originalText).font(.headline)
              let proposal = structured(conflict.proposed)
              Text(RecipePresentationFormatter(locale: locale).ingredient(proposal))
              ViewThatFits(in: .horizontal) {
                HStack { choices(conflict.id) }
                VStack(alignment: .leading) { choices(conflict.id) }
              }
            }
            .accessibilityElement(children: .contain)
          }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(contrast == .increased ? 0.2 : 0.12), in: .rect(cornerRadius: 12))
        .overlay {
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.accentColor.opacity(contrast == .increased ? 1 : 0.5), lineWidth: 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ingredient-interpretation-review")
        .padding(.top, 12)
        .transition(reduceMotion ? .identity : .move(edge: .top).combined(with: .opacity))
      }
    }
    .clipped()
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: hasConflicts)
    .onChange(of: hasConflicts) { _, needsReview in
      if needsReview {
        AccessibilityNotification.Announcement(
          LocalizedStringResource.recipeEditorInterpretationReview.localized(for: locale)
        ).post()
      }
    }
  }

  private func structured(_ ingredient: RecipeIngredient) -> RecipeIngredient {
    var value = ingredient
    value.presentationMode = .structured
    return value
  }

  private func choices(_ id: RecipeIngredient.ID) -> some View {
    Group {
      Button(.recipeEditorKeepDetails) { resolve(id, accept: false) }
      Button(.recipeEditorAcceptInterpretation) { resolve(id, accept: true) }
    }
  }

  private func resolve(_ id: RecipeIngredient.ID, accept: Bool) {
    editor.draft.resolveIngredientInterpretation(id, accepting: accept)
  }
}
