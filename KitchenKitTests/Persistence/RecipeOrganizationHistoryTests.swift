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
    assertAccepted(try await history.move([save.recipe.id], to: folder))
    XCTAssertEqual(try repository.load(in: kitchen.id).folders.primaryFolder(for: save.recipe.id), folder)
    assertAccepted(await history.undo())
    XCTAssertNil(try repository.load(in: kitchen.id).folders.primaryFolder(for: save.recipe.id))
    assertAccepted(await history.redo())
    XCTAssertEqual(try repository.load(in: kitchen.id).folders.primaryFolder(for: save.recipe.id), folder)
    await history.close()

    let restored = RecipeOrganizationHistory(repository: repository)
    try await restored.open(scope: scope, historyURL: url)
    XCTAssertTrue(try XCTUnwrap(restored.session).status.canUndo)
    assertAccepted(await restored.undo())
    XCTAssertNil(try repository.load(in: kitchen.id).folders.primaryFolder(for: save.recipe.id))
    XCTAssertEqual(try recipes.recipe(id: save.recipe.id)?.revision, save.revision)
    await restored.close()
  }

  func testRepeatedAndOlderMovesFoldOnlyAcceptedSceneEvidence() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let history = RecipeOrganizationHistory(repository: fixture.repository)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    assertAccepted(try await history.move([fixture.recipeID], to: fixture.first))
    assertAccepted(try await history.move([fixture.recipeID], to: fixture.second))
    assertAccepted(await history.undo())
    XCTAssertEqual(try fixture.placement(), fixture.first)
    assertAccepted(await history.undo())
    XCTAssertNil(try fixture.placement())
    assertAccepted(await history.redo())
    assertAccepted(await history.redo())
    XCTAssertEqual(try fixture.placement(), fixture.second)
    assertAccepted(await history.undo())
    assertAccepted(await history.redo())
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
    assertAccepted(try await history.move([fixture.recipeID], to: fixture.first))
    try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).prepare(
      folder: .rename(id: fixture.second, name: "Other meals")))
    let unrelated = Folder.ID(), another = Folder.ID()
    for (id, name) in [(unrelated, "Unrelated"), (another, "Another")] {
      try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).prepare(
        folder: .create(id: id, name: name, parentID: nil)))
    }
    try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).prepare(
      folder: .merge(ids: [unrelated, another], survivorID: unrelated, name: "Combined")))
    try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).prepare(folder: .delete(id: unrelated)))
    _ = await history.reconcile()
    XCTAssertTrue(try XCTUnwrap(history.session).status.canUndo)
    assertAccepted(await history.undo())
    XCTAssertNil(try fixture.placement())
    await history.close()
  }

  func testExternalMoveReturningToSamePlacementRefusesInverseAndStaysRetiredAfterReopen() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let history = RecipeOrganizationHistory(repository: fixture.repository)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    assertAccepted(try await history.move([fixture.recipeID], to: fixture.first))
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
    assertAccepted(try await history.move([fixture.recipeID], to: fixture.first))
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
    guard case .unresolved = unresolved else { return XCTFail("Lost reply must require outcome reconciliation") }
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
      assertAccepted(try await history.move([fixture.recipeID], to: fixture.second))
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
    assertAccepted(try await history.move([fixture.recipeID], to: fixture.first))
    boundary.rejectNextAcceptance = true
    _ = await history.undo()
    XCTAssertTrue(history.canDiscardRejectedCompensation)
    try await history.discardRejectedCompensation()
    XCTAssertFalse(history.hasPendingCompensation)
    XCTAssertFalse(history.canDiscardRejectedCompensation)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canRedo)
    assertAccepted(try await history.move([fixture.recipeID], to: fixture.second))
    await history.close()
    let reopened = RecipeOrganizationHistory(repository: boundary)
    try await reopened.open(scope: fixture.scope, historyURL: fixture.historyURL)
    assertAccepted(await reopened.undo())
    XCTAssertEqual(try fixture.placement(), fixture.first)
    await reopened.close()
  }

  func testSuccessiveSavedMovesKeepIntentFingerprintBounded() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let history = RecipeOrganizationHistory(repository: fixture.repository)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    for index in 0..<24 {
      assertAccepted(try await history.move([fixture.recipeID], to: index.isMultiple(of: 2) ? fixture.first : fixture.second))
    }
    assertAccepted(await history.undo())
    XCTAssertEqual(try fixture.placement(), fixture.first)
    await history.close()
  }

  func testUnresolvedMoveRetriesFrozenPreparationAndAcceptedReplyWithoutReplay() async throws {
    for acceptedBeforeReply in [false, true] {
      let fixture = try HistoryFixture()
      defer { fixture.removeFiles() }
      let boundary = ControlledHistoryRepository(fixture.repository)
      let history = RecipeOrganizationHistory(repository: boundary)
      try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
      boundary.loseNextReply = acceptedBeforeReply
      boundary.failNextAcceptance = !acceptedBeforeReply
      boundary.withholdReceipts = true
      let original = try await history.move([fixture.recipeID], to: fixture.first)
      guard case .unresolved = original else { return XCTFail("Unknown reply must preserve preparation") }
      let frozen = try XCTUnwrap(boundary.deliveries.last)
      let unknown = await history.reconcile()
      guard case .unresolved = unknown else { return XCTFail("Absent accepted receipt remains unknown") }
      XCTAssertFalse(history.canDiscardRejectedCompensation)
      do {
        try await history.discardRejectedCompensation()
        XCTFail("Ambiguous work cannot be discarded")
      } catch RecipeOrganizationHistoryError.ineligible {}
      boundary.withholdReceipts = false
      let retried = try await history.retryPending()
      assertAccepted(try XCTUnwrap(retried))
      XCTAssertEqual(boundary.deliveries.last, frozen)
      XCTAssertEqual(try fixture.placement(), fixture.first)
      XCTAssertTrue(try XCTUnwrap(history.session).status.canUndo)
      await history.close()
    }
  }

  func testScopeGuardsAndReconciliationFailureNeverAuthorizeChanges() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let wrong = RecipeOrganizationHistoryScope(ownerID: KitchenOwner.ID(rawValue: ""), storeID: "local-test",
      kitchenID: fixture.kitchenID, logicalSceneID: UUID())
    XCTAssertThrowsError(try fixture.repository.prepareHistoryMove(fixture.recipeID, to: fixture.first, in: wrong))
    let owned = Kitchen(id: fixture.kitchenID, ownerID: fixture.scope.ownerID, name: "Home")
    try fixture.recipes.save(owned)
    let boundary = ControlledHistoryRepository(fixture.repository)
    let history = RecipeOrganizationHistory(repository: boundary)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    assertAccepted(try await history.move([fixture.recipeID], to: fixture.first))
    boundary.failNextEligibilityRead = true
    let failure = await history.reconcile()
    guard case .unresolved = failure else { return XCTFail("Failed authority read must remain unresolved") }
    XCTAssertEqual(try fixture.placement(), fixture.first)
    boundary.rejectNextScope = true
    let rejected = try await history.move([fixture.recipeID], to: fixture.second)
    XCTAssertEqual(rejected, .rejected)
    XCTAssertEqual(try fixture.placement(), fixture.first)
    await history.close()
  }

  func testDeletionAndRestorationEvidenceInvalidateEvenWhenRecipeBecomesAvailableAgain() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    // Prior disposition evidence is a valid baseline, and must survive later operations.
    for _ in 0..<2 {
      let deletion = RecipeDeleteCommand(kitchenID: fixture.kitchenID, recipeID: fixture.recipeID)
      try fixture.recipes.delete(deletion)
      try fixture.recipes.restore(RecipeRestoreCommand(kitchenID: fixture.kitchenID, recipeID: fixture.recipeID,
        observedDeletionIDs: [deletion.id]))
    }
    let history = RecipeOrganizationHistory(repository: fixture.repository)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    assertAccepted(try await history.move([fixture.recipeID], to: fixture.first))
    let deletion = RecipeDeleteCommand(kitchenID: fixture.kitchenID, recipeID: fixture.recipeID)
    try fixture.recipes.delete(deletion)
    try fixture.recipes.restore(RecipeRestoreCommand(kitchenID: fixture.kitchenID, recipeID: fixture.recipeID,
      observedDeletionIDs: [deletion.id]))
    let rejected = await history.undo()
    XCTAssertEqual(rejected, .rejected)
    XCTAssertEqual(try fixture.placement(), fixture.first)
    await history.close()
  }

  func testUnsupportedPersistedReceiptVersionBlocksRestorationAndPreservesRecipe() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let history = RecipeOrganizationHistory(repository: fixture.repository)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    let result = try await history.move([fixture.recipeID], to: fixture.first)
    guard case let .accepted(acceptance) = result else { return XCTFail("Move must be accepted before compatibility setup") }
    let receipt = try XCTUnwrap(fixture.repository.historyReceipt(for: acceptance.token, in: fixture.scope))
    await history.close()
    // Setup a future persisted envelope through our own SwiftData record family.
    // The assertions exercise only the public recovery boundary.
    let context = ModelContext(fixture.container)
    let payload = FutureHistoryReceipt(version: 99, receipt: receipt)
    context.insert(try OrganizationActionRecord(action: OrganizationAction(id: UUID(), authoredAt: Date(),
      observed: [], payload: payload), kitchenID: fixture.kitchenID, namespace: "organization-history-receipts-v1"))
    try context.save()
    let reopened = RecipeOrganizationHistory(repository: fixture.repository)
    do {
      try await reopened.open(scope: fixture.scope, historyURL: fixture.historyURL)
      XCTFail("A future receipt version cannot restore actionable history")
    } catch RecipeOrganizationHistoryError.invalidEvidence {}
    XCTAssertNotEqual(reopened.session?.status.canUndo, true)
    XCTAssertEqual(try fixture.placement(), fixture.first)
    await reopened.close()
  }

  func testMismatchedFrozenCommandIsRejectedAtomicallyAtPublicAcceptanceBoundary() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let boundary = ControlledHistoryRepository(fixture.repository)
    let history = RecipeOrganizationHistory(repository: boundary)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    boundary.failNextAcceptance = true
    boundary.withholdReceipts = true
    _ = try await history.move([fixture.recipeID], to: fixture.first)
    let frozen = try XCTUnwrap(boundary.deliveries.last)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(frozen)) as? [String: Any])
    var command = try XCTUnwrap(object["command"] as? [String: Any])
    command["kitchenID"] = UUID().uuidString
    object["command"] = command
    let changed = try JSONDecoder().decode(RecipeOrganizationHistoryDelivery.self,
      from: JSONSerialization.data(withJSONObject: object))
    XCTAssertThrowsError(try fixture.repository.acceptHistory(changed))
    XCTAssertNil(try fixture.placement(), "The guard rejects before either the assignment or acceptance receipt commits")
    boundary.withholdReceipts = false
    let retried = try await history.retryPending()
    assertAccepted(try XCTUnwrap(retried))
    XCTAssertEqual(try fixture.placement(), fixture.first)
    await history.close()
  }

  private func assertAccepted(_ result: HistorySubmissionResult, file: StaticString = #filePath,
                              line: UInt = #line) {
    guard case .accepted = result else {
      XCTFail("Expected accepted organization history, got \(result)", file: file, line: line)
      return
    }
  }
}

