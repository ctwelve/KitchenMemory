// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
@testable import KitchenMemory
import XCTest

@MainActor
final class SessionDeliveryCharacterizationTests: XCTestCase {
  // Known pre-existing defect, explicitly characterized for #214 rather than
  // accepted product semantics: retry discards text edited after submission.
  func testCharacterizesRetryClearingNewerTextWhileEarlierSubmissionWasPending() throws {
    let (model, _) = try fixture()
    model.updateCurrentEntryDraft(text: "Submitted text", target: nil)
    XCTAssertFalse(model.submitCurrentEntryDraft())
    model.updateCurrentEntryDraft(text: "Newer text", target: nil)
    model.retryPendingCommands()
    XCTAssertEqual(model.currentSession?.entries.map(\.text), ["Submitted text"])
    XCTAssertNil(model.currentEntryDraft)
  }

  // A second explicit submit retries the old identity, then creates another.
  // Unchanged text becomes two Entries; new text is captured before retry clears
  // the draft. These are pre-refactor behaviors, not a new duplication policy.
  func testCharacterizesSecondSubmissionAfterRetryWithUnchangedOrEditedText() throws {
    for text in ["Submitted text", "Newer text"] {
      let (model, service) = try fixture()
      model.updateCurrentEntryDraft(text: "Submitted text", target: nil)
      XCTAssertFalse(model.submitCurrentEntryDraft())
      model.updateCurrentEntryDraft(text: text, target: nil)
      XCTAssertTrue(model.submitCurrentEntryDraft())
      XCTAssertEqual(service.submissions.count, 3)
      XCTAssertEqual(service.submissions[0], service.submissions[1])
      XCTAssertNotEqual(service.submissions[1], service.submissions[2])
      XCTAssertEqual(model.currentSession?.entries.map(\.text).sorted(), ["Submitted text", text].sorted())
      XCTAssertNil(model.currentEntryDraft)
    }
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
  init(base: CookingSessions) { self.base = base }
  func sessions() throws -> [SessionProjectionResult] { try base.sessions() }
  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    try base.start(intention)
  }
  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    if case .submitEntry(let fact, _, _) = intention {
      submissions.append(fact.id)
      if submissions.count == 1 { throw CookingSessionLogicError.sessionWriteFailed }
    }
    return try base.perform(intention)
  }
}
