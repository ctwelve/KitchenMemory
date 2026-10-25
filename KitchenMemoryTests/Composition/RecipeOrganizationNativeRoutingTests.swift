// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
@testable import KitchenMemory
import SwiftUI
import XCTest
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
final class RecipeOrganizationNativeRoutingTests: XCTestCase {
  func testSceneUndoPreservesFocusedNativeTextAndIndependentWindowHistory() async throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let model = try XCTUnwrap(app.libraryModel.organization)
    let recipes = app.libraryModel.recipes
    XCTAssertGreaterThan(recipes.count, 1)
    let folder = Folder.ID()
    model.perform { try $0.prepare(folder: .create(id: folder, name: "Dinner", parentID: nil)) }
    let first = app.organizationHistory.presentation(for: UUID())
    let second = app.organizationHistory.presentation(for: UUID())
    await first.open()
    await second.open()
    await model.move([recipes[0].id], to: folder, history: first)
    await model.move([recipes[1].id], to: folder, history: second)
    let native = try RecipeOrganizationNativeFixture(history: first)
#if !os(macOS)
    await Task.yield()
    XCTAssertTrue(native.hostIsFirstResponder, "The scene host must receive system Undo gestures outside text editing")
#endif
    defer { native.close() }
    let secondNative = try RecipeOrganizationNativeFixture(history: second)
    defer { secondNative.close() }
    XCTAssertTrue(native.focusText())
    native.typeText("temporary note")
    let textManager = try XCTUnwrap(native.routedManager)
    XCTAssertTrue(textManager.canUndo)
    textManager.undo()
    XCTAssertEqual(native.text, "")
    XCTAssertEqual(model.snapshot?.folders.primaryFolder(for: recipes[0].id), folder)
    XCTAssertFalse(try XCTUnwrap(native.routedManager).canUndo)
    native.routedManager?.undo()
    await first.waitForNativeOperations()
    XCTAssertEqual(model.snapshot?.folders.primaryFolder(for: recipes[0].id), folder)
    native.leaveText()
    XCTAssertTrue(try XCTUnwrap(native.routedManager).canUndo)
    native.routedManager?.undo()
    await first.waitForNativeOperations()
    XCTAssertNil(model.snapshot?.folders.primaryFolder(for: recipes[0].id))
    XCTAssertEqual(model.snapshot?.folders.primaryFolder(for: recipes[1].id), folder)
    XCTAssertTrue(second.canUndo)
    secondNative.leaveText()
    secondNative.routedManager?.undo()
    await second.waitForNativeOperations()
    XCTAssertNil(model.snapshot?.folders.primaryFolder(for: recipes[1].id))
    XCTAssertTrue(first.canRedo)
  }

  func testTagAndFolderTimelineKeepsFocusedTextUndoAndSceneRouting() async throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let model = try XCTUnwrap(app.libraryModel.organization)
    let recipe = try XCTUnwrap(app.libraryModel.recipes.first)
    let folder = Folder.ID(), tag = Tag.ID()
    model.perform { try $0.prepare(folder: .create(id: folder, name: "Dinner", parentID: nil)) }
    model.perform { try $0.prepare(tag: .create(id: tag, name: "Quick")) }
    let history = app.organizationHistory.presentation(for: UUID())
    await history.open()
    await model.move([recipe.id], to: folder, history: history)
    await model.classify([recipe.id], tagID: tag, adding: true, history: history)
    let native = try RecipeOrganizationNativeFixture(history: history)
    defer { native.close() }
    XCTAssertTrue(native.focusText())
    native.typeText("temporary note")
    native.routedManager?.undo()
    XCTAssertEqual(native.text, "")
    XCTAssertEqual(model.snapshot?.tags.tagIDs(for: recipe.id).contains(tag), true)
    XCTAssertFalse(try XCTUnwrap(native.routedManager).canUndo)
    native.routedManager?.undo()
    await history.waitForNativeOperations()
    XCTAssertEqual(model.snapshot?.tags.tagIDs(for: recipe.id).contains(tag), true)
    native.leaveText()
    native.routedManager?.undo()
    await history.waitForNativeOperations()
    XCTAssertEqual(model.snapshot?.tags.tagIDs(for: recipe.id).contains(tag), false)
    XCTAssertEqual(model.snapshot?.folders.primaryFolder(for: recipe.id), folder)
    native.routedManager?.undo()
    await history.waitForNativeOperations()
    XCTAssertNil(model.snapshot?.folders.primaryFolder(for: recipe.id))
    XCTAssertTrue(history.canRedo)
    await history.disconnect()
  }

}

#if os(macOS)
@MainActor
final class RecipeOrganizationNativeFixture {
  private let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
                                styleMask: [.titled], backing: .buffered, defer: false)
  private let scratch = NSTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
  private let history: OrganizationHistoryPresentation
  init(history: OrganizationHistoryPresentation) throws {
    self.history = history
    window.isReleasedWhenClosed = false
    scratch.allowsUndo = true
    scratch.isRichText = false
    window.contentView?.addSubview(scratch)
    window.makeKeyAndOrderFront(nil)
  }
  var routedManager: UndoManager? {
    OrganizationHistoryNativeRouting.manager(history: history, responder: window.firstResponder)
  }
  var text: String { scratch.string }
  var textIsFirstResponder: Bool { window.firstResponder === scratch }
  func focusText() -> Bool {
    window.makeKeyAndOrderFront(nil)
    return window.makeFirstResponder(scratch)
  }
  func typeText(_ value: String) {
    scratch.undoManager?.beginUndoGrouping()
    scratch.insertText(value, replacementRange: NSRange(location: 0, length: 0))
    scratch.breakUndoCoalescing()
    while let manager = scratch.undoManager, manager.groupingLevel > 0 { manager.endUndoGrouping() }
  }
  func leaveText() { window.makeKeyAndOrderFront(nil); window.makeFirstResponder(nil) }
  func close() { window.close() }
}
#else
@MainActor
final class RecipeOrganizationNativeFixture {
  private let window: UIWindow
  private let controller: OrganizationHistoryHostingController<Text>
  private let scratch = UITextView(frame: CGRect(x: 0, y: 0, width: 300, height: 100))
  private weak var previousKeyWindow: UIWindow?
  init(history: OrganizationHistoryPresentation) throws {
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive })
    previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
    window = UIWindow(windowScene: scene)
    controller = OrganizationHistoryHostingController(rootView: Text("Library"), history: history)
    window.rootViewController = controller
    controller.view.addSubview(scratch)
    window.makeKeyAndVisible()
  }
  var hostIsFirstResponder: Bool { controller.isFirstResponder }
  var routedManager: UndoManager? { controller.undoManager }
  var text: String { scratch.text }
  var textIsFirstResponder: Bool { scratch.isFirstResponder }
  func focusText() -> Bool { window.makeKeyAndVisible(); return scratch.becomeFirstResponder() }
  func typeText(_ value: String) { scratch.insertText(value) }
  func leaveText() { window.makeKeyAndVisible(); scratch.resignFirstResponder() }
  func close() { window.isHidden = true; previousKeyWindow?.makeKey() }
}
#endif
