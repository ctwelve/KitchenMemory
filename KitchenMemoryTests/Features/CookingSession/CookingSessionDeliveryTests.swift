// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
@testable import KitchenMemory
import XCTest

@MainActor
final class CookingSessionDeliveryTests: XCTestCase {
  func testSubmissionStagesBeforeCallingLogicAndRetriesTheSameIdentity() throws {
    let sessionID = CookingSession.ID()
    let command = PendingCookingSessionCommand.submitEntry(factID: SessionFact.ID(), sessionID: sessionID,
      authoredAt: Date(), text: "Exact text 🍋", target: nil)
    let store = VolatileCookingSessionPresentationStore()
    let service = DeliveryTestService(sessionID: sessionID)
    service.failures = [1]
    service.beforeAttempt = { XCTAssertEqual(store.pendingCommands, [command]) }
    let delivery = CookingSessionDelivery(service: service, store: store)
    let first = delivery.submit { command }
    XCTAssertFalse(first.wasAccepted)
    XCTAssertEqual(delivery.pendingCommands, [command])
    XCTAssertEqual(store.pendingCommands, [command])
    let relaunched = CookingSessionDelivery(service: service, store: store)
    let events = relaunched.retry()
    XCTAssertEqual(events.count, 1)
    guard case .resolved(let retried, .accepted) = events.first else {
      XCTFail("Retry must report domain acceptance")
      return
    }
    XCTAssertEqual(retried, command)
    XCTAssertTrue(relaunched.pendingCommands.isEmpty)
    XCTAssertTrue(store.pendingCommands.isEmpty)
    XCTAssertEqual(service.attempts.count, 2)
  }

  func testIndependentActivityKeepsOrderAtEveryFailurePositionAndBlocksOrdinaryPreparation() throws {
    let sessionID = CookingSession.ID()
    let store = VolatileCookingSessionPresentationStore()
    let service = DeliveryTestService(sessionID: sessionID)
    let delivery = CookingSessionDelivery(service: service, store: store)
    service.failures = [1, 2, 3, 4]
    let commands = (0..<3).map { _ in
      PendingCookingSessionCommand.progress(factID: SessionFact.ID(), sessionID: sessionID, authoredAt: Date(),
        progress: SessionProgress(target: .ingredient(SessionIngredient.ID()), state: .ingredient(.accounted)))
    }
    for command in commands { XCTAssertFalse(delivery.submitIndependent(command).wasAccepted) }
    XCTAssertEqual(delivery.pendingCommands, commands)
    var prepared = false
    XCTAssertFalse(delivery.submit { prepared = true; return commands[0] }.wasAccepted)
    XCTAssertFalse(prepared)
    for remaining in [2, 1] {
      service.failures = [service.attempts.count + 2]
      _ = delivery.retry()
      XCTAssertEqual(delivery.pendingCommands, Array(commands.suffix(remaining)))
      XCTAssertEqual(store.pendingCommands, delivery.pendingCommands)
    }
    service.failures = []
    _ = delivery.retry()
    XCTAssertTrue(delivery.pendingCommands.isEmpty)
    XCTAssertEqual(service.attempts.compactMap { intention -> SessionFact.ID? in
      guard case .progress(let fact, _) = intention else { return nil }
      return fact.id
    }.suffix(4), commands.compactMap { command -> SessionFact.ID? in
      guard case .progress(let factID, _, _, _) = command else { return nil }
      return factID
    }.flatMap { [$0, $0] }.suffix(4))
  }

  func testAcceptedEntryPersistsDraftEffectBeforeRetirementAndReplayDoesNotResurrectText() {
    let sessionID = CookingSession.ID()
    let store = RecordingEntryStore()
    store.entryDrafts = [.init(sessionID: sessionID, text: "Exact text", target: nil)]
    let command = PendingCookingSessionCommand.submitEntry(factID: SessionFact.ID(), sessionID: sessionID,
      authoredAt: Date(), text: "Exact text", target: nil)
    let service = DeliveryTestService(sessionID: sessionID)
    let delivery = CookingSessionDelivery(service: service, store: store)
    store.events = []
    XCTAssertTrue(delivery.submit { command }.wasAccepted)
    XCTAssertEqual(store.events, [.pending(1), .draftSession(nil), .pending(0)])
    XCTAssertTrue(store.entryDrafts.isEmpty)
    // Simulate interruption after the draft write but before retirement.
    store.pendingCommands = [command]
    let replay = CookingSessionDelivery(service: service, store: store)
    _ = replay.retry()
    XCTAssertTrue(store.pendingCommands.isEmpty)
    XCTAssertTrue(store.entryDrafts.isEmpty)
  }

