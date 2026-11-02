// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
@testable import KitchenMemory
import XCTest

@MainActor
final class SessionScaleHistoryPresentationTests: XCTestCase {
  func testCommittedScaleUsesNativeUndoWithoutChangingReadingOrFocus() async throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let recipe = try XCTUnwrap(app.libraryModel.recipes.first)
    let model = app.sessionModel
    model.loadIfNeeded()
    XCTAssertTrue(model.start(from: recipe))
    let original = try XCTUnwrap(model.currentSession)
    let history = app.organizationHistory.presentation(for: UUID())
    await history.open()
    let selection = CookingSessionScaleSelection(session: original)
    var doubled = selection
    doubled.selectFactor(.init(numerator: 2))
    XCTAssertTrue(model.replaceWorkingScale(with: try XCTUnwrap(doubled.scale), history: history))
    await model.delivery.waitForHistoryDelivery()
    let changed = try XCTUnwrap(model.currentSession?.workingScale)
    XCTAssertEqual(changed.exactScale, .init(numerator: 2))
    let destination = model.navigation.destination
    let reading = model.readingPreferences
    history.updateLocale(Locale(identifier: "en-US"))
    let native = try RecipeOrganizationNativeFixture(history: history)
    defer { native.close() }
    XCTAssertTrue(native.focusText())
    let manager = try XCTUnwrap(history.nativeUndoManager)
    XCTAssertTrue(manager.canUndo)
    XCTAssertEqual(manager.undoActionName, "Change Cooking Scale")
    manager.undo()
    await history.waitForNativeOperations()
    XCTAssertEqual(model.currentSession?.workingScale, original.workingScale)
    XCTAssertEqual(model.navigation.destination, destination)
    XCTAssertEqual(model.readingPreferences, reading)
    XCTAssertTrue(native.textIsFirstResponder)
    XCTAssertTrue(manager.canRedo)
    manager.redo()
    await history.waitForNativeOperations()
    XCTAssertEqual(model.currentSession?.workingScale, changed)
    await history.disconnect()
  }

  func testRepeatedScaleChoicesKeepOneGroupAndFocusedTextRetainsPriority() async throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let model = app.sessionModel
    model.loadIfNeeded()
    XCTAssertTrue(model.start(from: try XCTUnwrap(app.libraryModel.recipes.first)))
    let original = try XCTUnwrap(model.currentSession)
    let history = app.organizationHistory.presentation(for: UUID())
    await history.open()
    var selection = CookingSessionScaleSelection(session: original)
    selection.selectFactor(.init(numerator: 2))
    let doubled = try XCTUnwrap(selection.scale)
    for _ in 0..<2 {
      XCTAssertTrue(model.replaceWorkingScale(with: doubled, history: history))
      await model.delivery.waitForHistoryDelivery()
    }
    XCTAssertEqual(try app.cookingSessionRepository.evidence(id: original.id)?.facts.count, 1)
    let native = try RecipeOrganizationNativeFixture(history: history)
    defer { native.close() }
    XCTAssertTrue(native.focusText())
    native.typeText("temporary note")
    native.routedManager?.undo()
    XCTAssertEqual(native.text, "")
    XCTAssertEqual(model.currentSession?.workingScale?.exactScale, .init(numerator: 2))
    XCTAssertFalse(try XCTUnwrap(native.routedManager).canUndo)
    native.routedManager?.undo()
    await history.waitForNativeOperations()
    XCTAssertEqual(model.currentSession?.workingScale?.exactScale, .init(numerator: 2))
    native.leaveText()
    history.updateLocale(Locale(identifier: "fr-CA"))
    XCTAssertEqual(native.routedManager?.undoActionName, "Modifier les proportions de cuisson")
    native.routedManager?.undo()
    await history.waitForNativeOperations()
    XCTAssertEqual(model.currentSession?.workingScale, original.workingScale)
    XCTAssertFalse(history.canUndo, "Repeated equal choices must not create extra groups")
    XCTAssertTrue(history.canRedo)
    await history.disconnect()
  }

  func testPendingOrdinaryWorkBlocksScaleAndTheNativeHistoryRoute() async throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let model = app.sessionModel
    model.loadIfNeeded()
    XCTAssertTrue(model.start(from: try XCTUnwrap(app.libraryModel.recipes.first)))
    let original = try XCTUnwrap(model.currentSession)
    let history = app.organizationHistory.presentation(for: UUID())
    await history.open()
    var selection = CookingSessionScaleSelection(session: original)
    selection.selectFactor(.init(numerator: 2))
    XCTAssertTrue(model.replaceWorkingScale(with: try XCTUnwrap(selection.scale), history: history))
    await model.delivery.waitForHistoryDelivery()
    XCTAssertTrue(try XCTUnwrap(history.nativeUndoManager).canUndo)
    XCTAssertFalse(model.submitIndependentCommand(.progress(factID: .init(), sessionID: original.id,
      authoredAt: Date(), progress: SessionProgress(target: .ingredient(.init()), state: .ingredient(.accounted)))))
    selection.selectFactor(.init(numerator: 3))
    XCTAssertFalse(model.replaceWorkingScale(with: try XCTUnwrap(selection.scale), history: history))
    XCTAssertFalse(try XCTUnwrap(history.nativeUndoManager).canUndo)
    XCTAssertFalse(try XCTUnwrap(history.nativeUndoManager).canRedo)
    XCTAssertEqual(try app.cookingSessionRepository.evidence(id: original.id)?.facts.count, 1)
    await history.disconnect()
  }

}
