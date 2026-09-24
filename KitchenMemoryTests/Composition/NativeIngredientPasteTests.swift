// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
@testable import KitchenMemory
import SwiftUI
import XCTest

@MainActor
final class NativeIngredientPasteTests: XCTestCase {
  func testReplacementRetiresTheOldNativeControlEvenWhenWordingMatches() async throws {
    let recipeID = Recipe.ID()
    let first = RecipeRevision(recipeID: recipeID, revisionNumber: 1, title: "Soup", ingredientSections: [
      IngredientSection(ingredients: [IngredientLineParser.parse("1 tsp salt")]),
    ])
    let second = RecipeRevision(recipeID: recipeID, revisionNumber: 2, title: "Stew", ingredientSections: [
      IngredientSection(ingredients: [IngredientLineParser.parse("1 tsp salt")]),
    ])
    var comparison = try RecipeReconciliation(kitchenID: Kitchen.ID(), revisions: [first, second],
                                              observedSelectionIDs: [])
    try comparison.chooseRevision(first.id)
    let draft = RecipeEditingDraft(draft: RecipeDraft(revision: first), reconciliation: comparison)
    let host = try IngredientPasteHost(draft: draft)
    defer { host.close() }
    let old = try host.textView()
    let oldCoordinator = try XCTUnwrap(old.delegate as? IngredientTextCoordinator)
    try draft.choose(.ingredients, from: second.id)
    try await host.waitFor { (try? host.textView()) !== old }
    XCTAssertFalse(oldCoordinator.replace(NSRange(location: 0, length: 1), with: "2",
                                          source: "1 tsp salt", undoing: false))
    XCTAssertEqual(draft.session.ingredientSections, second.ingredientSections)
    let current = try host.textView()
    XCTAssertNotIdentical(current, old)
    XCTAssertFalse(try XCTUnwrap(current.undoManager).canUndo)
  }

  func testNativeTextUndoAndRedoPreserveLaterPrecisionAndIdentity() async throws {
    let salt = IngredientLineParser.parse("1 tsp salt")
    let draft = RecipeEditingDraft(draft: RecipeDraft(ingredientSections: [IngredientSection(ingredients: [salt])]))
    let host = try IngredientPasteHost(draft: draft)
    defer { host.close() }
    let text = try host.textView()
    host.focus(text)
    host.select(NSRange(location: 0, length: 1), in: text)
    host.paste("2", into: text)
    try await host.waitFor(diagnostics: {
      "\(host.editorState(text)); ingredient document: \(String(reflecting: draft.session.ingredientText))"
    }) {
      draft.session.ingredientSections.first?.ingredients.first?.quantity?.lowerBound?.numerator == 2
    }
    var adjusted = try XCTUnwrap(draft.session.ingredientSections.first?.ingredients.first)
    adjusted.note = "Use fine salt"
    XCTAssertTrue(draft.updateIngredient(adjusted))
    // Let SwiftUI update the native adapter, as it does when a precision control changes the draft.
    await Task.yield()
    host.undo(in: text)
    XCTAssertEqual(draft.session.ingredientText?.text, "1 tsp salt")
    XCTAssertEqual(draft.session.ingredientSections.first?.ingredients.first?.quantity?.lowerBound?.numerator, 1)
    XCTAssertEqual(draft.session.ingredientSections.first?.ingredients.first?.id, salt.id)
    XCTAssertEqual(draft.session.ingredientSections.first?.ingredients.first?.note, "Use fine salt")
    host.redo(in: text)
    XCTAssertEqual(draft.session.ingredientText?.text, "2 tsp salt")
    XCTAssertEqual(draft.session.ingredientSections.first?.ingredients.first?.quantity?.lowerBound?.numerator, 2)
    XCTAssertEqual(draft.session.ingredientSections.first?.ingredients.first?.id, salt.id)
    XCTAssertEqual(draft.session.ingredientSections.first?.ingredients.first?.note, "Use fine salt")
  }

