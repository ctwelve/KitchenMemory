// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import UndoKit
import XCTest

@MainActor
final class SessionOutcomeHistoryBoundaryTests: XCTestCase {
  func testVersionSixPreservesNoneAndRejectsUnknownOrMalformedMeaningAndForgedPrior() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    let history = RecipeOrganizationHistory(repository: fixture.base.repository)
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    let change = try XCTUnwrap(fixture.base.repository.prepareHistoryOutcome(fixture.id,
      to: .coarse(.great), in: fixture.base.scope))
    let bytes = try JSONEncoder().encode(change)
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    XCTAssertEqual(object["version"] as? Int, 6)
    XCTAssertEqual(try decodeChange(object), change)
    var outcome = try XCTUnwrap(object["sessionOutcome"] as? [String: Any])
    outcome["before"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(SessionOutcome.coarse(.okay)))
    object["sessionOutcome"] = outcome
    let invalid = try fixture.base.repository.prepareHistoryDelivery(decodeChange(object), memberID: UUID(),
      token: HistoryToken(scope: try XCTUnwrap(history.session?.configuration?.scope),
        generation: UUID(), sequence: 1, command: UUID()), in: fixture.base.scope)
    XCTAssertThrowsError(try fixture.base.repository.acceptHistory(invalid))
    XCTAssertEqual(try fixture.repository.evidence(id: fixture.id)?.facts.count, 0)
    object["version"] = 99
    XCTAssertThrowsError(try decodeChange(object))
    object["version"] = 6
    object["sessionOutcome"] = "Unsupported assessment payload"
    XCTAssertThrowsError(try decodeChange(object))
    object.removeValue(forKey: "sessionOutcome")
    XCTAssertThrowsError(try decodeChange(object))
    assertOrganizationHistoryAccepted(try await history.outcome(fixture.id, to: .coarse(.great)))
    let clear = try XCTUnwrap(fixture.base.repository.prepareHistoryOutcome(fixture.id,
      to: nil, in: fixture.base.scope))
    XCTAssertEqual(try JSONDecoder().decode(RecipeOrganizationHistoryChange.self,
      from: JSONEncoder().encode(clear)), clear)
    await history.close()
  }

  func testConcurrentOutcomeValuesRequireOrdinaryRecoveryAndCannotEarnUndoHistory() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    let heads = CausalHeadsCodec.encode([fixture.id.rawValue])
    for change in [SessionOutcomeChange.set(.coarse(.great)), .clear] {
      let payload = try SessionFactPayloadCodec.encode(.sessionOutcome(change))
      try fixture.repository.append(.activity(SessionFactEvidence(id: .init(), sessionID: fixture.id,
        kitchenID: fixture.base.kitchenID, kind: SessionFact.Kind.sessionOutcome.rawValue,
        targetSnapshotElementID: nil, authoredAt: Date(), causalHeadsFormatVersion: 1, causalHeadsData: heads.data,
        payloadFormatVersion: payload.formatVersion, payloadData: payload.data, payloadDigest: payload.digest)))
    }
    XCTAssertFalse(try fixture.session().conflicts.isEmpty)
    XCTAssertThrowsError(try fixture.base.repository.prepareHistoryOutcome(fixture.id,
      to: nil, in: fixture.base.scope))
    XCTAssertThrowsError(try fixture.base.repository.prepareHistoryOutcome(fixture.id,
      to: .coarse(.okay), in: fixture.base.scope))
    XCTAssertEqual(try fixture.repository.evidence(id: fixture.id)?.facts.count, 2)
    _ = try fixture.sessions.perform(.setOutcome(.init(id: .init(), sessionID: fixture.id, authoredAt: Date()),
      .coarse(.okay)))
    XCTAssertTrue(try fixture.session().conflicts.isEmpty)
    XCTAssertEqual(try fixture.session().outcome, .coarse(.okay))
  }

  private func decodeChange(_ object: [String: Any]) throws -> RecipeOrganizationHistoryChange {
    try JSONDecoder().decode(RecipeOrganizationHistoryChange.self,
      from: JSONSerialization.data(withJSONObject: object))
  }
}
