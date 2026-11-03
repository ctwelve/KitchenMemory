// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import UndoKit
import XCTest

@MainActor
final class SessionScaleHistoryBoundaryTests: XCTestCase {
  func testLegacySessionWithoutPriorScaleCannotEarnScaleHistory() throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let repository = SwiftDataCookingSessionRepository(modelContainer: fixture.container)
    let recipe = try XCTUnwrap(fixture.recipes.recipe(id: fixture.recipeID))
    let snapshot = try ExecutionSnapshotCodec.encode(ExecutionSnapshot(title: "Legacy cook"))
    let id = CookingSession.ID()
    try repository.append(.start(CookingSessionRootEvidence(id: id, kitchenID: fixture.kitchenID,
      recipeID: fixture.recipeID, recipeRevisionID: recipe.revision.id, startedAt: Date(),
      snapshotFormatVersion: snapshot.formatVersion, snapshotData: snapshot.data, snapshotDigest: snapshot.digest)))
    XCTAssertThrowsError(try fixture.repository.prepareHistoryScale(id,
      to: SessionWorkingScale(exactScale: RationalQuantity(numerator: 2)), in: fixture.scope))
    XCTAssertEqual(try repository.evidence(id: id)?.facts.count, 0)
  }

  func testInvalidScaleTargetsAreRefusedWithoutAppendingFacts() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    let history = RecipeOrganizationHistory(repository: fixture.base.repository)
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    let invalid = SessionWorkingScale(exactScale: RationalQuantity(numerator: 2), quantities: [
      SessionIngredientQuantity(ingredientID: .init(),
        quantity: QuantityExpression(kind: .exact, lowerBound: RationalQuantity(numerator: 2))),
    ])
    let result = try await history.scale(fixture.id, to: invalid)
    XCTAssertEqual(result, .rejected)
    XCTAssertEqual(try fixture.repository.evidence(id: fixture.id)?.facts.count, 0)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canUndo)
    await history.close()
  }

  func testVersionFiveRoundtripsAndMalformedPriorOrProgressTargetsCannotBeAccepted() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    let history = RecipeOrganizationHistory(repository: fixture.base.repository)
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    let identity = try XCTUnwrap(history.session?.configuration?.scope)
    let change = try XCTUnwrap(fixture.base.repository.prepareHistoryScale(fixture.id,
      to: SessionWorkingScale(exactScale: RationalQuantity(numerator: 2)), in: fixture.base.scope))
    let bytes = try JSONEncoder().encode(change)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    XCTAssertEqual(object["version"] as? Int, 5)
    XCTAssertEqual(try JSONDecoder().decode(RecipeOrganizationHistoryChange.self, from: bytes), change)
    var scale = try XCTUnwrap(object["sessionScale"] as? [String: Any])
    scale["before"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(
      SessionWorkingScale(exactScale: RationalQuantity(numerator: 9))))
    object["sessionScale"] = scale
    let wrongBefore = try decodeChange(object)
    let frozen = try fixture.base.repository.prepareHistoryDelivery(wrongBefore, memberID: UUID(),
      token: HistoryToken(scope: identity, generation: UUID(), sequence: 1, command: UUID()), in: fixture.base.scope)
    XCTAssertThrowsError(try fixture.base.repository.acceptHistory(frozen))
    scale.removeValue(forKey: "before")
    object["sessionScale"] = scale
    XCTAssertThrowsError(try decodeChange(object))
    try assertMalformedProgressRefused(fixture: fixture, identity: identity)
    await history.close()
  }

  func testMissingFrozenFactAndForgedPriorProgressAreRefusedBeforeAcceptance() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    let history = RecipeOrganizationHistory(repository: fixture.base.repository)
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    let identity = try XCTUnwrap(history.session?.configuration?.scope)
    let scale = try XCTUnwrap(fixture.base.repository.prepareHistoryScale(fixture.id,
      to: SessionWorkingScale(exactScale: RationalQuantity(numerator: 2)), in: fixture.base.scope))
    let frozen = try fixture.base.repository.prepareHistoryDelivery(scale, memberID: UUID(),
      token: HistoryToken(scope: identity, generation: UUID(), sequence: 1, command: UUID()), in: fixture.base.scope)
    var delivery = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(frozen)) as? [String: Any])
    delivery.removeValue(forKey: "sessionFact")
    let missingFact = try JSONDecoder().decode(RecipeOrganizationHistoryDelivery.self,
      from: JSONSerialization.data(withJSONObject: delivery))
    XCTAssertThrowsError(try fixture.base.repository.acceptHistory(missingFact))
    let progress = try XCTUnwrap(fixture.base.repository.prepareHistoryProgress(fixture.id,
      to: fixture.completed, in: fixture.base.scope))
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(progress)) as? [String: Any])
    var payload = try XCTUnwrap(object["sessionProgress"] as? [String: Any])
    payload["before"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(
      SessionProgress(target: fixture.completed.target, state: .instruction(.skipped))))
    object["sessionProgress"] = payload
    let forged = try fixture.base.repository.prepareHistoryDelivery(decodeChange(object), memberID: UUID(),
      token: HistoryToken(scope: identity, generation: UUID(), sequence: 1, command: UUID()), in: fixture.base.scope)
    XCTAssertThrowsError(try fixture.base.repository.acceptHistory(forged))
    XCTAssertEqual(try fixture.repository.evidence(id: fixture.id)?.facts.count, 0)
    XCTAssertTrue(try fixture.session().progress.isEmpty)
    await history.close()
  }

  private func assertMalformedProgressRefused(fixture: ProgressHistoryFixture, identity: UUID) throws {
    let progress = try XCTUnwrap(fixture.base.repository.prepareHistoryProgress(fixture.id,
      to: fixture.completed, in: fixture.base.scope))
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(progress)) as? [String: Any])
    var payload = try XCTUnwrap(object["sessionProgress"] as? [String: Any])
    payload["after"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(
      SessionProgress(target: .ingredient(.init()), state: .ingredient(.accounted))))
    object["sessionProgress"] = payload
    let invalid = try fixture.base.repository.prepareHistoryDelivery(decodeChange(object), memberID: UUID(),
      token: HistoryToken(scope: identity, generation: UUID(), sequence: 1, command: UUID()), in: fixture.base.scope)
    XCTAssertThrowsError(try fixture.base.repository.acceptHistory(invalid))
    XCTAssertEqual(try fixture.repository.evidence(id: fixture.id)?.facts.count, 0)
  }

  private func decodeChange(_ object: [String: Any]) throws -> RecipeOrganizationHistoryChange {
    try JSONDecoder().decode(RecipeOrganizationHistoryChange.self,
      from: JSONSerialization.data(withJSONObject: object))
  }
}