  func testSingleLineIngredientPasteInterpretsWithoutLeavingTheLine() async throws {
    let draft = RecipeEditingDraft(draft: RecipeDraft())
    var document: RecipeIngredientTextDraft { draft.session.ingredientText! }
    let host = try IngredientPasteHost(draft: draft)
    defer { host.close() }
    let text = try host.textView()
    host.focus(text)
    host.paste("2 cups flour", into: text)
    try await host.waitFor { document.text == "2 cups flour" && document.lines.allSatisfy(\.isInterpreted) }
    XCTAssertEqual(document.text, "2 cups flour")
    let ingredient = try XCTUnwrap(document.sections.first?.ingredients.first)
    XCTAssertEqual(ingredient.quantity?.lowerBound?.numerator, 2)
    XCTAssertEqual(ingredient.ingredientText, "flour")
    XCTAssertEqual(host.selection(in: text), NSRange(location: 12, length: 0))
  }

  func testSingleLineHeadingPasteRetainsSectionIdentityThroughNativeUndoAndRedo() async throws {
    let draft = RecipeEditingDraft(draft: RecipeDraft())
    var document: RecipeIngredientTextDraft { draft.session.ingredientText! }
    let host = try IngredientPasteHost(draft: draft)
    defer { host.close() }
    let text = try host.textView()
    host.focus(text)
    host.paste("# Sauce", into: text)
    try await host.waitFor { document.sections.first?.title == "Sauce" }
    let sectionID = try XCTUnwrap(document.sections.first?.id)
    XCTAssertEqual(document.text, "# Sauce")
    XCTAssertEqual(host.selection(in: text), NSRange(location: 7, length: 0))
    let undo = try XCTUnwrap(text.undoManager)
    XCTAssertTrue(undo.canUndo)
    host.undo(in: text)
#if os(macOS)
    XCTAssertEqual(text.string, "", "Native paste undo must remove the inserted text")
#else
    XCTAssertEqual(text.text, "", "Native paste undo must remove the inserted text")
#endif
    XCTAssertEqual(document.text, "")
    XCTAssertTrue(document.sections.isEmpty)
    XCTAssertTrue(undo.canRedo)
    host.redo(in: text)
    XCTAssertEqual(document.text, "# Sauce")
    XCTAssertEqual(document.sections.first?.id, sectionID)
  }

  func testTypingKeepsTheActiveLineUninterpretedUntilFocusLeaves() throws {
    let draft = RecipeEditingDraft(draft: RecipeDraft())
    var document: RecipeIngredientTextDraft { draft.session.ingredientText! }
    let host = try IngredientPasteHost(draft: draft)
    defer { host.close() }
    let text = try host.textView()
    host.focus(text)
#if os(macOS)
    text.insertText("2 cups flour", replacementRange: text.selectedRange())
#else
    // The keyboard asks the delegate before insertion; programmatic UITextInput does not.
    XCTAssertEqual(text.delegate?.textView?(text, shouldChangeTextIn: text.selectedRange,
                                          replacementText: "2 cups flour"), true)
    text.insertText("2 cups flour")
#endif
    XCTAssertEqual(document.text, "2 cups flour")
    XCTAssertFalse(try XCTUnwrap(document.lines.first).isInterpreted)
    host.endEditing()
    XCTAssertTrue(try XCTUnwrap(document.lines.first).isInterpreted)
    XCTAssertEqual(document.sections.first?.ingredients.first?.quantity?.lowerBound?.numerator, 2)
  }

  func testAddingSectionAppendsToNativeTextAndDraft() throws {
    let flour = IngredientLineParser.parse("2 cups flour")
    let draft = RecipeEditingDraft(draft: RecipeDraft(ingredientSections: [IngredientSection(ingredients: [flour])]))
    var document: RecipeIngredientTextDraft { draft.session.ingredientText! }
    let actions = IngredientTextActions()
    let host = try IngredientPasteHost(draft: draft, actions: actions)
    defer { host.close() }
    let text = try host.textView()
    host.focus(text)
    actions.addSection("Sauce")
    XCTAssertEqual(document.text, "2 cups flour\n# Sauce\n")
    XCTAssertEqual(document.sections.count, 2)
    XCTAssertEqual(document.sections.first?.ingredients.first?.id, flour.id)
    XCTAssertEqual(document.sections.last?.title, "Sauce")
    XCTAssertEqual(host.selection(in: text), NSRange(location: 21, length: 0))
  }
}

