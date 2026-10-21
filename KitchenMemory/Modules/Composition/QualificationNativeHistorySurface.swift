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

  func makeNSView(context: Context) -> QualificationHistoryResponder {
    let view = QualificationHistoryResponder()
    view.setAccessibilityElement(true)
    view.setAccessibilityRole(.group)
    view.setAccessibilityLabel("Collection history")
    view.setAccessibilityIdentifier("undo-qualification-native-history")
    view.historyManager = manager
    return view
  }

  func updateNSView(_ view: QualificationHistoryResponder, context: Context) {
    view.historyManager = manager
  }
}

final class QualificationHistoryResponder: NSView, NSUserInterfaceValidations {
  var historyManager: UndoManager?
  override var undoManager: UndoManager? { historyManager }
  override var acceptsFirstResponder: Bool { true }

  override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }

  @objc func undo(_ sender: Any?) { historyManager?.undo() }
  @objc func redo(_ sender: Any?) { historyManager?.redo() }

  func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
    switch item.action {
    case #selector(undo(_:)): historyManager?.canUndo ?? false
    case #selector(redo(_:)): historyManager?.canRedo ?? false
    default: false
    }
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    ("Click here, then use Edit > Undo or Edit > Redo." as NSString).draw(
      in: bounds.insetBy(dx: 8, dy: 8),
      withAttributes: [.font: NSFont.preferredFont(forTextStyle: .body), .foregroundColor: NSColor.labelColor])
  }
}
#endif
#endif
