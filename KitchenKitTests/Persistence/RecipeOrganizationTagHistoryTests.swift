// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenKit
import UndoKit
import XCTest

@MainActor
final class RecipeOrganizationTagHistoryTests: XCTestCase {
  func testOlderAddUndoFollowsOnlyItsReplacementAfterRemoveUndo() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let tag = Tag.ID()
    try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).prepare(
      tag: .create(id: tag, name: "Dinner")))
    let history = RecipeOrganizationHistory(repository: fixture.repository)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    assertOrganizationHistoryAccepted(try await history.classify([fixture.recipeID], tagID: tag, adding: true))
    assertOrganizationHistoryAccepted(try await history.classify([fixture.recipeID], tagID: tag, adding: false))
    XCTAssertFalse(try fixture.repository.load(in: fixture.kitchenID).tags.tagIDs(for: fixture.recipeID).contains(tag))
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertTrue(try fixture.repository.load(in: fixture.kitchenID).tags.tagIDs(for: fixture.recipeID).contains(tag))
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertFalse(try fixture.repository.load(in: fixture.kitchenID).tags.tagIDs(for: fixture.recipeID).contains(tag))
    assertOrganizationHistoryAccepted(await history.redo())
    assertOrganizationHistoryAccepted(await history.redo())
    XCTAssertFalse(try fixture.repository.load(in: fixture.kitchenID).tags.tagIDs(for: fixture.recipeID).contains(tag))
    await history.close()
  }

  func testSelectionExcludesPreexistingMembershipAndSharesFolderTimeline() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let tag = try createTag(fixture)
    let extra = try RecipeEditor(repository: fixture.recipes).create(in: fixture.kitchenID,
      from: RecipeDraft(title: "Bread"))
    try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).classify(
      [fixture.recipeID], tagID: tag, adding: true))
    let history = RecipeOrganizationHistory(repository: fixture.repository)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    assertOrganizationHistoryAccepted(try await history.move([fixture.recipeID, extra.id], to: fixture.first))
    assertOrganizationHistoryAccepted(try await history.classify([fixture.recipeID, extra.id],
      tagID: tag, adding: true))
    let noOp = try await history.classify([fixture.recipeID, extra.id], tagID: tag, adding: true)
    XCTAssertEqual(noOp, .rejected)
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertTrue(try contains(fixture, recipeID: fixture.recipeID, tagID: tag))
    XCTAssertFalse(try contains(fixture, recipeID: extra.id, tagID: tag))
    XCTAssertEqual(try fixture.placement(), fixture.first)
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertNil(try fixture.placement())
    assertOrganizationHistoryAccepted(await history.redo())
    assertOrganizationHistoryAccepted(await history.redo())
    assertOrganizationHistoryAccepted(try await history.classify([fixture.recipeID, extra.id],
      tagID: tag, adding: false))
    XCTAssertFalse(try contains(fixture, recipeID: fixture.recipeID, tagID: tag))
    XCTAssertFalse(try contains(fixture, recipeID: extra.id, tagID: tag))
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertTrue(try contains(fixture, recipeID: fixture.recipeID, tagID: tag))
    XCTAssertTrue(try contains(fixture, recipeID: extra.id, tagID: tag))
    assertOrganizationHistoryAccepted(try await history.move([extra.id], to: fixture.second))
    XCTAssertFalse(try XCTUnwrap(history.session).status.canRedo, "A new Folder action replaces Tag Redo")
    await history.close()
  }

  func testEveryStaleSelectionMemberRefusesEntireTagDelivery() throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let tag = try createTag(fixture)
    let extra = try RecipeEditor(repository: fixture.recipes).create(in: fixture.kitchenID,
      from: RecipeDraft(title: "Bread"))
    let ids = [fixture.recipeID, extra.id]
    for (index, staleID) in ids.enumerated() {
      let change = try XCTUnwrap(fixture.repository.prepareHistoryTags(Set(ids), tagID: tag,
        adding: true, in: fixture.scope))
      let token = HistoryToken(scope: fixture.scope.identity, generation: UUID(),
        sequence: Int64(index + 1), command: UUID())
      let delivery = try fixture.repository.prepareHistoryDelivery(change, memberID: UUID(), token: token,
        in: fixture.scope)
      try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).classify(
        [staleID], tagID: tag, adding: true))
      XCTAssertThrowsError(try fixture.repository.acceptHistory(delivery))
      XCTAssertTrue(try contains(fixture, recipeID: staleID, tagID: tag))
      let untouched = try XCTUnwrap(ids.first { $0 != staleID })
      XCTAssertFalse(try contains(fixture, recipeID: untouched, tagID: tag))
      XCTAssertNil(try fixture.repository.historyReceipt(for: token, in: fixture.scope))
      try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).classify(
        [staleID], tagID: tag, adding: false))
    }
  }

  func testTagLostReplyReopensByExactReceiptAndRetryNeverDuplicates() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let tag = try createTag(fixture)
    let boundary = ControlledHistoryRepository(fixture.repository)
    let history = RecipeOrganizationHistory(repository: boundary)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    boundary.loseNextReply = true
    boundary.withholdReceipts = true
    let result = try await history.classify([fixture.recipeID], tagID: tag, adding: true)
    guard case .unresolved = result else {
      XCTFail("Accepted reply loss must suspend the Tag operation")
      return
    }
    let delivery = try XCTUnwrap(boundary.deliveries.last)
    let receipt = try XCTUnwrap(fixture.repository.historyReceipt(for: delivery.token.value, in: fixture.scope))
    XCTAssertTrue(try contains(fixture, recipeID: fixture.recipeID, tagID: tag))
    await history.close()
    boundary.withholdReceipts = false
    for _ in 0..<2 {
      let reopened = RecipeOrganizationHistory(repository: boundary)
      try await reopened.open(scope: fixture.scope, historyURL: fixture.historyURL)
      XCTAssertTrue(try XCTUnwrap(reopened.session).status.canUndo)
      XCTAssertEqual(try fixture.repository.acceptHistory(delivery), receipt)
      await reopened.close()
    }
    let reopened = RecipeOrganizationHistory(repository: boundary)
    try await reopened.open(scope: fixture.scope, historyURL: fixture.historyURL)
    assertOrganizationHistoryAccepted(await reopened.undo())
    XCTAssertFalse(try contains(fixture, recipeID: fixture.recipeID, tagID: tag),
      "One Undo removes the single accepted logical assignment after repeated recovery")
    try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).classify(
      [fixture.recipeID], tagID: tag, adding: true))
    XCTAssertEqual(try fixture.repository.acceptHistory(delivery), receipt,
      "Receipt-first retry remains exact after independent later evidence")
    XCTAssertTrue(try contains(fixture, recipeID: fixture.recipeID, tagID: tag))
    _ = await reopened.reconcile()
    XCTAssertFalse(try XCTUnwrap(reopened.session).status.canRedo)
    await reopened.close()
  }

  func testObservedRemoveRestoresEachDotWithFreshAssignmentsAndFrozenInverseRefusesLateEvidence() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let tag = try createTag(fixture)
    for _ in 0..<2 {
      try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).classify(
        [fixture.recipeID], tagID: tag, adding: true))
    }
    let boundary = ControlledHistoryRepository(fixture.repository)
    let history = RecipeOrganizationHistory(repository: boundary)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    assertOrganizationHistoryAccepted(try await history.classify([fixture.recipeID], tagID: tag, adding: false))
    let removal = try XCTUnwrap(boundary.deliveries.last)
    assertOrganizationHistoryAccepted(await history.undo())
    let restored = try XCTUnwrap(boundary.deliveries.last)
    XCTAssertEqual(restored.command.tags.count, 2, "Each removed logical assignment needs its own fresh replacement")
    XCTAssertEqual(Set(restored.command.tags.map(\.id)).count, 2)
    assertOrganizationHistoryAccepted(await history.redo())
    assertOrganizationHistoryAccepted(await history.undo())
    let restoredAgain = try XCTUnwrap(boundary.deliveries.last)
    XCTAssertTrue(Set(restored.command.tags.map(\.id)).isDisjoint(with: restoredAgain.command.tags.map(\.id)))
    let token = HistoryToken(scope: fixture.scope.identity, generation: restoredAgain.token.generation,
      sequence: restoredAgain.token.sequence + 1, command: UUID())
    let frozen = try fixture.repository.prepareHistoryDelivery(removal.change, memberID: UUID(), token: token,
      in: fixture.scope)
    try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).classify(
      [fixture.recipeID], tagID: tag, adding: true))
    XCTAssertThrowsError(try fixture.repository.acceptHistory(frozen))
    XCTAssertTrue(try contains(fixture, recipeID: fixture.recipeID, tagID: tag),
      "An independent later assignment survives the refused stale inverse")
    await history.close()
  }

  func testChangedTagOrRecipeEvidenceRefusesWholeCompensationAcrossReopen() async throws {
    for scenario in 0..<4 {
      let fixture = try HistoryFixture()
      defer { fixture.removeFiles() }
      let tag = try createTag(fixture)
      let extra = try RecipeEditor(repository: fixture.recipes).create(in: fixture.kitchenID,
        from: RecipeDraft(title: "Bread"))
      let history = RecipeOrganizationHistory(repository: fixture.repository)
      try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
      assertOrganizationHistoryAccepted(try await history.classify([fixture.recipeID, extra.id],
        tagID: tag, adding: true))
      switch scenario {
      case 0:
        try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).prepare(tag: .delete(id: tag)))
      case 1:
        let survivor = Tag.ID()
        try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).prepare(
          tag: .create(id: survivor, name: "Other")))
        try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).prepare(
          tag: .merge(ids: [tag, survivor], survivorID: survivor, name: "Together")))
      case 2:
        try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).prepare(
          tag: .rename(id: tag, name: "Renamed")))
      default:
        let deletion = RecipeDeleteCommand(kitchenID: fixture.kitchenID, recipeID: fixture.recipeID)
        try fixture.recipes.delete(deletion)
        try fixture.recipes.restore(RecipeRestoreCommand(kitchenID: fixture.kitchenID, recipeID: fixture.recipeID,
          observedDeletionIDs: [deletion.id]))
      }
      let before = try fixture.repository.load(in: fixture.kitchenID)
      let result = await history.undo()
      XCTAssertEqual(result, .rejected)
      XCTAssertEqual(try fixture.repository.load(in: fixture.kitchenID), before)
      XCTAssertFalse(try XCTUnwrap(history.session).status.canRedo)
      await history.close()
      let reopened = RecipeOrganizationHistory(repository: fixture.repository)
      try await reopened.open(scope: fixture.scope, historyURL: fixture.historyURL)
      XCTAssertFalse(try XCTUnwrap(reopened.session).status.canUndo)
      XCTAssertFalse(try XCTUnwrap(reopened.session).status.canRedo)
      await reopened.close()
    }
  }

  func testMissingTargetsAndUnsupportedTagShapeFailClosed() throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let tag = try createTag(fixture)
    XCTAssertThrowsError(try fixture.repository.prepareHistoryTags([fixture.recipeID, Recipe.ID()],
      tagID: tag, adding: true, in: fixture.scope))
    XCTAssertThrowsError(try fixture.repository.prepareHistoryTags([fixture.recipeID],
      tagID: Tag.ID(), adding: true, in: fixture.scope))
    let change = try XCTUnwrap(fixture.repository.prepareHistoryTags([fixture.recipeID],
      tagID: tag, adding: true, in: fixture.scope))
    let encoded = try JSONEncoder().encode(change)
    XCTAssertEqual(try JSONDecoder().decode(RecipeOrganizationHistoryChange.self, from: encoded), change)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    XCTAssertEqual(object["version"] as? Int, 3)
    XCTAssertNil(object["recipeID"], "Older Folder-only readers must refuse the new Tag shape")
    object["version"] = 4
    XCTAssertThrowsError(try JSONDecoder().decode(RecipeOrganizationHistoryChange.self,
      from: JSONSerialization.data(withJSONObject: object)))
    object["version"] = 3
    var tagObject = try XCTUnwrap(object["tagChange"] as? [String: Any])
    tagObject["members"] = []
    object["tagChange"] = tagObject
    XCTAssertThrowsError(try JSONDecoder().decode(RecipeOrganizationHistoryChange.self,
      from: JSONSerialization.data(withJSONObject: object)))
  }

  private func createTag(_ fixture: HistoryFixture) throws -> Tag.ID {
    let tag = Tag.ID()
    try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).prepare(
      tag: .create(id: tag, name: "Dinner")))
    return tag
  }

  private func contains(_ fixture: HistoryFixture, recipeID: Recipe.ID, tagID: Tag.ID) throws -> Bool {
    try fixture.repository.load(in: fixture.kitchenID).tags.tagIDs(for: recipeID).contains(tagID)
  }

}
