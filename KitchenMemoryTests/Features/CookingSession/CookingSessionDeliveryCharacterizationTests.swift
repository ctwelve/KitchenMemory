// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
@testable import KitchenMemory
import XCTest

@MainActor
final class SessionDeliveryCharacterizationTests: XCTestCase {
  // Retry applies acceptance only to the exact submitted text and target.
  func testRetryPreservesNewerTextWhileEarlierSubmissionWasPending() throws {
    let (model, _) = try fixture()
    model.updateCurrentEntryDraft(text: "Submitted text", target: nil)
    XCTAssertFalse(model.submitCurrentEntryDraft())
    model.updateCurrentEntryDraft(text: "Newer text", target: nil)
    model.retryPendingCommands()
    XCTAssertEqual(model.currentSession?.entries.map(\.text), ["Submitted text"])
    XCTAssertEqual(model.currentEntryDraft?.text, "Newer text")
  }

  func testSubmitWhilePendingRetriesOriginalWithoutSubmittingAnotherVersion() throws {
    for text in ["Submitted text", "Newer text"] {
      let (model, service) = try fixture()
      model.updateCurrentEntryDraft(text: "Submitted text", target: nil)
      XCTAssertFalse(model.submitCurrentEntryDraft())
      model.updateCurrentEntryDraft(text: text, target: nil)
      XCTAssertTrue(model.submitCurrentEntryDraft())
      XCTAssertEqual(service.submissions.count, 2)
      XCTAssertEqual(service.submissions[0], service.submissions[1])
      XCTAssertEqual(model.currentSession?.entries.map(\.text), ["Submitted text"])
      if text == "Newer text" {
        XCTAssertEqual(model.currentEntryDraft?.text, text)
        XCTAssertTrue(model.submitCurrentEntryDraft())
        XCTAssertEqual(service.submissions.count, 3)
        XCTAssertNotEqual(service.submissions[1], service.submissions[2])
      } else {
        XCTAssertNil(model.currentEntryDraft)
      }
    }
  }

  func testPendingSubmissionPreventsDiscardAndCopyFinishWithoutLosingDraft() throws {
    let (model, service) = try fixture()
    model.updateCurrentEntryDraft(text: "Submitted text", target: nil)
    XCTAssertFalse(model.submitCurrentEntryDraft())
    XCTAssertFalse(model.finishDiscardingCurrentEntryDraft())
    var copied = false
    XCTAssertFalse(model.copyCurrentEntryDraftAndFinish(using: { _ in copied = true; return true }))
    XCTAssertFalse(copied)
    XCTAssertEqual(model.currentEntryDraft?.text, "Submitted text")
    XCTAssertEqual(service.submissions.count, 1)
  }

  func testComposerReopensMeaningfulDraftWithoutRetargetingAndRequiresActiveSession() throws {
    let (model, _) = try fixture()
    let first = try XCTUnwrap(model.currentSession)
    let originalTarget = SessionProgressTarget.instruction(try XCTUnwrap(first.snapshot.instructionSections.first?.steps.first?.id))
    model.openEntryComposer(target: originalTarget)
    model.updateCurrentEntryDraft(text: "  Keep this 🌮  ", target: originalTarget)
    model.isShowingEntryComposer = false
    model.openEntryComposer(target: nil)
    XCTAssertTrue(model.isShowingEntryComposer)
    XCTAssertEqual(model.currentEntryDraft?.text, "  Keep this 🌮  ")
    XCTAssertEqual(model.currentEntryDraft?.target, originalTarget)
    XCTAssertTrue(model.stopCurrentSession())
    model.isShowingEntryComposer = false
    model.openEntryComposer()
    XCTAssertFalse(model.isShowingEntryComposer)
    XCTAssertEqual(model.currentEntryDraft?.target, originalTarget)
  }

  func testResumeToEditOpensOnlyAfterAcceptanceAndNeverFinishes() throws {
    let (model, service) = try fixture()
    model.updateCurrentEntryDraft(text: "Stopped thought", target: nil)
    XCTAssertTrue(model.stopCurrentSession())
    let origin = UUID()
    service.blocksResume = true
    XCTAssertFalse(model.resumeToEditCurrentEntryDraft(origin: origin))
    XCTAssertFalse(model.isShowingEntryComposer)
    XCTAssertEqual(model.currentSession?.lifecycle, .stopped)
    let pending = try XCTUnwrap(model.pendingCommands.first)
    service.blocksResume = false
    model.retryPendingCommands()
    XCTAssertTrue(model.isShowingEntryComposer)
    XCTAssertEqual(model.entryComposerOrigin, origin)
    XCTAssertEqual(model.currentSession?.lifecycle, .active)
    XCTAssertEqual(model.currentEntryDraft?.text, "Stopped thought")
    XCTAssertTrue(model.pendingCommands.isEmpty)
    guard case let .resume(factID, _, _) = pending else { return XCTFail("Expected Resume") }
    XCTAssertEqual(service.resumeIDs, [factID, factID])
  }

