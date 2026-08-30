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

extension CookingSessionEntryPresentationTests {
  func testAcceptedContinuationPersistsMovedDraftBeforeClearingCommand() throws {
    let sourceID = CookingSession.ID()
    let destinationID = CookingSession.ID()
    let service = ContinuationAcceptanceService(sourceID: sourceID)
    let store = RecordingEntryStore()
    store.entryDrafts = [
      CookingSessionEntryDraft(
        sessionID: sourceID,
        text: "Survive every interruption",
        target: nil
      ),
    ]
    store.pendingCommands = [
      .continueSession(
        sessionID: destinationID,
        sourceSessionID: sourceID,
        startedAt: Date()
      ),
    ]
    store.events.removeAll()
    let model = CookingSessionPresentationModel(sessions: service, store: store)
    model.loadIfNeeded()

    XCTAssertEqual(
      store.events,
      [
        .draftSession(destinationID),
        .pending(0),
      ]
    )
    XCTAssertEqual(model.currentEntryDraft?.text, "Survive every interruption")
  }

  func testRemoteFinishDefinitivelyRejectsSubmissionBeforeDraftContinuation() throws {
    let sessionID = CookingSession.ID()
    let service = RemoteFinishDuringSubmitService(sessionID: sessionID)
    let store = VolatileCookingSessionPresentationStore()
    store.currentSessionID = sessionID
    let model = CookingSessionPresentationModel(sessions: service, store: store)
    model.loadIfNeeded()
    model.updateCurrentEntryDraft(text: "Still only a draft", target: nil)

    XCTAssertFalse(model.submitCurrentEntryDraft())
    XCTAssertEqual(store.pendingCommands.count, 1)
    service.isRemotelyFinished = true
    model.reloadAfterExternalStoreChange()

    XCTAssertTrue(store.pendingCommands.isEmpty)
    XCTAssertEqual(model.detachedEntryDraft?.text, "Still only a draft")
    XCTAssertTrue(model.continueDetachedEntryDraft())
    XCTAssertEqual(model.currentEntryDraft?.text, "Still only a draft")
  }

  func testRemoteFinishAllowsDetachedDraftToBeExplicitlyDiscarded() throws {
    let sessionID = CookingSession.ID()
    let service = RemoteFinishDuringSubmitService(sessionID: sessionID)
    let store = VolatileCookingSessionPresentationStore()
    store.currentSessionID = sessionID
    let model = CookingSessionPresentationModel(sessions: service, store: store)
    model.loadIfNeeded()
    model.updateCurrentEntryDraft(text: "Discard only when asked", target: nil)
    XCTAssertFalse(model.submitCurrentEntryDraft())

    service.isRemotelyFinished = true
    model.reloadAfterExternalStoreChange()
    model.discardDetachedEntryDraft()

    XCTAssertTrue(store.pendingCommands.isEmpty)
    XCTAssertTrue(store.entryDrafts.isEmpty)
    XCTAssertNil(model.detachedEntryDraft)
  }

  func testEntryAndOutcomeConflictsCanBeResolvedWithCausalCommands() throws {
    let fixture = ConflictedEntryFixture()
    let service = ConflictResolutionService(session: fixture.projection)
    let store = VolatileCookingSessionPresentationStore()
    store.currentSessionID = fixture.sessionID
    let model = CookingSessionPresentationModel(sessions: service, store: store)
    model.loadIfNeeded()

    let targetPresentation = SessionEntryTargetPresentation(snapshot: fixture.snapshot)
    XCTAssertEqual(targetPresentation.label(for: .ingredient(fixture.ingredientID)), "1 lime")
    XCTAssertEqual(targetPresentation.label(for: .instruction(fixture.instructionID)), "Simmer")
    XCTAssertTrue(model.reviseEntry(
      fixture.entryID,
      text: "More lime",
      target: .instruction(fixture.instructionID)
    ))
    service.session = fixture.projection
    model.reloadAfterExternalStoreChange()
    XCTAssertTrue(model.clearOutcome())

    XCTAssertEqual(service.intentions.count, 2)
    guard case let .reviseEntry(_, revisedID, text, target) = service.intentions[0] else {
      XCTFail("Expected entry conflict resolution")
      return
    }
    XCTAssertEqual(revisedID, fixture.entryID)
    XCTAssertEqual(text, "More lime")
    XCTAssertEqual(target, .instruction(fixture.instructionID))
    guard case .clearOutcome = service.intentions[1] else {
      XCTFail("Expected outcome conflict resolution")
      return
    }
  }
}
