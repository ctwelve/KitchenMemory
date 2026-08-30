// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import KitchenKit
import XCTest

@MainActor
final class CookingSessionEntryPresentationTests: XCTestCase {
  func testEntryDraftSurvivesStopAndPresentationRelaunchWithoutBecomingEvidence() throws {
    let store = VolatileCookingSessionPresentationStore()
    let preparedApp = try AppRuntime.testing(.init(
      library: .installed,
      sessionPresentationStore: store
    ))
    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(preparedApp.libraryModel.recipes.first)
    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))
    let target = try XCTUnwrap(
      preparedApp.sessionModel.currentSession?.snapshot.instructionSections.first?.steps.first?.id
    )

    preparedApp.sessionModel.updateCurrentEntryDraft(
      text: "  Needs more lime 🍋  ",
      target: .instruction(target)
    )
    XCTAssertTrue(preparedApp.sessionModel.stopCurrentSession())
    let relaunched = CookingSessionPresentationModel(
      sessions: preparedApp.cookingSessions,
      store: store
    )
    relaunched.loadIfNeeded()

    XCTAssertEqual(relaunched.currentEntryDraft?.text, "  Needs more lime 🍋  ")
    XCTAssertEqual(relaunched.currentEntryDraft?.target, .instruction(target))
    XCTAssertEqual(relaunched.currentSession?.entries.isEmpty, true)
    XCTAssertTrue(store.pendingCommands.isEmpty)
  }

  func testSubmittingExactUnicodeEntryThenRevisingRetargetingAndWithdrawingIsCausal() throws {
    let preparedApp = try AppRuntime.testing()
    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(preparedApp.libraryModel.recipes.first)
    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))
    let ingredient = try XCTUnwrap(
      preparedApp.sessionModel.currentSession?.snapshot.ingredientSections.first?.ingredients.first?.id
    )
    let instruction = try XCTUnwrap(
      preparedApp.sessionModel.currentSession?.snapshot.instructionSections.first?.steps.first?.id
    )
    let exactText = "  Jalapeño + lime 🍋\nsecond line  "

    preparedApp.sessionModel.updateCurrentEntryDraft(
      text: exactText,
      target: .ingredient(ingredient)
    )
    XCTAssertTrue(preparedApp.sessionModel.submitCurrentEntryDraft())
    let entry = try XCTUnwrap(preparedApp.sessionModel.currentSession?.entries.first)
    XCTAssertEqual(entry.text, exactText)
    XCTAssertEqual(entry.target, .ingredient(ingredient))
    XCTAssertNil(preparedApp.sessionModel.currentEntryDraft)

    XCTAssertTrue(preparedApp.sessionModel.reviseEntry(
      entry.id,
      text: "  revised ✨  ",
      target: .ingredient(ingredient)
    ))
    XCTAssertEqual(preparedApp.sessionModel.currentSession?.entries.first?.text, "  revised ✨  ")
    XCTAssertTrue(preparedApp.sessionModel.retargetEntry(entry.id, to: .instruction(instruction)))
    XCTAssertEqual(
      preparedApp.sessionModel.currentSession?.entries.first?.target,
      .instruction(instruction)
    )
    XCTAssertTrue(preparedApp.sessionModel.withdrawEntry(entry.id))
    XCTAssertEqual(preparedApp.sessionModel.currentSession?.entries.isEmpty, true)
  }

  func testEmptyEntryIsRejectedWithoutLosingDraftAndOutcomeHasDistinctLifecycle() throws {
    let preparedApp = try AppRuntime.testing()
    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(preparedApp.libraryModel.recipes.first)
    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))

    preparedApp.sessionModel.updateCurrentEntryDraft(text: " \n ", target: nil)
    XCTAssertFalse(preparedApp.sessionModel.submitCurrentEntryDraft())
    XCTAssertEqual(preparedApp.sessionModel.currentEntryDraft?.text, " \n ")
    XCTAssertEqual(preparedApp.sessionModel.currentSession?.entries.isEmpty, true)

    XCTAssertTrue(preparedApp.sessionModel.setOutcome(.coarse(.great)))
    XCTAssertEqual(preparedApp.sessionModel.currentSession?.outcome, .coarse(.great))
    XCTAssertTrue(preparedApp.sessionModel.clearOutcome())
    XCTAssertNil(preparedApp.sessionModel.currentSession?.outcome)
  }

  func testMeaningfulDraftRequiresAnExplicitFinishDecision() throws {
    let preparedApp = try AppRuntime.testing()
    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(preparedApp.libraryModel.recipes.first)
    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))
    preparedApp.sessionModel.updateCurrentEntryDraft(text: "Keep this thought", target: nil)

    XCTAssertFalse(preparedApp.sessionModel.finishCurrentSession())
    XCTAssertEqual(preparedApp.sessionModel.issue, .attention(.meaningfulDraft))
    XCTAssertEqual(preparedApp.sessionModel.currentEntryDraft?.text, "Keep this thought")
    XCTAssertNotNil(preparedApp.sessionModel.currentSession)

    XCTAssertTrue(preparedApp.sessionModel.finishDiscardingCurrentEntryDraft())
    XCTAssertNil(preparedApp.sessionModel.currentEntryDraft)
    XCTAssertNil(preparedApp.sessionModel.currentSession)
  }

  func testRemoteFinishSurfacesDraftAndContinuationMovesItWithMappedTarget() throws {
    let preparedApp = try AppRuntime.testing()
    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(preparedApp.libraryModel.recipes.first)
    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))
    let session = try XCTUnwrap(preparedApp.sessionModel.currentSession)
    let sourceTarget = try XCTUnwrap(
      session.snapshot.instructionSections.first?.steps.first?.id
    )
    preparedApp.sessionModel.updateCurrentEntryDraft(
      text: "Draft from the other device",
      target: .instruction(sourceTarget)
    )

    _ = try preparedApp.cookingSessions.perform(.finish(FinishCookingSessionIntention(
      closureID: SessionClosure.ID(),
      sessionID: session.id,
      finishedAt: Date(),
      hasMeaningfulDraft: false
    )))
    preparedApp.sessionModel.reloadAfterExternalStoreChange()

    XCTAssertNil(preparedApp.sessionModel.currentSession)
    XCTAssertEqual(
      preparedApp.sessionModel.detachedEntryDraft?.text,
      "Draft from the other device"
    )
    XCTAssertTrue(preparedApp.sessionModel.continueDetachedEntryDraft())
    let continued = try XCTUnwrap(preparedApp.sessionModel.currentSession)
    let expectedTarget = try XCTUnwrap(
      continued.snapshot.continuationBaseline?.targetMappings.first(where: {
        $0.sourceTarget == .instruction(sourceTarget)
      })?.target
    )
    XCTAssertEqual(preparedApp.sessionModel.currentEntryDraft?.sessionID, continued.id)
    XCTAssertEqual(preparedApp.sessionModel.currentEntryDraft?.target, expectedTarget)
    XCTAssertNil(preparedApp.sessionModel.detachedEntryDraft)
  }

  func testAmbiguousSubmissionRetriesOneIdentityAndKeepsDraftUntilAccepted() throws {
    let sessionID = CookingSession.ID()
    let active = CookingSessionProjection(
      id: sessionID,
      snapshot: ExecutionSnapshot(title: "Soup")
    )
    let service = AmbiguousEntryService(active: active)
    let store = VolatileCookingSessionPresentationStore()
    store.currentSessionID = sessionID
    let model = CookingSessionPresentationModel(sessions: service, store: store)
    model.loadIfNeeded()
    model.updateCurrentEntryDraft(text: "  exact retry 🍋  ", target: nil)

    XCTAssertFalse(model.submitCurrentEntryDraft())
    let pending = try XCTUnwrap(store.pendingCommands.first)
    XCTAssertEqual(model.currentEntryDraft?.text, "  exact retry 🍋  ")

    model.retryPendingCommands()

    XCTAssertEqual(service.attempts, [pending, pending])
    XCTAssertTrue(store.pendingCommands.isEmpty)
    XCTAssertNil(model.currentEntryDraft)
    XCTAssertEqual(model.currentSession?.entries.first?.text, "  exact retry 🍋  ")
  }
}

@MainActor
private final class AmbiguousEntryService: CookingSessionServing {
  let active: CookingSessionProjection
  var attempts: [PendingCookingSessionCommand] = []

  init(active: CookingSessionProjection) {
    self.active = active
  }

  func sessions() -> [SessionProjectionResult] {
    [.session(active)]
  }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    throw AmbiguousEntryError.unexpectedCommand
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    guard case let .submitEntry(fact, text, target) = intention else {
      throw AmbiguousEntryError.unexpectedCommand
    }
    let pending = PendingCookingSessionCommand.submitEntry(
      factID: fact.id,
      sessionID: fact.sessionID,
      authoredAt: fact.authoredAt,
      text: text,
      target: target
    )
    attempts.append(pending)
    guard attempts.count > 1 else { throw AmbiguousEntryError.interrupted }
    return .accepted(CookingSessionProjection(
      id: active.id,
      snapshot: active.snapshot,
      entries: [
        SessionEntry(
          id: .init(rawValue: fact.id.rawValue),
          target: target,
          text: text
        ),
      ]
    ))
  }
}

private enum AmbiguousEntryError: Error {
  case interrupted
  case unexpectedCommand
}
