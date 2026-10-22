// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenKit
import SwiftData
import UndoKit
import XCTest

@MainActor
final class RecipeOrganizationHistoryTests: XCTestCase {
  func testSavedMoveUndoRedoAndReopenPreserveRecipeAndPriorPlacement() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let container = try KitchenMemorySchema.makeContainer(storeURL: directory.appendingPathComponent("Kitchen.store"))
    let recipes = SwiftDataRecipeRepository(modelContainer: container)
    let repository = SwiftDataRecipeOrganizationRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try recipes.save(kitchen)
    let folder = Folder.ID()
    try repository.accept(repository.load(in: kitchen.id).prepare(
      folder: .create(id: folder, name: "Meals", parentID: nil)))
    let save = try RecipeEditor(repository: recipes).prepareSave(in: kitchen.id, from: RecipeDraft(title: "Soup"),
                                                               original: nil, observedSelectionIDs: [])
    try recipes.save(save)
    let scope = RecipeOrganizationHistoryScope(ownerID: KitchenOwner.ID(rawValue: "test-owner"), storeID: "local-test",
      kitchenID: kitchen.id, logicalSceneID: UUID())
    let url = directory.appendingPathComponent("History.sqlite")
    let history = RecipeOrganizationHistory(repository: repository)
    try await history.open(scope: scope, historyURL: url)
    assertOrganizationHistoryAccepted(try await history.move([save.recipe.id], to: folder))
    XCTAssertEqual(try repository.load(in: kitchen.id).folders.primaryFolder(for: save.recipe.id), folder)
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertNil(try repository.load(in: kitchen.id).folders.primaryFolder(for: save.recipe.id))
    assertOrganizationHistoryAccepted(await history.redo())
    XCTAssertEqual(try repository.load(in: kitchen.id).folders.primaryFolder(for: save.recipe.id), folder)
    await history.close()

