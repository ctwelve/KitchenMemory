// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit

@MainActor
extension CookingSessionPresentationModel {
  // This exhaustive retry router keeps every durable command identity adjacent
  // to its matching Logic intention so new enum cases cannot be silently lost.
  // swiftlint:disable:next cyclomatic_complexity function_body_length
  func perform(_ pending: PendingCookingSessionCommand) throws -> CookingSessionCommandResult {
    switch pending {
    case let .start(sessionID, recipeID, revisionID, startedAt):
      try service.start(StartCookingSessionIntention(
        sessionID: sessionID,
        recipeID: recipeID,
        recipeRevisionID: revisionID,
        startedAt: startedAt
      ))
    case let .stop(factID, sessionID, authoredAt):
      try service.perform(.stop(fact(factID, sessionID, authoredAt)))
    case let .resume(factID, sessionID, authoredAt):
      try service.perform(.resume(fact(factID, sessionID, authoredAt)))
    case let .progress(factID, sessionID, authoredAt, progress):
      try service.perform(.progress(fact(factID, sessionID, authoredAt), progress))
    case let .replaceWorkingScale(factID, sessionID, authoredAt, scale):
      try service.perform(.replaceWorkingScale(fact(factID, sessionID, authoredAt), scale))
    case let .submitEntry(factID, sessionID, authoredAt, text, target):
      try service.perform(.submitEntry(fact(factID, sessionID, authoredAt), text: text, target: target))
    case let .reviseEntry(factID, sessionID, authoredAt, entryID, text, target):
      try service.perform(.reviseEntry(
        fact(factID, sessionID, authoredAt),
        entryID: entryID,
        text: text,
        target: target
      ))
    case let .retargetEntry(factID, sessionID, authoredAt, entryID, target):
      try service.perform(.retargetEntry(
        fact(factID, sessionID, authoredAt),
        entryID: entryID,
        target: target
      ))
    case let .withdrawEntry(factID, sessionID, authoredAt, entryID):
      try service.perform(.withdrawEntry(fact(factID, sessionID, authoredAt), entryID: entryID))
    case let .setOutcome(factID, sessionID, authoredAt, outcome):
      try service.perform(.setOutcome(fact(factID, sessionID, authoredAt), outcome))
    case let .clearOutcome(factID, sessionID, authoredAt):
      try service.perform(.clearOutcome(fact(factID, sessionID, authoredAt)))
    case let .finish(closureID, sessionID, finishedAt):
      try service.perform(.finish(FinishCookingSessionIntention(
        closureID: closureID,
        sessionID: sessionID,
        finishedAt: finishedAt,
        hasMeaningfulDraft: false
      )))
    case let .delete(deletionID, sessionID, deletedAt):
      try service.perform(.delete(DeleteCookingSessionIntention(
        deletionID: deletionID,
        sessionID: sessionID,
        deletedAt: deletedAt
      )))
    case let .restore(commandID, sessionID, restoredAt, observedDeletionIDs):
      try service.perform(.restore(RestoreCookingSessionIntention(
        id: commandID,
        sessionID: sessionID,
        restoredAt: restoredAt,
        observedDeletionIDs: observedDeletionIDs
      )))
    case let .resolveClosure(factID, sessionID, authoredAt, selectedID, observedIDs):
      try service.perform(.resolveClosure(ResolveCookingSessionClosureIntention(
        fact: fact(factID, sessionID, authoredAt),
        selectedClosureID: selectedID,
        observedClosureIDs: observedIDs
      )))
    case let .continueSession(sessionID, sourceSessionID, startedAt):
      try service.perform(.continueSession(ContinueCookingSessionIntention(
        sessionID: sessionID,
        sourceSessionID: sourceSessionID,
        startedAt: startedAt
      )))
    }
  }

  private func fact(
    _ id: SessionFact.ID,
    _ sessionID: CookingSession.ID,
    _ authoredAt: Date
  ) -> SessionFactIntention {
    SessionFactIntention(id: id, sessionID: sessionID, authoredAt: authoredAt)
  }
}
