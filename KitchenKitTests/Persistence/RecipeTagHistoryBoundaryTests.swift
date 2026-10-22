// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenKit
import UndoKit
import XCTest

@MainActor
final class RecipeTagHistoryBoundaryTests: XCTestCase {
  func testMalformedFrozenTagDeliveriesRefuseWithoutChangingOrganization() throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let tag = try createTag(fixture)
    let change = try XCTUnwrap(fixture.repository.prepareHistoryTags([fixture.recipeID],
      tagID: tag, adding: true, in: fixture.scope))
    let wrongToken = HistoryToken(scope: UUID(), generation: UUID(), sequence: 1, command: UUID())
    XCTAssertThrowsError(try fixture.repository.prepareHistoryDelivery(change, memberID: UUID(), token: wrongToken,
      in: fixture.scope))
    let token = HistoryToken(scope: fixture.scope.identity, generation: UUID(), sequence: 1, command: UUID())
    let delivery = try fixture.repository.prepareHistoryDelivery(change, memberID: UUID(), token: token,
      in: fixture.scope)
    // A decoded, malformed frozen command must be refused at the public acceptance boundary.
    let wrongCommand = try altered(delivery) { object in
      var command = try XCTUnwrap(object["command"] as? [String: Any])
      command["id"] = UUID().uuidString
      object["command"] = command
    }
    let before = try fixture.repository.load(in: fixture.kitchenID)
    XCTAssertThrowsError(try fixture.repository.acceptHistory(wrongCommand))
    let wrongWitness = try altered(delivery) { $0["beforeWitness"] = Data("stale".utf8).base64EncodedString() }
    XCTAssertThrowsError(try fixture.repository.acceptHistory(wrongWitness))
    XCTAssertEqual(try fixture.repository.load(in: fixture.kitchenID), before)
    XCTAssertNil(try fixture.repository.historyReceipt(for: token, in: fixture.scope))

    try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).classify(
      [fixture.recipeID], tagID: tag, adding: true))
    let observedRemoval = try XCTUnwrap(fixture.repository.prepareHistoryTags([fixture.recipeID],
      tagID: tag, adding: false, in: fixture.scope))
    let unknownRemoval = try altered(observedRemoval) { object in
      var intent = try XCTUnwrap(object["tagChange"] as? [String: Any])
      var members = try XCTUnwrap(intent["members"] as? [[String: Any]])
      members[0]["logicalDots"] = [UUID().uuidString]
      intent["members"] = members
      object["tagChange"] = intent
    }
    let removeToken = HistoryToken(scope: fixture.scope.identity, generation: UUID(), sequence: 1, command: UUID())
    let frozen = try fixture.repository.prepareHistoryDelivery(unknownRemoval, memberID: UUID(), token: removeToken,
      in: fixture.scope)
    let assigned = try fixture.repository.load(in: fixture.kitchenID)
    XCTAssertThrowsError(try fixture.repository.acceptHistory(frozen))
    XCTAssertEqual(try fixture.repository.load(in: fixture.kitchenID), assigned)
    XCTAssertNil(try fixture.repository.historyReceipt(for: removeToken, in: fixture.scope))
  }

  func testPriorRecipeDispositionAndUnrelatedTagMergeRemainEligibleBaseline() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let tag = try createTag(fixture)
    for _ in 0..<2 {
      let deletion = RecipeDeleteCommand(kitchenID: fixture.kitchenID, recipeID: fixture.recipeID)
      try fixture.recipes.delete(deletion)
      try fixture.recipes.restore(RecipeRestoreCommand(kitchenID: fixture.kitchenID, recipeID: fixture.recipeID,
        observedDeletionIDs: [deletion.id]))
    }
    let first = Tag.ID(), second = Tag.ID()
    for (id, name) in [(first, "First"), (second, "Second")] {
      try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).prepare(
        tag: .create(id: id, name: name)))
    }
    try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).prepare(
      tag: .merge(ids: [first, second], survivorID: first, name: "Together")))
    let history = RecipeOrganizationHistory(repository: fixture.repository)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    assertOrganizationHistoryAccepted(try await history.classify([fixture.recipeID], tagID: tag, adding: true))
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertFalse(try fixture.repository.load(in: fixture.kitchenID).tags.tagIDs(for: fixture.recipeID).contains(tag))
    assertOrganizationHistoryAccepted(await history.redo())
    XCTAssertTrue(try fixture.repository.load(in: fixture.kitchenID).tags.tagIDs(for: fixture.recipeID).contains(tag))
    await history.close()
  }

  func testRejectedTagInverseRecoversExactCompensationWithoutRedoAfterReopen() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let tag = try createTag(fixture)
    let boundary = ControlledHistoryRepository(fixture.repository)
    let history = RecipeOrganizationHistory(repository: boundary)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    assertOrganizationHistoryAccepted(try await history.classify([fixture.recipeID], tagID: tag, adding: true))
    boundary.rejectNextAcceptance = true
    let rejected = await history.undo()
    XCTAssertEqual(rejected, .rejected)
    let frozen = try XCTUnwrap(boundary.deliveries.last)
    XCTAssertTrue(history.hasPendingCompensation)
    await history.close()
    let reopened = RecipeOrganizationHistory(repository: boundary)
    try await reopened.open(scope: fixture.scope, historyURL: fixture.historyURL)
    _ = try await reopened.retryPending()
    XCTAssertEqual(boundary.deliveries.last, frozen)
    XCTAssertFalse(try fixture.repository.load(in: fixture.kitchenID).tags.tagIDs(for: fixture.recipeID).contains(tag))
    XCTAssertFalse(reopened.hasPendingCompensation)
    XCTAssertFalse(try XCTUnwrap(reopened.session).status.canUndo)
    XCTAssertFalse(try XCTUnwrap(reopened.session).status.canRedo)
    await reopened.close()
  }

  private func createTag(_ fixture: HistoryFixture) throws -> Tag.ID {
    let tag = Tag.ID()
    try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).prepare(
      tag: .create(id: tag, name: "Dinner")))
    return tag
  }

  private func altered<Value: Codable>(_ value: Value, update: (inout [String: Any]) throws -> Void) throws -> Value {
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    try update(&object)
    return try JSONDecoder().decode(Value.self, from: JSONSerialization.data(withJSONObject: object))
  }
}
