// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Commands route through the native text system so section insertion participates in text undo.
@MainActor
final class IngredientTextActions {
  var addSection: (String) -> Void = { _ in }
}

@MainActor
final class IngredientTextCoordinator: NSObject {
  let editing: RecipeIngredientTextEditing
  var document: RecipeIngredientTextDraft { editing.document }
  var locale: Locale
  private weak var nativeUndoManager: UndoManager?
  private var nativeText: (() -> String?)?
  var applyingAttributes = false

  init(draft: RecipeEditingDraft, locale: Locale) {
    editing = draft.beginIngredientTextEditing()
    self.locale = locale
  }

  func end() {
    editing.end()
    observeNativeUndo(nil, text: { nil })
  }

  @discardableResult
  func replace(_ range: NSRange, with replacement: String, source: String,
               undoing: Bool, redoing: Bool = false) -> Bool {
    guard editing.isActive, source == document.text else { return false }
    editing.replaceCharacters(in: range, with: replacement, source: source,
                              undoing: undoing, redoing: redoing, locale: locale)
    return true
  }

  /// AppKit can undo text storage without calling either text-change delegate method.
  func observeNativeUndo(_ undoManager: UndoManager?, text: @escaping () -> String?) {
    nativeText = text
    guard nativeUndoManager !== undoManager else { return }
    NotificationCenter.default.removeObserver(self, name: Notification.Name.NSUndoManagerDidUndoChange,
                                              object: nativeUndoManager)
    NotificationCenter.default.removeObserver(self, name: Notification.Name.NSUndoManagerDidRedoChange,
                                              object: nativeUndoManager)
    nativeUndoManager = undoManager
    guard let undoManager else { return }
    for name in [Notification.Name.NSUndoManagerDidUndoChange, Notification.Name.NSUndoManagerDidRedoChange] {
      NotificationCenter.default.addObserver(self, selector: #selector(nativeUndoCompleted(_:)),
                                            name: name, object: undoManager)
    }
  }

  @objc private func nativeUndoCompleted(_ notification: Notification) {
    guard let text = nativeText?() else { return }
    editing.observeNativeUndo(text: text, redoing: notification.name == Notification.Name.NSUndoManagerDidRedoChange,
                              locale: locale)
  }

  func finish(excluding offset: Int? = nil) {
    editing.completeLines(excluding: offset, locale: locale)
  }

  func decorate(_ storage: NSTextStorage, base: [NSAttributedString.Key: Any], undoManager: UndoManager?) {
    guard !applyingAttributes, editing.isActive, storage.string == document.text else { return }
    applyingAttributes = true
    undoManager?.disableUndoRegistration()
    storage.beginEditing()
    storage.setAttributes(base, range: NSRange(location: 0, length: storage.length))
    var offset = 0
    for line in document.lines {
      let length = (line.source as NSString).length
      defer { offset += length + 1 }
      if line.sectionID != nil {
        storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.double.rawValue,
                             range: NSRange(location: offset, length: length))
      } else if line.isInterpreted {
        for segment in IngredientLineParser.interpret(line.source, locale: locale).segments {
          let range = NSRange(location: offset + segment.utf16Range.lowerBound, length: segment.utf16Range.count)
          switch segment.kind {
          case .quantity:
            storage.addAttribute(.strokeWidth, value: -3.0, range: range)
          case .unit:
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
          case .package, .preparation:
            storage.addAttribute(.obliqueness, value: 0.15, range: range)
          case .ingredient: break
          }
          if segment.kind != .ingredient {
#if os(macOS)
            storage.addAttribute(.foregroundColor, value: NSColor.controlAccentColor, range: range)
#else
            storage.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: range)
#endif
          }
        }
      }
    }
    storage.endEditing()
    undoManager?.enableUndoRegistration()
    applyingAttributes = false
  }
}
