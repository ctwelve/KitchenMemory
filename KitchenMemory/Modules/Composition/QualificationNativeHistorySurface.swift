// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

#if TESTING
import SwiftUI

/// Read-only first responder for exercising system menus/gestures against the
/// disposable scene's history facade. It never creates a second history stack.
#if canImport(UIKit)
import UIKit

struct QualificationNativeHistorySurface: UIViewRepresentable {
  let manager: UndoManager

  func makeUIView(context: Context) -> QualificationHistoryTextView {
    let view = QualificationHistoryTextView()
    view.isEditable = false
    view.text = "Tap here, then use the system Undo or Redo gesture."
    view.font = .preferredFont(forTextStyle: .body)
    view.adjustsFontForContentSizeCategory = true
    view.accessibilityLabel = "Collection history"
    view.accessibilityIdentifier = "undo-qualification-native-history"
    view.historyManager = manager
    return view
  }

  func updateUIView(_ view: QualificationHistoryTextView, context: Context) {
    view.historyManager = manager
  }
}

final class QualificationHistoryTextView: UITextView {
  var historyManager: UndoManager?
  override var undoManager: UndoManager? { historyManager }
  override var canBecomeFirstResponder: Bool { true }
}
#elseif canImport(AppKit)
import AppKit

struct QualificationNativeHistorySurface: NSViewRepresentable {
  let manager: UndoManager

  func makeNSView(context: Context) -> QualificationHistoryTextView {
    let view = QualificationHistoryTextView()
    view.isEditable = false
    view.string = "Click here, then use Edit > Undo or Edit > Redo."
    view.font = .preferredFont(forTextStyle: .body)
    view.setAccessibilityLabel("Collection history")
    view.setAccessibilityIdentifier("undo-qualification-native-history")
    view.historyManager = manager
    return view
  }

  func updateNSView(_ view: QualificationHistoryTextView, context: Context) {
    view.historyManager = manager
  }
}

final class QualificationHistoryTextView: NSTextView {
  var historyManager: UndoManager?
  override var undoManager: UndoManager? { historyManager }
}
#endif
#endif
