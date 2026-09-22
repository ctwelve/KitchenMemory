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
  var document: Binding<RecipeIngredientTextDraft>
  var locale: Locale
  private var snapshots: [RecipeIngredientTextDraft]
  private var snapshotIndex = 0
  var applyingAttributes = false

  init(document: Binding<RecipeIngredientTextDraft>, locale: Locale) {
    self.document = document
    self.locale = locale
    snapshots = [document.wrappedValue]
  }

  func replace(_ range: NSRange, with replacement: String, undoing: Bool, redoing: Bool = false) {
    synchronizeAdjustments()
    var value = document.wrappedValue
    let resultingText = (value.text as NSString).replacingCharacters(in: range, with: replacement)
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
    document.wrappedValue = value
  }

  func synchronizeAdjustments() {
    let current = document.wrappedValue
    let previous = snapshots[snapshotIndex]
    guard current != previous else { return }
    if current.text != previous.text {
      snapshots = [current]
      snapshotIndex = 0
    } else {
      snapshots = snapshots.map { $0.preservingAdjustments(from: previous, to: current) }
      snapshots[snapshotIndex] = current
    }
  }

  func finish(excluding offset: Int? = nil) {
    synchronizeAdjustments()
    var value = document.wrappedValue
    value.finishEditing(locale: locale, excludingLineAtUTF16Offset: offset)
    if value != document.wrappedValue { document.wrappedValue = value }
    snapshots[snapshotIndex] = value
  }

  func decorate(_ storage: NSTextStorage, base: [NSAttributedString.Key: Any], undoManager: UndoManager?) {
    guard !applyingAttributes, storage.string == document.wrappedValue.text else { return }
    applyingAttributes = true
    undoManager?.disableUndoRegistration()
    storage.beginEditing()
    storage.setAttributes(base, range: NSRange(location: 0, length: storage.length))
    var offset = 0
    for line in document.wrappedValue.lines {
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