  func testRetainedFinishSurvivesDismissalAndRetryWithSameIdentity() throws {
    let (model, service) = try fixture()
    service.blocksFinish = true
    XCTAssertFalse(model.finishCurrentSession())
    XCTAssertTrue(model.currentSessionHasPendingFinish)
    XCTAssertFalse(model.finishBlockedByEarlierWork)
    let pending = try XCTUnwrap(model.pendingCommands.first)
    model.dismissIssuePresentation()
    XCTAssertFalse(model.finishCurrentSession())
    XCTAssertEqual(model.pendingCommands, [pending])
    service.blocksFinish = false
    model.retryPendingCommands()
    XCTAssertTrue(model.pendingCommands.isEmpty)
    guard case let .finish(closureID, _, _) = pending else { return XCTFail("Expected Finish") }
    XCTAssertEqual(service.finishIDs, [closureID, closureID])
    XCTAssertNil(model.currentSession)
  }

  func testComposerBelongsToTheWindowThatRequestedIt() throws {
    let (model, _) = try fixture()
    let firstWindow = UUID(), secondWindow = UUID()
    model.openEntryComposer(origin: firstWindow)
    XCTAssertEqual(model.entryComposerOrigin, firstWindow)
    model.dismissEntryComposer(origin: secondWindow)
    XCTAssertTrue(model.isShowingEntryComposer)
    XCTAssertEqual(model.entryComposerOrigin, firstWindow)
    model.dismissEntryComposer(origin: firstWindow)
    XCTAssertFalse(model.isShowingEntryComposer)
    XCTAssertNil(model.entryComposerOrigin)
    model.openEntryComposer(origin: secondWindow)
    XCTAssertTrue(model.isShowingEntryComposer)
    XCTAssertEqual(model.entryComposerOrigin, secondWindow)
    XCTAssertTrue(model.select(nil))
    XCTAssertFalse(model.isShowingEntryComposer)
    XCTAssertNil(model.entryComposerOrigin)
  }

  func testRetryPreservesNewerTargetEvenWithIdenticalText() throws {
    let (model, _) = try fixture()
    let target = SessionProgressTarget.instruction(try XCTUnwrap(model.currentSession?.snapshot.instructionSections.first?.steps.first?.id))
    model.updateCurrentEntryDraft(text: "Same text", target: nil)
    XCTAssertFalse(model.submitCurrentEntryDraft())
    model.updateCurrentEntryDraft(text: "Same text", target: target)
    model.retryPendingCommands()
    XCTAssertEqual(model.currentEntryDraft?.target, target)
    XCTAssertEqual(model.currentEntryDraft?.text, "Same text")
    XCTAssertNil(model.currentSession?.entries.first?.target)
  }

  func testAddAndFinishDoesNotSubmitNewerDraftOrFinishAfterRetry() throws {
    let (model, service) = try fixture()
    model.updateCurrentEntryDraft(text: "Submitted text", target: nil)
    XCTAssertFalse(model.submitCurrentEntryDraft())
    model.updateCurrentEntryDraft(text: "Newer text", target: nil)
    XCTAssertFalse(model.submitCurrentEntryDraftAndFinish())
    XCTAssertEqual(model.currentEntryDraft?.text, "Newer text")
    XCTAssertEqual(model.currentSession?.lifecycle, .active)
    XCTAssertEqual(service.submissions.count, 2)
    XCTAssertTrue(service.finishIDs.isEmpty)
  }

  func testAcceptedProjectionWithoutOriginalEntryCannotAuthorizeFinish() throws {
    let (model, service) = try fixture()
    service.omitsAcceptedEntry = true
    model.updateCurrentEntryDraft(text: "Keep original", target: nil)
    XCTAssertFalse(model.submitCurrentEntryDraftAndFinish())
    XCTAssertFalse(model.submitCurrentEntryDraftAndFinish())
    XCTAssertEqual(model.currentEntryDraft?.text, "Keep original")
    XCTAssertEqual(model.currentSession?.lifecycle, .active)
    XCTAssertTrue(service.finishIDs.isEmpty)
  }

  func testRelaunchRetriesOriginalEntryAndPreservesNewerDraftAndTarget() throws {
    let (model, service) = try fixture()
    let target = SessionProgressTarget.instruction(try XCTUnwrap(model.currentSession?.snapshot.instructionSections.first?.steps.first?.id))
    model.updateCurrentEntryDraft(text: "Original", target: nil)
    XCTAssertFalse(model.submitCurrentEntryDraft())
    model.updateCurrentEntryDraft(text: "Newer", target: target)
    let pending = try XCTUnwrap(model.pendingCommands.first)
    let relaunched = CookingSessionPresentationModel(sessions: service, store: model.store)
    relaunched.loadIfNeeded()
    XCTAssertEqual(relaunched.currentEntryDraft?.text, "Newer")
    XCTAssertEqual(relaunched.currentEntryDraft?.target, target)
    XCTAssertTrue(relaunched.pendingCommands.isEmpty)
    guard case let .submitEntry(factID, _, _, _, _) = pending else { return XCTFail("Expected Entry") }
    XCTAssertEqual(service.submissions, [factID, factID])
  }