@MainActor
private struct HistoryFixture {
  let directory: URL
  let container: ModelContainer
  let recipes: SwiftDataRecipeRepository
  let repository: SwiftDataRecipeOrganizationRepository
  let kitchenID: Kitchen.ID
  let recipeID: Recipe.ID
  let first: Folder.ID
  let second: Folder.ID
  let scope: RecipeOrganizationHistoryScope
  var historyURL: URL { directory.appendingPathComponent("History.sqlite") }

  init() throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    container = try KitchenMemorySchema.makeContainer(storeURL: directory.appendingPathComponent("Kitchen.store"))
    recipes = SwiftDataRecipeRepository(modelContainer: container)
    repository = SwiftDataRecipeOrganizationRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    kitchenID = kitchen.id
    try recipes.save(kitchen)
    first = Folder.ID(); second = Folder.ID()
    try repository.accept(repository.load(in: kitchen.id).prepare(
      folder: .create(id: first, name: "Meals", parentID: nil)))
    try repository.accept(repository.load(in: kitchen.id).prepare(
      folder: .create(id: second, name: "Other", parentID: nil)))
    let save = try RecipeEditor(repository: recipes).prepareSave(in: kitchen.id, from: RecipeDraft(title: "Soup"),
                                                               original: nil, observedSelectionIDs: [])
    try recipes.save(save)
    recipeID = save.recipe.id
    scope = RecipeOrganizationHistoryScope(ownerID: KitchenOwner.ID(rawValue: "test-owner"), storeID: "local-test",
      kitchenID: kitchen.id, logicalSceneID: UUID())
  }

  func placement() throws -> Folder.ID? { try repository.load(in: kitchenID).folders.primaryFolder(for: recipeID) }
  func moveOutsideHistory(to folderID: Folder.ID?) throws {
    try repository.accept(repository.load(in: kitchenID).move([recipeID], to: folderID))
  }
  func removeFiles() { try? FileManager.default.removeItem(at: directory) }
}

