// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
@testable import KitchenMemory
import SwiftUI
import XCTest

@MainActor
final class NativeIngredientPasteTests: XCTestCase {
  func testSingleLineIngredientPasteInterpretsWithoutLeavingTheLine() async throws {
    var document = RecipeIngredientTextDraft(sections: [])
    let interpreted = expectation(description: "Pasted ingredient interpreted")
    var completed = false
    let binding = Binding(get: { document }, set: {
      document = $0
      if !completed, document.text == "2 cups flour", document.lines.allSatisfy(\.isInterpreted) {
        completed = true
        interpreted.fulfill()
      }
    })
    let host = try IngredientPasteHost(document: binding)
    defer { host.close() }
    let text = try host.textView()
    host.focus(text)
    host.paste("2 cups flour", into: text)
    await fulfillment(of: [interpreted], timeout: 3)
    XCTAssertEqual(document.text, "2 cups flour")
    let ingredient = try XCTUnwrap(document.sections.first?.ingredients.first)
    XCTAssertEqual(ingredient.quantity?.lowerBound?.numerator, 2)
    XCTAssertEqual(ingredient.ingredientText, "flour")
    XCTAssertEqual(host.selection(in: text), NSRange(location: 12, length: 0))
  }

  func testSingleLineHeadingPasteRetainsSectionIdentityThroughNativeUndoAndRedo() async throws {
    var document = RecipeIngredientTextDraft(sections: [])
    let interpreted = expectation(description: "Pasted heading interpreted")
    var completed = false
    let binding = Binding(get: { document }, set: {
      document = $0
      if !completed, document.sections.first?.title == "Sauce" {
        completed = true
        interpreted.fulfill()
      }
    })
    let host = try IngredientPasteHost(document: binding)
    defer { host.close() }
    let text = try host.textView()
    host.focus(text)
    host.paste("# Sauce", into: text)
    await fulfillment(of: [interpreted], timeout: 3)
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
    var document = RecipeIngredientTextDraft(sections: [])
    let host = try IngredientPasteHost(document: Binding(get: { document }, set: { document = $0 }))
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
    var document = RecipeIngredientTextDraft(sections: [IngredientSection(ingredients: [flour])])
    let actions = IngredientTextActions()
    let host = try IngredientPasteHost(document: Binding(get: { document }, set: { document = $0 }),
                                       actions: actions)
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

  init(document: Binding<RecipeIngredientTextDraft>, actions: IngredientTextActions = .init()) throws {
    let editor = NativeIngredientText(document: document, actions: actions)
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
}
