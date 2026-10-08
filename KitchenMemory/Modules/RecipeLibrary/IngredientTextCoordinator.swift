// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
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

/// Retained callback bridge between one native control and its Kit editing interface.
///
/// SwiftUI creates this through `makeCoordinator`; the native text view calls
/// its delegate extensions in ``NativeIngredientText``. Kit owns ingredient
/// identities, interpretation, and semantic snapshots. The coordinator owns
/// platform offsets, styling, and observation of the control's native undo.
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

  /// Ends the captured editing lifetime and removes native undo observers on teardown.
  func end() {
    editing.end()
    observeNativeUndo(nil, text: { nil })
  }

  /// Mirrors a pre-edit native replacement only while its captured source is current.
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

  // Undo notifications arrive after native text has been restored. Kit rebases
  // semantic snapshots onto that outcome, including later precision edits;
  // repeated delivery of the same outcome is a no-op in the editing interface.
  @objc private func nativeUndoCompleted(_ notification: Notification) {
    guard let text = nativeText?() else { return }
    editing.observeNativeUndo(text: text, redoing: notification.name == Notification.Name.NSUndoManagerDidRedoChange,
                              locale: locale)
  }

  /// Completes interpretation after paste, caret movement, or editing resignation.
  /// The optional native UTF-16 offset leaves the currently edited line pending.
  func finish(excluding offset: Int? = nil) {
    editing.completeLines(excluding: offset, locale: locale)
  }

  func decorate(_ storage: NSTextStorage, base: [NSAttributedString.Key: Any], undoManager: UndoManager?) {
    guard !applyingAttributes, editing.isActive, storage.string == document.text else { return }
    // Styling is presentation, not an authored text edit. Suppress native undo
    // registration and guard reentrant delegate delivery while attributes change.
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
