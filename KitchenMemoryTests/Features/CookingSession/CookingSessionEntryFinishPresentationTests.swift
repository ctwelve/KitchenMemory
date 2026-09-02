// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import KitchenKit
import XCTest

@MainActor
extension CookingSessionEntryPresentationTests {
  func testSubmittingDraftThenFinishingPreservesExactEntryEvidence() throws {
    let preparedApp = try AppRuntime.testing()
    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(preparedApp.libraryModel.recipes.first)
    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))
    let sessionID = try XCTUnwrap(preparedApp.sessionModel.currentSession?.id)
    preparedApp.sessionModel.updateCurrentEntryDraft(text: "  exact finish note 🌮  ", target: nil)

    XCTAssertTrue(preparedApp.sessionModel.submitCurrentEntryDraftAndFinish())

    XCTAssertNil(preparedApp.sessionModel.currentEntryDraft)
    XCTAssertNil(preparedApp.sessionModel.currentSession)
    let finishedSessions: [CookingSessionProjection] = try preparedApp.cookingSessions
      .sessions()
      .compactMap { result in
        guard case let .session(session) = result, session.id == sessionID else { return nil }
        return session
      }
    let finished = try XCTUnwrap(finishedSessions.first)
    XCTAssertEqual(finished.lifecycle, .finished)
    XCTAssertEqual(finished.entries.first?.text, "  exact finish note 🌮  ")
  }

  func testCopyFailureKeepsCurrentDraftAndSuccessfulCopyFinishes() throws {
    let preparedApp = try AppRuntime.testing()
    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(preparedApp.libraryModel.recipes.first)
    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))
    preparedApp.sessionModel.updateCurrentEntryDraft(text: "Copy me exactly", target: nil)

    XCTAssertFalse(preparedApp.sessionModel.copyCurrentEntryDraftAndFinish(using: { _ in false }))
    XCTAssertEqual(preparedApp.sessionModel.currentEntryDraft?.text, "Copy me exactly")
    XCTAssertNotNil(preparedApp.sessionModel.currentSession)
    XCTAssertEqual(preparedApp.sessionModel.issue, .clipboard)

    var copiedText: String?
    XCTAssertTrue(preparedApp.sessionModel.copyCurrentEntryDraftAndFinish(using: {
      copiedText = $0
      return true
    }))
    XCTAssertEqual(copiedText, "Copy me exactly")
    XCTAssertNil(preparedApp.sessionModel.currentEntryDraft)
    XCTAssertNil(preparedApp.sessionModel.currentSession)
  }

  func testRemoteFinishCopyFailureKeepsDetachedDraftUntilCopySucceeds() {
    let sessionID = CookingSession.ID()
    let service = RemoteFinishDuringSubmitService(sessionID: sessionID)
    let store = VolatileCookingSessionPresentationStore()
    store.currentSessionID = sessionID
    let model = CookingSessionPresentationModel(sessions: service, store: store)
    model.loadIfNeeded()
    model.updateCurrentEntryDraft(text: "Detached exact text", target: nil)
    XCTAssertFalse(model.submitCurrentEntryDraft())
    service.isRemotelyFinished = true
    model.reloadAfterExternalStoreChange()

    XCTAssertFalse(model.copyAndDiscardDetachedEntryDraft(using: { _ in false }))
    XCTAssertEqual(model.detachedEntryDraft?.text, "Detached exact text")
    XCTAssertEqual(model.issue, .clipboard)

    var copiedText: String?
    XCTAssertTrue(model.copyAndDiscardDetachedEntryDraft(using: {
      copiedText = $0
      return true
    }))
    XCTAssertEqual(copiedText, "Detached exact text")
    XCTAssertNil(model.detachedEntryDraft)
    XCTAssertTrue(store.entryDrafts.isEmpty)
  }
}
