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
      if editor.session.ingredientText != nil {
        NativeIngredientText(document: textBinding, actions: textActions)
          .frame(height: textHeight)
          .overlay(RoundedRectangle(cornerRadius: 6).stroke(.secondary.opacity(0.4)))
      }
      Button(.recipeEditorIngredientsActionAddSection, systemImage: "plus") {
        textActions.addSection(LocalizedStringResource.recipeEditorSectionDefault.localized(for: locale))
      }
      DisclosureGroup(.recipeEditorPrecision) {
        ForEach(editor.session.ingredientSections.indices, id: \.self) { section in
          ForEach(editor.session.ingredientSections[section].ingredients.indices, id: \.self) { index in
            IngredientEditor(ingredient: $editor.session.ingredientSections[section].ingredients[index],
                             moveUp: { moveIngredient(section, index, by: -1) },
                             moveDown: { moveIngredient(section, index, by: 1) },
                             delete: { editor.session.ingredientSections[section].ingredients.remove(at: index) })
          }
        }
      }
    } header: { Text(.recipeEditorIngredientsSection) } footer: { Text(.recipeEditorSimpleHelp).fixedSize(horizontal: false, vertical: true) }
    Section(.recipeEditorInstructionsSection) {
      ForEach(editor.session.instructionSections.indices, id: \.self) { section in
        if let title = editor.session.instructionSections[section].title { Text(title).font(.headline) }
        ForEach(editor.session.instructionSections[section].steps.indices, id: \.self) { step in
          if let name = editor.session.instructionSections[section].steps[step].name { Text(name).font(.headline) }
          EditorTextField(.recipeEditorInstructionTextField,
                          text: $editor.session.instructionSections[section].steps[step].text, multiline: true)
        }
      }
      Button(.recipeEditorInstructionsActionAddStep, systemImage: "plus") {
        if editor.session.instructionSections.isEmpty {
          editor.session.instructionSections = [InstructionSection(title: nil, steps: [])]
        }
        let last = editor.session.instructionSections.count - 1
        editor.session.instructionSections[last].steps.append(InstructionStep(text: ""))
      }
    }
    .onAppear { prepareText() }
  }

  private var textBinding: Binding<RecipeIngredientTextDraft> {
    Binding(get: { editor.session.ingredientText ?? .init(sections: editor.session.ingredientSections) },
            set: { editor.session.updateIngredientText($0) })
  }

  private func prepareText() {
    let formatter = RecipePresentationFormatter(locale: locale)
    let wording = Dictionary(uniqueKeysWithValues: editor.session.ingredientSections.flatMap(\.ingredients)
      .map { ($0.id, formatter.ingredient($0)) })
    editor.session.prepareIngredientText(displayWording: wording)
  }

  private func moveIngredient(_ section: Int, _ index: Int, by offset: Int) {
    let destination = index + offset
    guard editor.session.ingredientSections[section].ingredients.indices.contains(destination) else { return }
    editor.session.ingredientSections[section].ingredients.swapAt(index, destination)
  }
}

struct IngredientInterpretationReview: View {
  @Bindable var editor: RecipeEditingModel
  @Environment(\.locale) private var locale

  var body: some View {
    if let text = editor.session.ingredientText, !text.conflicts.isEmpty {
      Section(.recipeEditorInterpretationReview) {
        Text(.recipeEditorInterpretationExplanation)
        ForEach(text.conflicts) { conflict in
          VStack(alignment: .leading, spacing: 8) {
            Text(conflict.proposed.originalText).font(.headline)
            let proposal = structured(conflict.proposed)
            Text(RecipePresentationFormatter(locale: locale).ingredient(proposal))
            ViewThatFits(in: .horizontal) {
              HStack { choices(conflict.id) }
              VStack(alignment: .leading) { choices(conflict.id) }
            }
          }
        }
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
    guard var text = editor.session.ingredientText else { return }
    text.resolve(id, acceptingInterpretation: accept)
    editor.session.updateIngredientText(text)
  }
}
