// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

public extension RecipeEditingDraft {
  /// Updates a live ingredient by identity, retaining authored wording unless explicitly edited.
  ///
  /// Reconciles text and structured contents before the existing draft-change notification.
  /// Returns false for a missing identity, an unchanged value, or a frozen Save intention.
  /// This edits only the local draft; publication remains an explicit Recipe Save.
  @discardableResult
  func updateIngredient(_ ingredient: RecipeIngredient) -> Bool {
    editIngredientSections { sections in
      for section in sections.indices {
        if let index = sections[section].ingredients.firstIndex(where: { $0.id == ingredient.id }) {
          sections[section].ingredients[index] = ingredient
          return
        }
      }
    }
  }

  /// Appends an empty precision-editing row. Returns its identity, or nil if unavailable or frozen.
  @discardableResult
  func addIngredient(to sectionID: IngredientSection.ID) -> RecipeIngredient.ID? {
    let ingredient = RecipeIngredient(parseState: .edited)
    let accepted = editIngredientSections { sections in
      guard let section = sections.firstIndex(where: { $0.id == sectionID }) else { return }
      sections[section].ingredients.append(ingredient)
    }
    return accepted ? ingredient.id : nil
  }

  /// Removes only the identified row. Missing identities and frozen drafts are unchanged.
  @discardableResult
  func removeIngredient(_ id: RecipeIngredient.ID) -> Bool {
    editIngredientSections { sections in
      for section in sections.indices { sections[section].ingredients.removeAll { $0.id == id } }
    }
  }

  /// Swaps a row within its current section, matching the editor's Move Up/Down actions.
  /// Missing identities, out-of-range destinations, and frozen drafts are unchanged.
  @discardableResult
  func moveIngredient(_ id: RecipeIngredient.ID, by offset: Int) -> Bool {
    editIngredientSections { sections in
      for section in sections.indices {
        if let index = sections[section].ingredients.firstIndex(where: { $0.id == id }) {
          moveIngredientElement(in: &sections[section].ingredients, at: index, by: offset)
          return
        }
      }
    }
  }

  /// Appends an empty section without parsing or normalizing its authored title.
  @discardableResult
  func addIngredientSection(title: String? = nil) -> IngredientSection.ID? {
    let section = IngredientSection(title: title, ingredients: [])
    return editIngredientSections { $0.append(section) } ? section.id : nil
  }

  /// Renames the identified section while retaining its ingredient and section identities.
  @discardableResult
  func renameIngredientSection(_ id: IngredientSection.ID, to title: String?) -> Bool {
    editIngredientSections { sections in
      guard let index = sections.firstIndex(where: { $0.id == id }) else { return }
      sections[index].title = title
    }
  }

  /// Removes the section and its rows from this local draft, without changing a saved Recipe.
  @discardableResult
  func removeIngredientSection(_ id: IngredientSection.ID) -> Bool {
    editIngredientSections { $0.removeAll { $0.id == id } }
  }

  /// Swaps sections using their current positions; stale or out-of-range requests do nothing.
  @discardableResult
  func moveIngredientSection(_ id: IngredientSection.ID, by offset: Int) -> Bool {
    editIngredientSections { sections in
      guard let index = sections.firstIndex(where: { $0.id == id }) else { return }
      moveIngredientElement(in: &sections, at: index, by: offset)
    }
  }

  /// Opens simple editing without reinterpreting maintained ingredients.
  /// Display wording is presentation-only and is used for rows lacking original text.
  @discardableResult
  func prepareIngredientText(displayWording: [RecipeIngredient.ID: String] = [:]) -> Bool {
    editIngredientText { $0.prepareIngredientText(displayWording: displayWording) }
  }

  /// Completes pending interpretation for mode changes, Close, or Save in one local edit.
  /// Existing precise fields and unresolved proposals retain their normal choice semantics.
  @discardableResult
  func finishIngredientText(locale: Locale = .current) -> Bool {
    editIngredientText {
      $0.prepareIngredientText()
      $0.finishIngredientText(locale: locale)
    }
  }

  /// Accepts a pending parser proposal or keeps the person's precise fields.
  /// Missing proposals and frozen drafts are unchanged. No Recipe is published.
  @discardableResult
  func resolveIngredientInterpretation(_ id: RecipeIngredient.ID, accepting: Bool) -> Bool {
    editIngredientText { updated in
      guard var text = updated.ingredientText else { return }
      text.resolve(id, acceptingInterpretation: accepting)
      updated.updateIngredientText(text)
    }
  }

  private func editIngredientSections(_ edit: (inout [IngredientSection]) -> Void) -> Bool {
    guard pendingSave == nil else { return false }
    var updated = session
    edit(&updated.ingredientSections)
    guard updated.ingredientSections != session.ingredientSections else { return false }
    updated.prepareIngredientText()
    session = updated
    return true
  }

  private func moveIngredientElement<Value>(in values: inout [Value], at index: Int, by offset: Int) {
    let (destination, overflow) = index.addingReportingOverflow(offset)
    guard !overflow, values.indices.contains(destination) else { return }
    values.swapAt(index, destination)
  }

  private func editIngredientText(_ edit: (inout RecipeEditSession) -> Void) -> Bool {
    guard pendingSave == nil else { return false }
    var updated = session
    edit(&updated)
    guard updated != session else { return false }
    session = updated
    return true
  }
}