  func testContinuationMovesExactDraftAndMappedTargetBeforeRetirement() {
    let sourceID = CookingSession.ID(), destinationID = CookingSession.ID()
    let sourceTarget = SessionProgressTarget.instruction(SessionInstruction.ID())
    let destinationTarget = SessionProgressTarget.instruction(SessionInstruction.ID())
    let store = RecordingEntryStore()
    store.entryDrafts = [.init(sessionID: sourceID, text: "  Keep this 🍋  ", target: sourceTarget)]
    let command = PendingCookingSessionCommand.continueSession(sessionID: destinationID,
      sourceSessionID: sourceID, startedAt: Date())
    let service = DeliveryTestService(sessionID: destinationID)
    service.result = .accepted(CookingSessionProjection(id: destinationID,
      snapshot: ExecutionSnapshot(title: "Continued", continuationBaseline: .init(
        targetMappings: [.init(target: destinationTarget, sourceTarget: sourceTarget)]))))
    let delivery = CookingSessionDelivery(service: service, store: store)
    store.events = []
    XCTAssertTrue(delivery.submit { command }.wasAccepted)
    XCTAssertEqual(store.events, [.pending(1), .draftSession(destinationID), .pending(0)])
    XCTAssertEqual(delivery.entryDrafts, [.init(sessionID: destinationID, text: "  Keep this 🍋  ",
      target: destinationTarget),
    ])
    store.pendingCommands = [command]
    let replay = CookingSessionDelivery(service: service, store: store)
    _ = replay.retry()
    XCTAssertEqual(replay.entryDrafts, delivery.entryDrafts)
  }

  func testLegacyDefaultsCommandSurvivesFailureAndResetCannotResurrectLocalState() throws {
    let defaults = try makeTestUserDefaults(suiteNamePrefix: "KitchenMemory.Delivery").defaults
    let sessionID = CookingSession.ID()
    let command = PendingCookingSessionCommand.stop(factID: SessionFact.ID(), sessionID: sessionID,
      authoredAt: Date())
    defaults.set(try PropertyListEncoder().encode(command),
      forKey: DefaultsCookingSessionPresentationStore.pendingCommandKey)
    let store = DefaultsCookingSessionPresentationStore(defaults: defaults)
    store.entryDrafts = [.init(sessionID: sessionID, text: "Keep until reset", target: nil)]
    let service = DeliveryTestService(sessionID: sessionID)
    service.failures = [1, 2]
    let delivery = CookingSessionDelivery(service: service, store: store)
    _ = delivery.retry()
    XCTAssertEqual(delivery.pendingCommands, [command])
    let reopened = CookingSessionDelivery(service: service,
      store: DefaultsCookingSessionPresentationStore(defaults: defaults))
    XCTAssertEqual(reopened.pendingCommands, [command])
    _ = reopened.retry()
    reopened.reset()
    XCTAssertTrue(reopened.retry().isEmpty)
    XCTAssertTrue(reopened.entryDrafts.isEmpty)
    XCTAssertTrue(store.pendingCommands.isEmpty)
    XCTAssertTrue(store.entryDrafts.isEmpty)
    let newDraft = CookingSessionEntryDraft(sessionID: CookingSession.ID(), text: "After reset", target: nil)
    reopened.replaceDraft(newDraft)
    XCTAssertEqual(store.entryDrafts, [newDraft])
  }
}

@MainActor
final class DeliveryTestService: CookingSessionServing {
  let sessionID: CookingSession.ID
  var failures: Set<Int> = []
  var attempts: [CookingSessionIntention] = []
  var beforeAttempt: () -> Void = {}
  var result: CookingSessionCommandResult
  init(sessionID: CookingSession.ID) {
    self.sessionID = sessionID
    result = .accepted(CookingSessionProjection(id: sessionID, snapshot: ExecutionSnapshot(title: "Soup")))
  }
  func sessions() throws -> [SessionProjectionResult] { [] }
  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult { result }
  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    beforeAttempt()
    attempts.append(intention)
    if failures.contains(attempts.count) { throw CookingSessionLogicError.sessionWriteFailed }
    return result
  }
}