/// The public repository is the fault boundary. Every accepted effect still uses
/// the real SwiftData transaction; failures model a proved refusal or lost reply.
@MainActor
private final class ControlledHistoryRepository: RecipeOrganizationHistoryRepository {
  let base: SwiftDataRecipeOrganizationRepository
  var rejectNextAcceptance = false
  var failNextAcceptance = false
  var failNextEligibilityRead = false
  var rejectNextScope = false
  var loseNextReply = false
  var withholdReceipts = false
  var deliveries: [RecipeOrganizationHistoryDelivery] = []
  init(_ base: SwiftDataRecipeOrganizationRepository) { self.base = base }
  func load(in kitchenID: Kitchen.ID) throws -> RecipeOrganization { try base.load(in: kitchenID) }
  func accept(_ command: RecipeOrganizationCommand, firstSave: RecipeSaveCommand?) throws {
    try base.accept(command, firstSave: firstSave)
  }
  func prepareHistoryMove(_ recipeID: Recipe.ID, to folderID: Folder.ID?, in scope: RecipeOrganizationHistoryScope)
    throws -> RecipeOrganizationHistoryChange? { try base.prepareHistoryMove(recipeID, to: folderID, in: scope) }
  func prepareHistoryDelivery(_ change: RecipeOrganizationHistoryChange, memberID: UUID, token: UndoKit.HistoryToken,
                              in scope: RecipeOrganizationHistoryScope) throws -> RecipeOrganizationHistoryDelivery {
    try base.prepareHistoryDelivery(change, memberID: memberID, token: token, in: scope)
  }
  func acceptHistory(_ delivery: RecipeOrganizationHistoryDelivery) throws -> RecipeOrganizationHistoryReceipt {
    deliveries.append(delivery)
    if failNextAcceptance { failNextAcceptance = false; throw LostReply() }
    if rejectNextScope { rejectNextScope = false; throw RecipeOrganizationHistoryError.invalidScope }
    if rejectNextAcceptance {
      rejectNextAcceptance = false
      throw RecipeOrganizationHistoryError.ineligible
    }
    let receipt = try base.acceptHistory(delivery)
    if loseNextReply { loseNextReply = false; throw LostReply() }
    return receipt
  }
  func recoverHistory(_ delivery: RecipeOrganizationHistoryDelivery) throws -> RecipeOrganizationHistoryReceipt {
    deliveries.append(delivery)
    return try base.recoverHistory(delivery)
  }
  func historyReceipt(for token: UndoKit.HistoryToken, in scope: RecipeOrganizationHistoryScope)
    throws -> RecipeOrganizationHistoryReceipt? {
    withholdReceipts ? nil : try base.historyReceipt(for: token, in: scope)
  }
  func historyIsEligible(in scope: RecipeOrganizationHistoryScope, generation: UUID) throws -> Bool {
    if failNextEligibilityRead { failNextEligibilityRead = false; throw LostReply() }
    return try base.historyIsEligible(in: scope, generation: generation)
  }
  private struct LostReply: Error {}
}

private struct FutureHistoryReceipt: OrganizationPayload {
  let version: Int
  let receipt: RecipeOrganizationHistoryReceipt
  var compactableRegister: String? { nil }
}