  func testLaterDeliberateIdenticalNoteCreatesDistinctEntry() throws {
    let (model, service) = try fixture()
    model.updateCurrentEntryDraft(text: "Repeat deliberately", target: nil)
    XCTAssertFalse(model.submitCurrentEntryDraft())
    model.retryPendingCommands()
    XCTAssertNil(model.currentEntryDraft)
    model.updateCurrentEntryDraft(text: "Repeat deliberately", target: nil)
    XCTAssertTrue(model.submitCurrentEntryDraft())
    XCTAssertEqual(model.currentSession?.entries.map(\.text), ["Repeat deliberately", "Repeat deliberately"])
    XCTAssertEqual(service.submissions.count, 3)
    XCTAssertNotEqual(service.submissions[1], service.submissions[2])
  }

  func testRepeatedRetryFailureCannotUseOptimisticEntryAsAcceptance() throws {
    let (model, service) = try fixture()
    service.blocksSubmission = true
    model.updateCurrentEntryDraft(text: "Still pending", target: nil)
    XCTAssertFalse(model.submitCurrentEntryDraft())
    XCTAssertFalse(model.submitCurrentEntryDraft())
    XCTAssertFalse(model.submitCurrentEntryDraftAndFinish())
    XCTAssertEqual(service.submissions.count, 3)
    XCTAssertEqual(Set(service.submissions).count, 1)
    XCTAssertEqual(model.currentEntryDraft?.text, "Still pending")
    XCTAssertTrue(model.currentSessionHasPendingEntrySubmission)
    XCTAssertTrue(service.finishIDs.isEmpty)
  }

  func testRelaunchRetainsFinishConsentAndRetriesSameClosureWithoutAnotherFinish() throws {
    let (model, service) = try fixture()
    service.blocksFinish = true
    XCTAssertFalse(model.finishCurrentSession())
    let pending = try XCTUnwrap(model.pendingCommands.first)
    let relaunched = CookingSessionPresentationModel(sessions: service, store: model.store)
    relaunched.loadIfNeeded()
    XCTAssertTrue(relaunched.currentSessionHasPendingFinish)
    XCTAssertEqual(relaunched.pendingCommands, [pending])
    relaunched.dismissIssuePresentation()
    XCTAssertEqual(relaunched.pendingCommands, [pending])
    service.blocksFinish = false
    relaunched.retryPendingCommands()
    XCTAssertTrue(relaunched.pendingCommands.isEmpty)
    XCTAssertNil(relaunched.currentSession)
    guard case let .finish(closureID, _, _) = pending else { return XCTFail("Expected Finish") }
    XCTAssertEqual(service.finishIDs, [closureID, closureID, closureID])
  }

  private func fixture() throws -> (CookingSessionPresentationModel, EntryRetryProbe) {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let service = EntryRetryProbe(base: app.cookingSessions)
    let model = CookingSessionPresentationModel(sessions: service, store: VolatileCookingSessionPresentationStore())
    model.loadIfNeeded()
    XCTAssertTrue(model.start(from: try XCTUnwrap(app.libraryModel.selectedRecipe)))
    return (model, service)
  }
}

@MainActor
private final class EntryRetryProbe: CookingSessionServing {
  let base: CookingSessions
  var submissions: [SessionFact.ID] = []
  var omitsAcceptedEntry = false
  var blocksSubmission = false
  var blocksResume = false
  var blocksFinish = false
  var resumeIDs: [SessionFact.ID] = []
  var finishIDs: [SessionClosure.ID] = []
  init(base: CookingSessions) { self.base = base }
  func sessions() throws -> [SessionProjectionResult] { try base.sessions() }
  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    try base.start(intention)
  }
  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    if case let .resume(fact) = intention {
      resumeIDs.append(fact.id)
      if blocksResume { throw CookingSessionLogicError.sessionWriteFailed }
    }
    if case let .finish(value) = intention {
      finishIDs.append(value.closureID)
      if blocksFinish { throw CookingSessionLogicError.sessionWriteFailed }
    }
    if case .submitEntry(let fact, _, _) = intention {
      submissions.append(fact.id)
      if blocksSubmission || submissions.count == 1 { throw CookingSessionLogicError.sessionWriteFailed }
      if omitsAcceptedEntry {
        let session = try XCTUnwrap(base.sessions().compactMap { result -> CookingSessionProjection? in
          guard case let .session(session) = result, session.id == fact.sessionID else { return nil }
          return session
        }.first)
        return .accepted(session)
      }
    }
    return try base.perform(intention)
  }
}
