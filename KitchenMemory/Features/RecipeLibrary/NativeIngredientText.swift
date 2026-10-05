// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

/// Hosts the native ingredient editor for one KitchenKit editing lifetime.
///
/// SwiftUI's representable callbacks create, update, and dismantle the control;
/// AppKit or UIKit then calls its coordinator for typing, selection, and paste.
/// The two explicit identities rebuild the control when either the draft or its
/// Kit editing lifetime changes. Old callbacks retain the retired interface,
/// never a lookup that could accidentally reach the replacement editor.
///
/// See [AppKit integration](https://developer.apple.com/tutorials/app-dev-training/integrating-appkit)
/// for the representable/coordinator lifecycle.
struct NativeIngredientText: View {
  @Bindable var draft: RecipeEditingDraft
  let actions: IngredientTextActions

  var body: some View {
    NativeIngredientTextView(draft: draft, actions: actions)
      .id(draft.ingredientTextEditorID)
      .id(draft.id)
  }
}

#if os(macOS)
import AppKit

private struct NativeIngredientTextView: NSViewRepresentable {
  @Bindable var draft: RecipeEditingDraft
  let actions: IngredientTextActions
  @Environment(\.locale) private var locale

  // SwiftUI creates a coordinator for this representable identity, keeping
  // delegate state outside the short-lived SwiftUI view value.
  func makeCoordinator() -> IngredientTextCoordinator { .init(draft: draft, locale: locale) }

  func makeNSView(context: Context) -> NSScrollView {
    let scroll = IngredientPasteTextView.scrollableTextView()
    guard let text = scroll.documentView as? NSTextView else { return scroll }
    text.isRichText = false
    text.allowsUndo = true
    text.isAutomaticQuoteSubstitutionEnabled = false
    text.isAutomaticDashSubstitutionEnabled = false
    text.font = .preferredFont(forTextStyle: .body)
    text.string = context.coordinator.document.text
    text.delegate = context.coordinator
    text.textContainerInset = NSSize(width: 8, height: 8)
    text.setAccessibilityLabel(LocalizedStringResource.recipeEditorIngredientsSection.localized(for: locale))
    text.setAccessibilityIdentifier("simple-ingredient-text")
    // The command bridge outlives individual native updates. Weak captures
    // avoid retaining a removed text view; responder activation and insertion
    // leave selection and undo grouping under the native text system.
    actions.addSection = { [weak text, weak coordinator = context.coordinator] title in
      guard let text, let coordinator, coordinator.editing.isActive else { return }
      text.window?.makeFirstResponder(text)
      text.insertText((text.string.isEmpty ? "" : "\n") + "# " + title + "\n",
                      replacementRange: NSRange(location: (text.string as NSString).length, length: 0))
    }
    context.coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: text))
    return scroll
  }

  func updateNSView(_ scroll: NSScrollView, context: Context) {
    context.coordinator.locale = locale
    guard let text = scroll.documentView as? NSTextView else { return }
    let document = context.coordinator.document
    // Ordinary typing already matches Kit. A mismatched model replacement
    // invalidates native history rather than applying old undo to new contents.
    if text.string != document.text {
      text.undoManager?.removeAllActions()
      text.string = document.text
    }
    context.coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: text))
  }

  static func dismantleNSView(_ scroll: NSScrollView, coordinator: IngredientTextCoordinator) {
    // Teardown retires semantic history and disconnects delayed native input.
    coordinator.end()
    guard let text = scroll.documentView as? NSTextView else { return }
    text.delegate = nil
    text.undoManager?.removeAllActions()
  }
}

/// Complete interpretation after AppKit inserts clipboard contents, without altering native undo or selection.
private final class IngredientPasteTextView: NSTextView {
  override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
    let inserted = super.readSelection(from: pboard, type: type)
    if inserted, let coordinator = delegate as? IngredientTextCoordinator {
      coordinator.finish()
      coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: self))
    }
    return inserted
  }
}

// AppKit calls shouldChange before applying the text replacement. Mirror the
// UTF-16 operation into Kit first; reject callbacks from an obsolete source.
extension IngredientTextCoordinator: NSTextViewDelegate {
  func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange,
                replacementString: String?) -> Bool {
    guard let replacementString, !applyingAttributes else { return true }
    return replace(affectedCharRange, with: replacementString, source: textView.string,
                   undoing: textView.undoManager?.isUndoing == true, redoing: textView.undoManager?.isRedoing == true)
  }

  // Marked text is provisional IME composition. Avoid restyling it or treating
  // a composition-driven selection move as completion of the active line.
  func textDidChange(_ notification: Notification) {
    guard let text = notification.object as? NSTextView, !text.hasMarkedText(),
          let storage = text.textStorage else { return }
    observeNativeUndo(text.undoManager) { [weak text] in text?.string }
    decorate(storage, base: [.font: NSFont.preferredFont(forTextStyle: .body),
                            .foregroundColor: NSColor.labelColor,
    ], undoManager: text.undoManager)
  }

  func textViewDidChangeSelection(_ notification: Notification) {
    guard !applyingAttributes, let text = notification.object as? NSTextView,
          !text.hasMarkedText(), text.string == document.text else { return }
    // Moving the caret completes other lines while preserving the active line
    // as pending. Native offsets and Kit's text ranges both use UTF-16 units.
    finish(excluding: text.selectedRange().location)
  }

  func textDidEndEditing(_ notification: Notification) { finish() }
}
#else
import UIKit

