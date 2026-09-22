// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

public extension RecipeIngredientTextDraft {
  /// Rebases a text-undo snapshot over subsequent explicit precision edits.
  /// Only fields changed outside the text history are carried over; historical wording and
  /// parser-derived quantities remain undoable. Removed lines are not resurrected by precision.
  func preservingAdjustments(from previous: Self, to current: Self) -> Self {
    let before = Dictionary(uniqueKeysWithValues: previous.sections.flatMap(\.ingredients).map { ($0.id, $0) })
    let after = Dictionary(uniqueKeysWithValues: current.sections.flatMap(\.ingredients).map { ($0.id, $0) })
    var updated = sections
    for section in updated.indices {
      for index in updated[section].ingredients.indices {
        let id = updated[section].ingredients[index].id
        guard let old = before[id], let new = after[id] else { continue }
        var value = updated[section].ingredients[index]
        value.carryAdjustments(from: old, to: new)
        updated[section].ingredients[index] = value
      }
    }
    return incorporating(updated)
  }
}

private extension RecipeIngredient {
  mutating func carryAdjustments(from old: Self, to new: Self) {
    carry(\.presentationMode, from: old, to: new)
    carry(\.customDisplayText, from: old, to: new)
    carry(\.quantity, from: old, to: new)
    carry(\.unitText, from: old, to: new)
    carry(\.package, from: old, to: new)
    carry(\.ingredientText, from: old, to: new)
    carry(\.preparation, from: old, to: new)
    carry(\.note, from: old, to: new)
    carry(\.isOptional, from: old, to: new)
    carry(\.scalingBehavior, from: old, to: new)
    carry(\.parseState, from: old, to: new)
  }

  mutating func carry<Value: Equatable>(_ key: WritableKeyPath<Self, Value>, from old: Self, to new: Self) {
    if old[keyPath: key] != new[keyPath: key] { self[keyPath: key] = new[keyPath: key] }
  }
}
