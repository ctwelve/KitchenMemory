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
    store.pendingCommands = [
      .stop(
        factID: factID,
        sessionID: sessionID,
        authoredAt: authoredAt
      ),
    ]
    let reopened = DefaultsCookingSessionPresentationStore(defaults: defaults)

    XCTAssertEqual(reopened.currentSessionID, sessionID)
    XCTAssertEqual(
      reopened.pendingCommands,
      [.stop(factID: factID, sessionID: sessionID, authoredAt: authoredAt)]
    )
  }

  func testClearingPresentationStateRemovesDurableValues() throws {
    let suiteName = "CookingSessionPresentationStoreTests-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = DefaultsCookingSessionPresentationStore(defaults: defaults)
    store.currentSessionID = CookingSession.ID()
    store.pendingCommands = [
      .finish(
        closureID: SessionClosure.ID(),
        sessionID: CookingSession.ID(),
        finishedAt: Date(timeIntervalSince1970: 1_800_000_100)
      ),
    ]

    store.currentSessionID = nil
    store.pendingCommands = []
    let reopened = DefaultsCookingSessionPresentationStore(defaults: defaults)

    XCTAssertNil(reopened.currentSessionID)
    XCTAssertTrue(reopened.pendingCommands.isEmpty)
  }

  func testOrderedOutboxSurvivesStoreRecreation() throws {
    let suiteName = "CookingSessionPresentationStoreTests-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let sessionID = CookingSession.ID()
    let first = PendingCookingSessionCommand.progress(
      factID: SessionFact.ID(),
      sessionID: sessionID,
      authoredAt: Date(timeIntervalSince1970: 1_800_000_200),
      progress: SessionProgress(
        target: .ingredient(SessionIngredient.ID()),
        state: .ingredient(.accounted)
      )
    )
    let second = PendingCookingSessionCommand.progress(
      factID: SessionFact.ID(),
      sessionID: sessionID,
      authoredAt: Date(timeIntervalSince1970: 1_800_000_201),
      progress: SessionProgress(
        target: .instruction(SessionInstruction.ID()),
        state: .instruction(.completed)
      )
    )
    DefaultsCookingSessionPresentationStore(defaults: defaults).pendingCommands = [first, second]

    XCTAssertEqual(
      DefaultsCookingSessionPresentationStore(defaults: defaults).pendingCommands,
      [first, second]
    )
  }

  func testRecoveryCommandsSurviveStoreRecreationWithoutLosingObservedFrontiers() throws {
    let suiteName = "CookingSessionPresentationStoreTests-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let sessionID = CookingSession.ID()
    let deletionIDs = [SessionDeletion.ID(), SessionDeletion.ID()]
    let closureIDs = [SessionClosure.ID(), SessionClosure.ID()]
    let commands = [
      PendingCookingSessionCommand.delete(
        deletionID: SessionDeletion.ID(),
        sessionID: sessionID,
        deletedAt: Date(timeIntervalSince1970: 1_800_000_250)
      ),
      .restore(
        commandID: RestoreCookingSessionIntention.ID(),
        sessionID: sessionID,
        restoredAt: Date(timeIntervalSince1970: 1_800_000_251),
        observedDeletionIDs: deletionIDs
      ),
      .resolveClosure(
        factID: SessionFact.ID(),
        sessionID: sessionID,
        authoredAt: Date(timeIntervalSince1970: 1_800_000_252),
        selectedClosureID: closureIDs[1],
        observedClosureIDs: closureIDs
      ),
    ]

    DefaultsCookingSessionPresentationStore(defaults: defaults).pendingCommands = commands

    XCTAssertEqual(
      DefaultsCookingSessionPresentationStore(defaults: defaults).pendingCommands,
      commands
    )
  }

  func testSlice14SingleCommandDecodesAsOneItemOutbox() throws {
    let suiteName = "CookingSessionPresentationStoreTests-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let legacy = PendingCookingSessionCommand.stop(
      factID: SessionFact.ID(),
      sessionID: CookingSession.ID(),
      authoredAt: Date(timeIntervalSince1970: 1_800_000_300)
    )
    defaults.set(
      try PropertyListEncoder().encode(legacy),
      forKey: DefaultsCookingSessionPresentationStore.pendingCommandKey
    )

    XCTAssertEqual(
      DefaultsCookingSessionPresentationStore(defaults: defaults).pendingCommands,
      [legacy]
    )
  }

  func testEntryDraftSurvivesStoreRecreationWithoutEnteringTheCommandOutbox() throws {
    let suiteName = "CookingSessionPresentationStoreTests-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let sessionID = CookingSession.ID()
    let target = SessionProgressTarget.instruction(SessionInstruction.ID())
    let draft = CookingSessionEntryDraft(
      sessionID: sessionID,
      text: "  Needs more lime 🍋  ",
      target: target
    )
    let store = DefaultsCookingSessionPresentationStore(defaults: defaults)

    store.entryDrafts = [draft]
    let reopened = DefaultsCookingSessionPresentationStore(defaults: defaults)

    XCTAssertEqual(reopened.entryDrafts, [draft])
    XCTAssertTrue(reopened.pendingCommands.isEmpty)
  }

  func testDeviceLocalSessionVisitSurvivesStoreRecreation() throws {
    let suiteName = "CookingSessionPresentationStoreTests-\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let visit = CookingSessionVisit(
      sessionID: CookingSession.ID(),
      lastVisitedAt: Date(timeIntervalSince1970: 1_800_000_400),
      dismissedStaleNudge: true
    )

    DefaultsCookingSessionPresentationStore(defaults: defaults).sessionVisits = [visit]

    XCTAssertEqual(
      DefaultsCookingSessionPresentationStore(defaults: defaults).sessionVisits,
      [visit]
    )
  }
}