    let restored = RecipeOrganizationHistory(repository: repository)
    try await restored.open(scope: scope, historyURL: url)
    XCTAssertTrue(try XCTUnwrap(restored.session).status.canUndo)
    assertOrganizationHistoryAccepted(await restored.undo())
    XCTAssertNil(try repository.load(in: kitchen.id).folders.primaryFolder(for: save.recipe.id))
    XCTAssertEqual(try recipes.recipe(id: save.recipe.id)?.revision, save.revision)
    await restored.close()
  }

  func testRepeatedAndOlderMovesFoldOnlyAcceptedSceneEvidence() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let history = RecipeOrganizationHistory(repository: fixture.repository)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    assertOrganizationHistoryAccepted(try await history.move([fixture.recipeID], to: fixture.first))
    assertOrganizationHistoryAccepted(try await history.move([fixture.recipeID], to: fixture.second))
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertEqual(try fixture.placement(), fixture.first)
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertNil(try fixture.placement())
    assertOrganizationHistoryAccepted(await history.redo())
    assertOrganizationHistoryAccepted(await history.redo())
    XCTAssertEqual(try fixture.placement(), fixture.second)
    assertOrganizationHistoryAccepted(await history.undo())
    assertOrganizationHistoryAccepted(await history.redo())
    XCTAssertEqual(try fixture.placement(), fixture.second)
    await history.close()
  }

  func testNoOpCreatesNoUndoAndUnrelatedEvidenceDoesNotInvalidateMove() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let history = RecipeOrganizationHistory(repository: fixture.repository)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    let noOp = try await history.move([fixture.recipeID], to: nil)
    XCTAssertEqual(noOp, .rejected)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canUndo)
    assertOrganizationHistoryAccepted(try await history.move([fixture.recipeID], to: fixture.first))
    try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).prepare(
      folder: .rename(id: fixture.second, name: "Other meals")))
    let unrelated = Folder.ID(), another = Folder.ID()
    for (id, name) in [(unrelated, "Unrelated"), (another, "Another")] {
      try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).prepare(
        folder: .create(id: id, name: name, parentID: nil)))
    }
    try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).prepare(
      folder: .merge(ids: [unrelated, another], survivorID: unrelated, name: "Combined")))
    try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).prepare(
      folder: .delete(id: unrelated)))
    try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).prepare(folder: .ordering(.manual)))
    try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).prepare(
      folder: .systemViewVisible(false)))
    _ = await history.reconcile()
    XCTAssertTrue(try XCTUnwrap(history.session).status.canUndo)
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertNil(try fixture.placement())
    await history.close()
  }

  func testExternalMoveReturningToSamePlacementRefusesInverseAndStaysRetiredAfterReopen() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let history = RecipeOrganizationHistory(repository: fixture.repository)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    assertOrganizationHistoryAccepted(try await history.move([fixture.recipeID], to: fixture.first))
    try fixture.moveOutsideHistory(to: fixture.second)
    try fixture.moveOutsideHistory(to: fixture.first)
    let rejected = await history.undo()
    XCTAssertEqual(rejected, .rejected)
    XCTAssertTrue(history.hasPendingCompensation)
    XCTAssertEqual(try fixture.placement(), fixture.first)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canRedo)
    await history.close()
    let reopened = RecipeOrganizationHistory(repository: fixture.repository)
    try await reopened.open(scope: fixture.scope, historyURL: fixture.historyURL)
    XCTAssertTrue(reopened.hasPendingCompensation)
    XCTAssertFalse(try XCTUnwrap(reopened.session).status.canUndo)
    XCTAssertFalse(try XCTUnwrap(reopened.session).status.canRedo)
    await reopened.close()
  }

  func testRejectedInverseRetainsFrozenCompensationForExactRetryAcrossReopen() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let boundary = ControlledHistoryRepository(fixture.repository)
    let history = RecipeOrganizationHistory(repository: boundary)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    assertOrganizationHistoryAccepted(try await history.move([fixture.recipeID], to: fixture.first))
    boundary.rejectNextAcceptance = true
    let rejected = await history.undo()
    XCTAssertEqual(rejected, .rejected)
    let frozen = try XCTUnwrap(boundary.deliveries.last)
    XCTAssertTrue(history.hasPendingCompensation)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canRedo)
    await history.close()
    let reopened = RecipeOrganizationHistory(repository: boundary)
    try await reopened.open(scope: fixture.scope, historyURL: fixture.historyURL)
    XCTAssertTrue(reopened.hasPendingCompensation)
    _ = try await reopened.retryPending()
    XCTAssertEqual(boundary.deliveries.last, frozen, "Retry retains token, causal frontier, dates, and action IDs")
    XCTAssertNil(try fixture.placement())
    XCTAssertFalse(reopened.hasPendingCompensation)
    XCTAssertFalse(try XCTUnwrap(reopened.session).status.canRedo)
    await reopened.close()
  }

  func testLostAcceptanceReplyReconcilesExactFullTokenBeforeEligibility() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let boundary = ControlledHistoryRepository(fixture.repository)
    let history = RecipeOrganizationHistory(repository: boundary)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    boundary.loseNextReply = true
    boundary.withholdReceipts = true
    let unresolved = try await history.move([fixture.recipeID], to: fixture.first)
    guard case .unresolved = unresolved else { XCTFail("Lost reply must require outcome reconciliation")
return }
    XCTAssertEqual(try fixture.placement(), fixture.first)
    let delivery = try XCTUnwrap(boundary.deliveries.last)
    let count = boundary.deliveries.count
    await history.close()
    boundary.withholdReceipts = false
    let reopened = RecipeOrganizationHistory(repository: boundary)
    try await reopened.open(scope: fixture.scope, historyURL: fixture.historyURL)
    XCTAssertEqual(boundary.deliveries.count, count, "Opening restores accepted evidence without replay")
    XCTAssertTrue(try XCTUnwrap(reopened.session).status.canUndo)
    // Receipt-first exact acceptance remains valid even when a later writer changes eligibility.
    try fixture.moveOutsideHistory(to: fixture.second)
    XCTAssertNoThrow(try fixture.repository.acceptHistory(delivery))
    _ = await reopened.reconcile()
    XCTAssertFalse(try XCTUnwrap(reopened.session).status.canUndo)
    await reopened.close()
  }

  func testRemovedPriorFolderAndMergedTargetCannotBeRestoredByInverse() async throws {
    for merged in [false, true] {
      let fixture = try HistoryFixture()
      defer { fixture.removeFiles() }
      try fixture.moveOutsideHistory(to: fixture.first)
      let history = RecipeOrganizationHistory(repository: fixture.repository)
      try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
      assertOrganizationHistoryAccepted(try await history.move([fixture.recipeID], to: fixture.second))
      let intent: FolderIntent = merged
        ? .merge(ids: [fixture.first, fixture.second], survivorID: fixture.second, name: "Together")
        : .delete(id: fixture.first)
      try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).prepare(folder: intent))
      let rejected = await history.undo()
      XCTAssertEqual(rejected, .rejected)
      XCTAssertEqual(try fixture.placement(), fixture.second)
      XCTAssertFalse(try XCTUnwrap(history.session).status.canRedo)
      await history.close()
    }
  }

  func testExplicitDiscardOfProvedRejectedCompensationAllowsFreshHistory() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let boundary = ControlledHistoryRepository(fixture.repository)
    let history = RecipeOrganizationHistory(repository: boundary)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    assertOrganizationHistoryAccepted(try await history.move([fixture.recipeID], to: fixture.first))
    boundary.rejectNextAcceptance = true
    _ = await history.undo()
    XCTAssertTrue(history.canDiscardRejectedCompensation)
    try await history.discardRejectedCompensation()
    XCTAssertFalse(history.hasPendingCompensation)
    XCTAssertFalse(history.canDiscardRejectedCompensation)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canRedo)
    assertOrganizationHistoryAccepted(try await history.move([fixture.recipeID], to: fixture.second))
    await history.close()
    let reopened = RecipeOrganizationHistory(repository: boundary)
    try await reopened.open(scope: fixture.scope, historyURL: fixture.historyURL)
    assertOrganizationHistoryAccepted(await reopened.undo())
    XCTAssertEqual(try fixture.placement(), fixture.first)
    await reopened.close()
  }

  func testSuccessiveSavedMovesKeepIntentFingerprintBounded() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let history = RecipeOrganizationHistory(repository: fixture.repository)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    for index in 0..<24 {
      assertOrganizationHistoryAccepted(try await history.move(
        [fixture.recipeID], to: index.isMultiple(of: 2) ? fixture.first : fixture.second))
    }
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertEqual(try fixture.placement(), fixture.first)
    await history.close()
  }

}