#if os(macOS)
import AppKit
private typealias IngredientPlatformView = NSView
private typealias IngredientPlatformTextView = NSTextView
#else
import UIKit
private typealias IngredientPlatformView = UIView
private typealias IngredientPlatformTextView = UITextView
#endif

/// Hosts the actual adapter; no UI automation, global clipboard changes or user store access.
@MainActor
private final class IngredientPasteHost {
  private let root: IngredientPlatformView
#if os(macOS)
  private let window: NSWindow
#else
  private let controller: UIHostingController<NativeIngredientText>
  private let window: UIWindow
#endif

  init(draft: RecipeEditingDraft, actions: IngredientTextActions = .init()) throws {
    let editor = NativeIngredientText(draft: draft, actions: actions)
#if os(macOS)
    let hosting = NSHostingView(rootView: editor)
    hosting.frame = NSRect(x: 0, y: 0, width: 400, height: 200)
    hosting.layoutSubtreeIfNeeded()
    root = hosting
    window = NSWindow(contentRect: hosting.frame, styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = hosting
    window.makeKeyAndOrderFront(nil)
#else
    controller = UIHostingController(rootView: editor)
    root = controller.view
    root.frame = CGRect(x: 0, y: 0, width: 400, height: 200)
    root.layoutIfNeeded()
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
    window = UIWindow(windowScene: scene)
    window.rootViewController = controller
    window.makeKeyAndVisible()
    root.layoutIfNeeded()
#endif
  }

  func waitFor(diagnostics: () -> String = { "" }, file: StaticString = #filePath, line: UInt = #line,
               _ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(3))
    while !condition(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(10)) }
    // Stop here so later undo/redo assertions cannot obscure an incomplete paste.
    _ = try XCTUnwrap(condition() ? true : nil,
                      "Native editor did not reach the expected state. \(diagnostics())", file: file, line: line)
  }

  func editorState(_ text: IngredientPlatformTextView) -> String {
#if os(macOS)
    "native text: \(text.string.debugDescription); selection: \(text.selectedRange())"
#else
    "native text: \((text.text ?? "").debugDescription); selection: \(text.selectedRange); "
      + "first responder: \(text.isFirstResponder); marked text: \(text.markedTextRange != nil)"
#endif
  }

  func focus(_ text: IngredientPlatformTextView) {
#if os(macOS)
    XCTAssertTrue(window.makeFirstResponder(text))
#else
    XCTAssertTrue(text.becomeFirstResponder())
#endif
  }

  func close() {
#if os(macOS)
    window.close()
#else
    window.isHidden = true
#endif
  }

  func endEditing() {
#if os(macOS)
    window.makeFirstResponder(nil)
#else
    root.endEditing(true)
#endif
  }

  func undo(in text: IngredientPlatformTextView) {
#if os(macOS)
    XCTAssertTrue(text.tryToPerform(NSSelectorFromString("undo:"), with: nil))
#else
    text.undoManager?.undo()
#endif
  }

  func redo(in text: IngredientPlatformTextView) {
#if os(macOS)
    XCTAssertTrue(text.tryToPerform(NSSelectorFromString("redo:"), with: nil))
#else
    text.undoManager?.redo()
#endif
  }

  func textView() throws -> IngredientPlatformTextView {
    func find(in view: IngredientPlatformView) -> IngredientPlatformTextView? {
      if let text = view as? IngredientPlatformTextView { return text }
      return view.subviews.lazy.compactMap { find(in: $0) }.first
    }
    return try XCTUnwrap(find(in: root))
  }

  func paste(_ value: String, into text: IngredientPlatformTextView) {
#if os(macOS)
    let board = NSPasteboard.withUniqueName()
    defer { board.releaseGlobally() }
    board.setString(value, forType: .string)
    XCTAssertTrue(text.readSelection(from: board, type: .string))
    text.didChangeText()
#else
    text.paste(itemProviders: [NSItemProvider(object: value as NSString)])
#endif
  }

  func selection(in text: IngredientPlatformTextView) -> NSRange {
#if os(macOS)
    text.selectedRange()
#else
    text.selectedRange
#endif
  }

  func select(_ range: NSRange, in text: IngredientPlatformTextView) {
#if os(macOS)
    text.setSelectedRange(range)
#else
    text.selectedRange = range
#endif
  }
}
