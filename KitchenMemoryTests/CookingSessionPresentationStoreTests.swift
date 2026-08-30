// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import KitchenKit
import XCTest

@MainActor
final class CookingSessionPresentationStoreTests: XCTestCase {
  func testCurrentPointerAndPendingCommandSurviveStoreRecreation() throws {
    let suiteName = "CookingSessionPresentationStoreTests-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let sessionID = CookingSession.ID()
    let factID = SessionFact.ID()
    let authoredAt = Date(timeIntervalSince1970: 1_800_000_000)
    let store = DefaultsCookingSessionPresentationStore(defaults: defaults)

    store.currentSessionID = sessionID
    store.pendingCommand = .stop(
      factID: factID,
      sessionID: sessionID,
      authoredAt: authoredAt
    )
    let reopened = DefaultsCookingSessionPresentationStore(defaults: defaults)

    XCTAssertEqual(reopened.currentSessionID, sessionID)
    XCTAssertEqual(
      reopened.pendingCommand,
      .stop(factID: factID, sessionID: sessionID, authoredAt: authoredAt)
    )
  }

  func testClearingPresentationStateRemovesDurableValues() throws {
    let suiteName = "CookingSessionPresentationStoreTests-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = DefaultsCookingSessionPresentationStore(defaults: defaults)
    store.currentSessionID = CookingSession.ID()
    store.pendingCommand = .finish(
      closureID: SessionClosure.ID(),
      sessionID: CookingSession.ID(),
      finishedAt: Date(timeIntervalSince1970: 1_800_000_100)
    )

    store.currentSessionID = nil
    store.pendingCommand = nil
    let reopened = DefaultsCookingSessionPresentationStore(defaults: defaults)

    XCTAssertNil(reopened.currentSessionID)
    XCTAssertNil(reopened.pendingCommand)
  }
}
