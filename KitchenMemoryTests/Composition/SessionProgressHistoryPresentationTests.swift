// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
@testable import KitchenMemory
import XCTest

@MainActor
final class SessionProgressHistoryPresentationTests: XCTestCase {
  func testStopResumeStartsFreshNativeHistoryAndOtherSceneStaysIndependent() async throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let recipe = try XCTUnwrap(app.libraryModel.recipes.first)
    let model = app.sessionModel
    model.loadIfNeeded()
    XCTAssertTrue(model.start(from: recipe))
    let instruction = try XCTUnwrap(model.currentSession?.snapshot.instructionSections.first?.steps.first)
    let independent = app.organizationHistory.presentation(for: UUID())
    await independent.open()
    let organization = try XCTUnwrap(app.libraryModel.organization)
    let folder = Folder.ID()
    organization.perform { try $0.prepare(folder: .create(id: folder, name: "Meals", parentID: nil)) }
    await organization.move([recipe.id], to: folder, history: independent)
    let history = app.organizationHistory.presentation(for: UUID())
    await history.open()
    XCTAssertTrue(model.setInstruction(instruction.id, to: .completed, history: history))
    await model.delivery.waitForHistoryDelivery()
    XCTAssertTrue(model.stopCurrentSession())
    await app.organizationHistory.waitForReconciliation()
    XCTAssertFalse(history.canUndo)
    XCTAssertTrue(independent.canUndo)
    XCTAssertTrue(model.resumeCurrentSession())
    XCTAssertTrue(model.setInstruction(instruction.id, to: .skipped, history: history))
    await model.delivery.waitForHistoryDelivery()
    let manager = try XCTUnwrap(history.nativeUndoManager)
    XCTAssertTrue(manager.canUndo)
    manager.undo()
    await history.waitForNativeOperations()
    XCTAssertEqual(model.currentSession?.instructionProgress(for: instruction.id), .completed)
    XCTAssertFalse(history.canUndo)
    await history.disconnect()
    await independent.disconnect()
  }

  func testNativeProgressUndoPreservesNavigationAndReadingPreference() async throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let recipe = try XCTUnwrap(app.libraryModel.recipes.first)
    let model = app.sessionModel
    model.loadIfNeeded()
    XCTAssertTrue(model.start(from: recipe))
    let session = try XCTUnwrap(model.currentSession)
    let instruction = try XCTUnwrap(session.snapshot.instructionSections.first?.steps.first)
    let history = app.organizationHistory.presentation(for: UUID())
    await history.open()
    XCTAssertTrue(model.setInstruction(instruction.id, to: .completed, history: history))
    await model.delivery.waitForHistoryDelivery()
    XCTAssertEqual(model.currentSession?.instructionProgress(for: instruction.id), .completed)
    let destination = model.navigation.destination
    let reading = model.readingPreferences
    let manager = try XCTUnwrap(history.nativeUndoManager)
    XCTAssertTrue(manager.canUndo)
    manager.undo()
    await history.waitForNativeOperations()
    XCTAssertEqual(model.currentSession?.instructionProgress(for: instruction.id), .open)
    XCTAssertEqual(model.navigation.destination, destination)
    XCTAssertEqual(model.readingPreferences, reading)
    XCTAssertTrue(manager.canRedo)
    manager.redo()
    await history.waitForNativeOperations()
    XCTAssertEqual(model.currentSession?.instructionProgress(for: instruction.id), .completed)
    await history.disconnect()
  }
}