private struct NativeIngredientTextView: UIViewRepresentable {
  @Bindable var draft: RecipeEditingDraft
  let actions: IngredientTextActions
  @Environment(\.locale) private var locale

  // As on macOS, the coordinator retains one Kit interface for this control,
  // while SwiftUI may recreate and update the representable value many times.
  func makeCoordinator() -> IngredientTextCoordinator { .init(draft: draft, locale: locale) }

  func makeUIView(context: Context) -> UITextView {
    let text = UITextView()
    text.text = context.coordinator.document.text
    text.font = .preferredFont(forTextStyle: .body)
    text.adjustsFontForContentSizeCategory = true
    text.smartDashesType = .no
    text.smartQuotesType = .no
    text.delegate = context.coordinator
    text.pasteDelegate = context.coordinator
    text.accessibilityLabel = LocalizedStringResource.recipeEditorIngredientsSection.localized(for: locale)
    text.accessibilityIdentifier = "simple-ingredient-text"
    // The command bridge outlives individual native updates. Weak captures
    // avoid retaining a removed text view; responder activation and insertion
    // leave selection and undo grouping under the native text system.
    actions.addSection = { [weak text, weak coordinator = context.coordinator] title in
      guard let text, let coordinator, coordinator.editing.isActive else { return }
      text.becomeFirstResponder()
      text.selectedRange = NSRange(location: (text.text as NSString).length, length: 0)
      guard let range = text.selectedTextRange else { return }
      coordinator.insertText((text.text.isEmpty ? "" : "\n") + "# " + title + "\n",
                             into: text, replacing: range)
    }
    context.coordinator.textViewDidChange(text)
    return text
  }

  func updateUIView(_ text: UITextView, context: Context) {
    context.coordinator.locale = locale
    let document = context.coordinator.document
    // Model-driven replacement is not another keystroke: old native undo
    // actions refer to the previous contents and must be retired first.
    if text.text != document.text {
      text.undoManager?.removeAllActions()
      text.text = document.text
    }
    context.coordinator.textViewDidChange(text)
  }

  static func dismantleUIView(_ text: UITextView, coordinator: IngredientTextCoordinator) {
    // Teardown retires semantic history and disconnects delayed native input.
    coordinator.end()
    text.delegate = nil
    text.pasteDelegate = nil
    text.undoManager?.removeAllActions()
  }
}

extension IngredientTextCoordinator: UITextPasteDelegate {
  func textPasteConfigurationSupporting(_ support: any UITextPasteConfigurationSupporting,
                                        performPasteOf attributedString: NSAttributedString,
                                        to textRange: UITextRange) -> UITextRange {
    guard let text = support as? UITextView else { return textRange }
    let offset = text.offset(from: text.beginningOfDocument, to: textRange.start)
    // Use native insertion so selection and text undo retain their normal behavior.
    insertText(attributedString.string, into: text, replacing: textRange)
    finish()
    textViewDidChange(text)
    guard let start = text.position(from: text.beginningOfDocument, offset: offset),
          let end = text.position(from: start, offset: attributedString.length),
          let insertedRange = text.textRange(from: start, to: end) else { return textRange }
    return insertedRange
  }

  /// Mirrors programmatic native insertion even if the keyboard delegate path is skipped.
  ///
  /// Paste and Add Section enter here. Capture the pre-edit source and native
  /// range before insertion, then submit the same operation to Kit. If UIKit
  /// also sent the delegate callback, source validation rejects the duplicate.
  func insertText(_ replacement: String, into text: UITextView, replacing range: UITextRange) {
    guard editing.isActive else { return }
    let source = text.text ?? ""
    let affected = NSRange(location: text.offset(from: text.beginningOfDocument, to: range.start),
                           length: text.offset(from: range.start, to: range.end))
    text.selectedTextRange = range
    text.insertText(replacement)
    // If UIKit already delivered its delegate callback, Kit rejects this duplicate pre-edit source.
    replace(affected, with: replacement, source: source, undoing: false)
    textViewDidChange(text)
  }
}

// UIKit keyboard edits enter before the native replacement through this
// delegate. The captured Kit interface validates its lifetime and pre-edit text.
extension IngredientTextCoordinator: UITextViewDelegate {
  func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
    guard !applyingAttributes else { return true }
    return replace(range, with: text, source: textView.text,
                   undoing: textView.undoManager?.isUndoing == true, redoing: textView.undoManager?.isRedoing == true)
  }

  // Do not decorate provisional multistage input. UIKit owns the marked range
  // until the person commits it; selection completion below uses the same guard.
  func textViewDidChange(_ textView: UITextView) {
    guard textView.markedTextRange == nil else { return }
    observeNativeUndo(textView.undoManager) { [weak textView] in textView?.text }
    decorate(textView.textStorage, base: [.font: UIFont.preferredFont(forTextStyle: .body),
                                        .foregroundColor: UIColor.label,
    ], undoManager: textView.undoManager)
  }

  func textViewDidChangeSelection(_ textView: UITextView) {
    guard !applyingAttributes, textView.markedTextRange == nil,
          textView.text == document.text else { return }
    // Complete departed lines, leaving the line containing the native caret
    // pending; Swift Character counts would not match these UTF-16 offsets.
    finish(excluding: textView.selectedRange.location)
  }

  func textViewDidEndEditing(_ textView: UITextView) { finish() }
}
#endif
