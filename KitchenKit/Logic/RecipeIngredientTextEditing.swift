// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

public extension RecipeEditingDraft {
  /// Begins one native editor's transient semantic history, retiring any previous editor.
  /// Retain the returned editing interface for the native view's lifetime and call `end()` on teardown.
  func beginIngredientTextEditing() -> RecipeIngredientTextEditing {
    ingredientTextEditing?.end()
    prepareIngredientText()
    let editing = RecipeIngredientTextEditing(draft: self)
    ingredientTextEditing = editing
    return editing
  }
}

/// Ingredient meaning and identity history for one native text editor attached to a live draft.
///
/// Native controls own undo grouping and delivery; this interface restores the matching semantic
/// contents and carries subsequent precision edits across those contents. History is never encoded.
@MainActor
public final class RecipeIngredientTextEditing {
  private let draft: RecipeEditingDraft
  private var snapshots: [RecipeIngredientTextDraft]
  private var snapshotIndex = 0

  public var document: RecipeIngredientTextDraft {
    draft.session.ingredientText ?? snapshots[snapshotIndex]
  }
  public var isActive: Bool { draft.ingredientTextEditing === self && draft.pendingSave == nil }

  init(draft: RecipeEditingDraft) {
    self.draft = draft
    snapshots = [draft.session.ingredientText ?? .init(sections: draft.session.ingredientSections)]
  }

  /// Releases semantic history and prevents any later callback from this editor changing the draft.
  public func end() {
    draft.retireIngredientTextEditing(self)
    snapshots = [document]
    snapshotIndex = 0
  }

  /// Applies a UTF-16 replacement reported by a native control. `source` is its pre-edit text;
  /// mismatched sources and invalid ranges are rejected without mutation or persistence.
  /// Ordinary typing leaves the active line pending; newline insertion completes affected lines.
  @discardableResult
  public func replaceCharacters(in range: NSRange, with replacement: String, source: String,
                                undoing: Bool = false, redoing: Bool = false, locale: Locale = .current) -> Bool {
    guard isActive, source == document.text,
          range.location >= 0, range.length >= 0, range.location <= (source as NSString).length,
          range.length <= (source as NSString).length - range.location else { return false }
    var value = document
    let resultingText = (source as NSString).replacingCharacters(in: range, with: replacement)
    guard resultingText != source else { return false }
    let restoredIndex: Int?
    if undoing {
      restoredIndex = snapshots.indices.prefix(snapshotIndex).last { snapshots[$0].text == resultingText }
    } else if redoing {
      restoredIndex = snapshots.indices.dropFirst(snapshotIndex + 1).first { snapshots[$0].text == resultingText }
    } else {
      restoredIndex = nil
    }
    if let restoredIndex {
      snapshotIndex = restoredIndex
      value = snapshots[restoredIndex]
    } else {
      value.replaceCharacters(in: range, with: replacement)
      let cursor = range.location + (replacement as NSString).length
      value.finishEditing(locale: locale, excludingLineAtUTF16Offset: replacement.contains("\n") ? nil : cursor)
      snapshots = Array(snapshots.prefix(snapshotIndex + 1)) + [value]
      snapshotIndex += 1
    }
    return draft.updateIngredientText(value, from: self)
  }

  /// Applies a native undo/redo outcome when a platform omits its replacement callback.
  /// An outcome already delivered through replacement is a no-op.
  @discardableResult
  public func observeNativeUndo(text: String, redoing: Bool, locale: Locale = .current) -> Bool {
    replaceCharacters(in: NSRange(location: 0, length: (document.text as NSString).length), with: text,
                      source: document.text, undoing: !redoing, redoing: redoing, locale: locale)
  }

  /// Completes paste, blur, or completed lines while optionally leaving the active UTF-16 offset pending.
  @discardableResult
  public func completeLines(excluding offset: Int? = nil, locale: Locale = .current) -> Bool {
    guard isActive else { return false }
    var value = document
    value.finishEditing(locale: locale, excludingLineAtUTF16Offset: offset)
    snapshots[snapshotIndex] = value
    return draft.updateIngredientText(value, from: self)
  }

  func synchronize() {
    guard let current = draft.session.ingredientText else { end(); return }
    let previous = snapshots[snapshotIndex]
    guard current != previous else { return }
    if current.text != previous.text || current.lines.map(\.id) != previous.lines.map(\.id) {
      end()
    } else {
      snapshots = snapshots.map { $0.preservingAdjustments(from: previous, to: current) }
      snapshots[snapshotIndex] = current
    }
  }
}
