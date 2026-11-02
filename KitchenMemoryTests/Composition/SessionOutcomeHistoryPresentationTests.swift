// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
@testable import KitchenMemory
import XCTest

@MainActor
final class SessionOutcomeHistoryPresentationTests: XCTestCase {
  func testNativeOutcomeUndoRestoresNoneWithoutMovingTheReaderOrFocus() async throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let model = app.sessionModel
    model.loadIfNeeded()
    XCTAssertTrue(model.start(from: try XCTUnwrap(app.libraryModel.recipes.first)))
    let history = app.organizationHistory.presentation(for: UUID())
    await history.open()
    XCTAssertTrue(model.setOutcome(.coarse(.great), history: history))
    await model.delivery.waitForHistoryDelivery()
    XCTAssertEqual(model.currentSession?.outcome, .coarse(.great))
    let destination = model.navigation.destination
    let reading = model.readingPreferences
    history.updateLocale(Locale(identifier: "en-US"))
    let native = try RecipeOrganizationNativeFixture(history: history)
    defer { native.close() }
    XCTAssertTrue(native.focusText())
    let manager = try XCTUnwrap(history.nativeUndoManager)
    XCTAssertTrue(manager.canUndo)
    XCTAssertEqual(manager.undoActionName, "Set Cooking Outcome")
    manager.undo()
    await history.waitForNativeOperations()
    XCTAssertNil(model.currentSession?.outcome)
    XCTAssertEqual(model.navigation.destination, destination)
    XCTAssertEqual(model.readingPreferences, reading)
    XCTAssertTrue(native.textIsFirstResponder)
    XCTAssertTrue(manager.canRedo)
    manager.redo()
    await history.waitForNativeOperations()
    XCTAssertEqual(model.currentSession?.outcome, .coarse(.great))
    await history.disconnect()
  }

  func testSetAndClearNoOpsPreserveDistinctNativeGroupsAndRedo() async throws {
    let app = try startedOutcomeApp()
    let model = app.sessionModel
    let id = try XCTUnwrap(model.currentSession?.id)
    let history = app.organizationHistory.presentation(for: UUID())
    await history.open()
    XCTAssertTrue(model.clearOutcome(history: history))
    for _ in 0..<2 {
      XCTAssertTrue(model.setOutcome(.coarse(.okay), history: history))
      await model.delivery.waitForHistoryDelivery()
    }
    XCTAssertTrue(model.clearOutcome(history: history))
    await model.delivery.waitForHistoryDelivery()
    XCTAssertTrue(model.clearOutcome(history: history))
    XCTAssertEqual(try app.cookingSessionRepository.evidence(id: id)?.facts.count, 2)
    let native = try RecipeOrganizationNativeFixture(history: history)
    defer { native.close() }
    native.leaveText()
    history.updateLocale(Locale(identifier: "en-US"))
    XCTAssertEqual(native.routedManager?.undoActionName, "Clear Cooking Outcome")
    native.routedManager?.undo()
    await history.waitForNativeOperations()
    XCTAssertEqual(model.currentSession?.outcome, .coarse(.okay))
    XCTAssertTrue(model.setOutcome(.coarse(.okay), history: history))
    XCTAssertTrue(history.canRedo, "An unchanged choice must preserve Redo")
    history.updateLocale(Locale(identifier: "fr-CA"))
    XCTAssertEqual(native.routedManager?.undoActionName, "Définir le résultat de cuisson")
    native.routedManager?.undo()
    await history.waitForNativeOperations()
    XCTAssertNil(model.currentSession?.outcome)
    XCTAssertFalse(history.canUndo)
    XCTAssertTrue(model.clearOutcome(history: history))
    XCTAssertTrue(history.canRedo)
    await history.disconnect()
  }

  func testOutcomeKeepsTextPriorityAndInterleavesWithWorkingScale() async throws {
    let app = try startedOutcomeApp()
    let model = app.sessionModel
    let original = try XCTUnwrap(model.currentSession)
    let history = app.organizationHistory.presentation(for: UUID())
    await history.open()
    XCTAssertTrue(model.setOutcome(.coarse(.great), history: history))
    await model.delivery.waitForHistoryDelivery()
    var selection = CookingSessionScaleSelection(session: original)
    selection.selectFactor(.init(numerator: 2))
    XCTAssertTrue(model.replaceWorkingScale(with: try XCTUnwrap(selection.scale), history: history))
    await model.delivery.waitForHistoryDelivery()
    let native = try RecipeOrganizationNativeFixture(history: history)
    defer { native.close() }
    XCTAssertTrue(native.focusText())
    native.typeText("temporary note")
    native.routedManager?.undo()
    XCTAssertEqual(native.text, "")
    XCTAssertFalse(try XCTUnwrap(native.routedManager).canUndo)
    native.routedManager?.undo()
    await history.waitForNativeOperations()
    XCTAssertEqual(model.currentSession?.workingScale?.exactScale, .init(numerator: 2))
    native.leaveText()
    native.routedManager?.undo()
    await history.waitForNativeOperations()
    XCTAssertEqual(model.currentSession?.workingScale, original.workingScale)
    XCTAssertEqual(model.currentSession?.outcome, .coarse(.great))
    native.routedManager?.undo()
    await history.waitForNativeOperations()
    XCTAssertNil(model.currentSession?.outcome)
    await history.disconnect()
  }

  func testPendingWorkBlocksOutcomeSetClearAndNativeUndo() async throws {
    let app = try startedOutcomeApp()
    let model = app.sessionModel
    let id = try XCTUnwrap(model.currentSession?.id)
    let history = app.organizationHistory.presentation(for: UUID())
    await history.open()
    XCTAssertTrue(model.setOutcome(.coarse(.great), history: history))
    await model.delivery.waitForHistoryDelivery()
    XCTAssertFalse(model.submitIndependentCommand(.progress(factID: .init(), sessionID: id,
      authoredAt: Date(), progress: .init(target: .ingredient(.init()), state: .ingredient(.accounted)))))
    XCTAssertFalse(model.setOutcome(.coarse(.okay), history: history))
    XCTAssertFalse(model.clearOutcome(history: history))
    XCTAssertFalse(try XCTUnwrap(history.nativeUndoManager).canUndo)
    XCTAssertFalse(try XCTUnwrap(history.nativeUndoManager).canRedo)
    XCTAssertEqual(try app.cookingSessionRepository.evidence(id: id)?.facts.count, 1)
    await history.disconnect()
  }

  func testConflictingOutcomeResolutionStaysOnTheOrdinaryNonUndoPath() async throws {
    for clearing in [false, true] {
      let app = try conflictingOutcomeApp()
      let model = app.sessionModel
      let history = app.organizationHistory.presentation(for: UUID())
      await history.open()
      let accepted = clearing ? model.clearOutcome(history: history)
        : model.setOutcome(.coarse(.okay), history: history)
      XCTAssertTrue(accepted)
      XCTAssertEqual(model.currentSession?.outcome, clearing ? nil : .coarse(.okay))
      XCTAssertEqual(model.currentSession?.conflicts.isEmpty, true)
      XCTAssertFalse(model.delivery.historyInFlight)
      XCTAssertFalse(history.canUndo)
      await history.disconnect()
    }
  }

  private func startedOutcomeApp() throws -> PreparedApp {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    app.sessionModel.loadIfNeeded()
    XCTAssertTrue(app.sessionModel.start(from: try XCTUnwrap(app.libraryModel.recipes.first)))
    return app
  }

  private func conflictingOutcomeApp() throws -> PreparedApp {
    let app = try startedOutcomeApp()
    let model = app.sessionModel
    XCTAssertTrue(model.setOutcome(.coarse(.great)))
    let session = try XCTUnwrap(model.currentSession)
    let evidence = try XCTUnwrap(app.cookingSessionRepository.evidence(id: session.id))
    let head = try XCTUnwrap(evidence.facts.first?.id)
    for value in [SessionOutcome.CoarseValue.okay, .unsuccessful] {
      let fact = try concurrentSessionFact(sessionID: session.id,
        kitchenID: try XCTUnwrap(evidence.roots.first?.kitchenID), head: head,
        kind: .sessionOutcome, payload: .sessionOutcome(.set(.coarse(value))))
      try app.cookingSessionRepository.append(.activity(fact))
    }
    model.reloadAfterExternalStoreChange()
    XCTAssertFalse(try XCTUnwrap(model.currentSession).conflicts.isEmpty)
    return app
  }

}
