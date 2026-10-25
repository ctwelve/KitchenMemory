// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
@testable import KitchenMemory
import XCTest

@MainActor
final class SessionProgressHistoryPresentationTests: XCTestCase {
  func testUnopenedScenePendingHistoryBlocksOrdinaryDeliveryAfterRegistryRecreation() async throws {
    try await verifyDisposedRecovery(rejectedInverse: false)
  }

  func testDisposedRejectedInverseOffersExplicitDiscardWithoutChangingFacts() async throws {
    try await verifyDisposedRecovery(rejectedInverse: true)
  }

  private func verifyDisposedRecovery(rejectedInverse: Bool) async throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let recipe = try XCTUnwrap(app.libraryModel.recipes.first)
    let organization = try XCTUnwrap(app.libraryModel.organization)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      .appendingPathComponent(String(repeating: "a", count: 64))
    defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }
    let boundary = InterruptedProgressHistoryRepository(
      SwiftDataRecipeOrganizationRepository(modelContainer: app.modelContainer))
    let registry = try OrganizationHistoryRegistry(repository: boundary, organization: organization,
      ownerID: app.ownerID, storeID: "test", kitchenID: recipe.recipe.kitchenID, directory: directory)
    registry.installSessions(app.sessionModel, repository: app.cookingSessionRepository)
    let model = app.sessionModel
    model.loadIfNeeded()
    XCTAssertTrue(model.start(from: recipe))
    let session = try XCTUnwrap(model.currentSession)
    let instruction = try XCTUnwrap(session.snapshot.instructionSections.first?.steps.first)
    let sceneID = UUID()
    let history = registry.presentation(for: sceneID)
    await history.open()
    boundary.failNextAcceptance = !rejectedInverse
    XCTAssertTrue(model.setInstruction(instruction.id, to: .completed, history: history))
    await model.delivery.waitForHistoryDelivery()
    if rejectedInverse {
      boundary.rejectNextAcceptance = true
      await history.undo()
      _ = try app.cookingSessions.perform(.setOutcome(
        .init(id: .init(), sessionID: session.id, authoredAt: Date()), .coarse(.okay)))
    }
    await history.disconnect()
    history.disposeScene()

    let restored = try OrganizationHistoryRegistry(repository: boundary, organization: organization,
      ownerID: app.ownerID, storeID: "test", kitchenID: recipe.recipe.kitchenID, directory: directory)
    let relaunched = CookingSessionPresentationModel(sessions: app.cookingSessions,
      store: VolatileCookingSessionPresentationStore())
    restored.installSessions(relaunched, repository: app.cookingSessionRepository)
    XCTAssertEqual(relaunched.delivery.pendingHistorySessions(), [session.id])
    XCTAssertFalse(relaunched.start(from: recipe), "No scene has opened, but its durable pending barrier still applies")
    let resumed = restored.presentation(for: sceneID)
    await restored.recoverRetainedSessionHistory()
    if rejectedInverse {
      XCTAssertTrue(relaunched.delivery.canDiscardRetainedHistory)
      XCTAssertEqual(relaunched.delivery.pendingHistorySessions(), [session.id])
      await restored.recoverRetainedSessionHistory(discardRejected: true)
    }
    XCTAssertTrue(relaunched.delivery.pendingHistorySessions().isEmpty)
    await resumed.open()
    XCTAssertFalse(resumed.canUndo)
    XCTAssertEqual(try app.cookingSessionRepository.evidence(id: session.id)?.facts.count, rejectedInverse ? 2 : 1)
    await resumed.disconnect()
    let sidecar = directory.appendingPathComponent(restored.generation.uuidString)
      .appendingPathComponent(sceneID.uuidString).appendingPathComponent("History.sqlite.organization-pending.json")
    try assertUnreadableRecoveryIsPreserved(at: sidecar, model: relaunched, recipe: recipe)
  }

  func testPendingSessionCommandDisablesTheActualNativeUndoRoute() async throws {
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
    XCTAssertTrue(try XCTUnwrap(history.nativeUndoManager).canUndo)
    // Public delivery preserves a refused intention for its normal retry owner.
    XCTAssertFalse(model.submitIndependentCommand(.progress(factID: .init(), sessionID: session.id,
      authoredAt: Date(), progress: SessionProgress(target: .ingredient(.init()), state: .ingredient(.accounted)))))
    XCTAssertFalse(model.pendingCommands.isEmpty)
    XCTAssertFalse(try XCTUnwrap(history.nativeUndoManager).canUndo)
    XCTAssertFalse(try XCTUnwrap(history.nativeUndoManager).canRedo)
    await history.disconnect()
  }

  func testHistoryRefreshDoesNotNavigateWhenFinishArrivesBeforeItsNotification() async throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let recipe = try XCTUnwrap(app.libraryModel.recipes.first)
    let model = app.sessionModel
    model.loadIfNeeded()
    XCTAssertTrue(model.start(from: recipe))
    let session = try XCTUnwrap(model.currentSession)
    let history = app.organizationHistory.presentation(for: UUID())
    await history.open()
    let destination = model.navigation.destination
    _ = try app.cookingSessions.perform(.finish(.init(closureID: .init(), sessionID: session.id,
      finishedAt: Date(), hasMeaningfulDraft: false)))
    history.refresh()
    XCTAssertEqual(model.navigation.destination, destination)
    await history.disconnect()
  }

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
  private func assertUnreadableRecoveryIsPreserved(at sidecar: URL,
                                                  model: CookingSessionPresentationModel, recipe: StoredRecipe) throws {
    let unreadable = Data("unsupported recovery envelope".utf8)
    try unreadable.write(to: sidecar)
    XCTAssertTrue(model.delivery.historyRecoveryUnavailable())
    XCTAssertFalse(model.start(from: recipe))
    XCTAssertEqual(try Data(contentsOf: sidecar), unreadable)
  }

}
