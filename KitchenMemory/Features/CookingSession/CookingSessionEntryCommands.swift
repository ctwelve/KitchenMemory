// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit

@MainActor
extension CookingSessionPresentationModel {
  func updateCurrentEntryDraft(text: String, target: SessionProgressTarget?) {
    guard let session = currentSession else { return }
    replaceDraft(CookingSessionEntryDraft(sessionID: session.id, text: text, target: target))
  }

  func discardCurrentEntryDraft() {
    guard let currentSessionID else { return }
    removeDraft(for: currentSessionID)
  }

  @discardableResult
  func submitCurrentEntryDraft() -> Bool {
    guard let session = currentSession, session.lifecycle == .active,
          let draft = currentEntryDraft, draft.isMeaningful,
          prepareForNewCommand() else { return false }
    return stageAndPerform(.submitEntry(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date(),
      text: draft.text,
      target: draft.target
    ))
  }

  @discardableResult
  func reviseEntry(
    _ entryID: SessionEntry.ID,
    text: String,
    target: SessionProgressTarget?
  ) -> Bool {
    guard let session = currentSession, session.lifecycle == .active,
          CookingSessionEntryDraft.isMeaningful(text),
          session.knowsEntry(entryID),
          prepareForNewCommand() else { return false }
    return stageAndPerform(.reviseEntry(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date(),
      entryID: entryID,
      text: text,
      target: target
    ))
  }

  @discardableResult
  func retargetEntry(_ entryID: SessionEntry.ID, to target: SessionProgressTarget?) -> Bool {
    guard let session = currentSession, session.lifecycle == .active,
          session.entries.contains(where: { $0.id == entryID }),
          prepareForNewCommand() else { return false }
    return stageAndPerform(.retargetEntry(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date(),
      entryID: entryID,
      target: target
    ))
  }

  @discardableResult
  func withdrawEntry(_ entryID: SessionEntry.ID) -> Bool {
    guard let session = currentSession, session.lifecycle == .active,
          session.knowsEntry(entryID),
          prepareForNewCommand() else { return false }
    return stageAndPerform(.withdrawEntry(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date(),
      entryID: entryID
    ))
  }

  @discardableResult
  func setOutcome(_ outcome: SessionOutcome) -> Bool {
    guard let session = currentSession, session.lifecycle == .active,
          prepareForNewCommand() else { return false }
    return stageAndPerform(.setOutcome(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date(),
      outcome: outcome
    ))
  }

  @discardableResult
  func clearOutcome() -> Bool {
    guard let session = currentSession, session.lifecycle == .active,
          session.outcome != nil || session.hasOutcomeConflict,
          prepareForNewCommand() else { return false }
    return stageAndPerform(.clearOutcome(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date()
    ))
  }

  @discardableResult
  func finishDiscardingCurrentEntryDraft() -> Bool {
    discardCurrentEntryDraft()
    return finishCurrentSession()
  }

  @discardableResult
  func submitCurrentEntryDraftAndFinish() -> Bool {
    guard submitCurrentEntryDraft() else { return false }
    return finishCurrentSession()
  }

  @discardableResult
  func copyCurrentEntryDraftAndFinish(using copy: (String) -> Bool) -> Bool {
    guard let draft = currentEntryDraft, copy(draft.text) else {
      present(.clipboard)
      return false
    }
    return finishDiscardingCurrentEntryDraft()
  }

  func discardDetachedEntryDraft() {
    guard let detachedEntryDraft else { return }
    removeDraft(for: detachedEntryDraft.sessionID)
  }

  @discardableResult
  func copyAndDiscardDetachedEntryDraft(using copy: (String) -> Bool) -> Bool {
    guard let draft = detachedEntryDraft, copy(draft.text) else {
      present(.clipboard)
      return false
    }
    discardDetachedEntryDraft()
    return true
  }

  @discardableResult
  func continueDetachedEntryDraft() -> Bool {
    guard let draft = detachedEntryDraft else { return false }
    guard prepareForNewCommand() else { return false }
    return stageAndPerform(.continueSession(
      sessionID: CookingSession.ID(),
      sourceSessionID: draft.sessionID,
      startedAt: Date()
    ))
  }
}

private extension CookingSessionProjection {
  func knowsEntry(_ entryID: SessionEntry.ID) -> Bool {
    entries.contains(where: { $0.id == entryID }) || conflicts.contains { conflict in
      guard case let .entry(conflictedID, _, _) = conflict else { return false }
      return conflictedID == entryID
    }
  }

  var hasOutcomeConflict: Bool {
    conflicts.contains { conflict in
      if case .outcome = conflict { return true }
      return false
    }
  }
}
