// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

#if os(macOS)
import AppKit

struct NativeIngredientText: NSViewRepresentable {
  @Binding var document: RecipeIngredientTextDraft
  let actions: IngredientTextActions
  @Environment(\.locale) private var locale

  func makeCoordinator() -> IngredientTextCoordinator { .init(document: $document, locale: locale) }

  func makeNSView(context: Context) -> NSScrollView {
    let scroll = NSTextView.scrollableTextView()
    guard let text = scroll.documentView as? NSTextView else { return scroll }
    text.isRichText = false
    text.allowsUndo = true
    text.isAutomaticQuoteSubstitutionEnabled = false
    text.isAutomaticDashSubstitutionEnabled = false
    text.font = .preferredFont(forTextStyle: .body)
    text.string = document.text
    text.delegate = context.coordinator
    text.textContainerInset = NSSize(width: 8, height: 8)
    text.setAccessibilityLabel(LocalizedStringResource.recipeEditorIngredientsSection.localized(for: locale))
    text.setAccessibilityIdentifier("simple-ingredient-text")
    actions.addSection = { [weak text] title in
      guard let text else { return }
      text.window?.makeFirstResponder(text)
      text.insertText((text.string.isEmpty ? "" : "\n") + "# " + title + "\n",
                      replacementRange: NSRange(location: (text.string as NSString).length, length: 0))
    }
    context.coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: text))
    return scroll
  }

  func updateNSView(_ scroll: NSScrollView, context: Context) {
    context.coordinator.document = $document
    context.coordinator.locale = locale
    guard let text = scroll.documentView as? NSTextView else { return }
    if text.string != document.text {
      text.undoManager?.removeAllActions()
      text.string = document.text
    }
    context.coordinator.synchronizeAdjustments()
    context.coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: text))
  }
}

extension IngredientTextCoordinator: NSTextViewDelegate {
  func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange,
                replacementString: String?) -> Bool {
    guard let replacementString, !applyingAttributes else { return true }
    replace(affectedCharRange, with: replacementString,
            undoing: textView.undoManager?.isUndoing == true, redoing: textView.undoManager?.isRedoing == true)
    return true
  }

  func textDidChange(_ notification: Notification) {
    guard let text = notification.object as? NSTextView, !text.hasMarkedText(),
          let storage = text.textStorage else { return }
    decorate(storage, base: [.font: NSFont.preferredFont(forTextStyle: .body),
                            .foregroundColor: NSColor.labelColor,
    ], undoManager: text.undoManager)
  }

  func textViewDidChangeSelection(_ notification: Notification) {
    guard !applyingAttributes, let text = notification.object as? NSTextView,
          !text.hasMarkedText(), text.string == document.wrappedValue.text else { return }
    finish(excluding: text.selectedRange().location)
  }

  func textDidEndEditing(_ notification: Notification) { finish() }
}
#else
import UIKit

struct NativeIngredientText: UIViewRepresentable {
  @Binding var document: RecipeIngredientTextDraft
  let actions: IngredientTextActions
  @Environment(\.locale) private var locale

  func makeCoordinator() -> IngredientTextCoordinator { .init(document: $document, locale: locale) }

  func makeUIView(context: Context) -> UITextView {
    let text = UITextView()
    text.text = document.text
    text.font = .preferredFont(forTextStyle: .body)
    text.adjustsFontForContentSizeCategory = true
    text.smartDashesType = .no
    text.smartQuotesType = .no
    text.delegate = context.coordinator
    text.accessibilityLabel = LocalizedStringResource.recipeEditorIngredientsSection.localized(for: locale)
    text.accessibilityIdentifier = "simple-ingredient-text"
    actions.addSection = { [weak text] title in
      guard let text else { return }
      text.becomeFirstResponder()
      text.selectedRange = NSRange(location: (text.text as NSString).length, length: 0)
      text.insertText((text.text.isEmpty ? "" : "\n") + "# " + title + "\n")
    }
    context.coordinator.textViewDidChange(text)
    return text
  }

  func updateUIView(_ text: UITextView, context: Context) {
    context.coordinator.document = $document
    context.coordinator.locale = locale
    if text.text != document.text {
      text.undoManager?.removeAllActions()
      text.text = document.text
    }
    context.coordinator.synchronizeAdjustments()
    context.coordinator.textViewDidChange(text)
  }
}

extension IngredientTextCoordinator: UITextViewDelegate {
  func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
    guard !applyingAttributes else { return true }
    replace(range, with: text,
            undoing: textView.undoManager?.isUndoing == true, redoing: textView.undoManager?.isRedoing == true)
    return true
  }

  func textViewDidChange(_ textView: UITextView) {
    guard textView.markedTextRange == nil else { return }
    decorate(textView.textStorage, base: [.font: UIFont.preferredFont(forTextStyle: .body),
                                        .foregroundColor: UIColor.label,
    ], undoManager: textView.undoManager)
  }

  func textViewDidChangeSelection(_ textView: UITextView) {
    guard !applyingAttributes, textView.markedTextRange == nil,
          textView.text == document.wrappedValue.text else { return }
    finish(excluding: textView.selectedRange.location)
  }

  func textViewDidEndEditing(_ textView: UITextView) { finish() }
}
#endif
