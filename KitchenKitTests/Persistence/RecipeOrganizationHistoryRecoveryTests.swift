// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenKit
import SwiftData
import UndoKit
import XCTest

extension RecipeOrganizationHistoryTests {
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
      guard case .unresolved = original else { XCTFail("Unknown reply must preserve preparation")
return }
      let frozen = try XCTUnwrap(boundary.deliveries.last)
      let unknown = await history.reconcile()
      guard case .unresolved = unknown else { XCTFail("Absent accepted receipt remains unknown")
return }
      XCTAssertFalse(history.canDiscardRejectedCompensation)
      do {
        try await history.discardRejectedCompensation()
        XCTFail("Ambiguous work cannot be discarded")
      } catch RecipeOrganizationHistoryError.ineligible {}
      boundary.withholdReceipts = false
      let retried = try await history.retryPending()
      assertOrganizationHistoryAccepted(try XCTUnwrap(retried))
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
    boundary.rejectNextAcceptance = true
    let refused = try await history.move([fixture.recipeID], to: fixture.first)
    XCTAssertEqual(refused, .rejected)
    XCTAssertNil(try fixture.placement())
    XCTAssertFalse(try XCTUnwrap(history.session).status.canUndo)
    assertOrganizationHistoryAccepted(try await history.move([fixture.recipeID], to: fixture.first))
    boundary.failNextEligibilityRead = true
    let failure = await history.reconcile()
    guard case .unresolved = failure else { XCTFail("Failed authority read must remain unresolved")
return }
    XCTAssertEqual(try fixture.placement(), fixture.first)
    XCTAssertNil(history.session, "Unproved eligibility must not remain actionable through native Undo")
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
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
    assertOrganizationHistoryAccepted(try await history.move([fixture.recipeID], to: fixture.first))
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
    guard case let .accepted(acceptance) = result else { XCTFail("Move must be accepted before compatibility setup")
return }
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
    XCTAssertNil(try fixture.placement(),
      "The guard rejects before either the assignment or acceptance receipt commits")
    boundary.withholdReceipts = false
    let retried = try await history.retryPending()
    assertOrganizationHistoryAccepted(try XCTUnwrap(retried))
    XCTAssertEqual(try fixture.placement(), fixture.first)
    await history.close()
  }

}
