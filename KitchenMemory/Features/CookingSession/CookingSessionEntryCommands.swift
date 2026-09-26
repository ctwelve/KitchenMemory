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
          let draft = currentEntryDraft, draft.isMeaningful else { return false }
    return submitCommand { .submitEntry(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date(),
      text: draft.text,
      target: draft.target
    ) }
  }

  @discardableResult
  func reviseEntry(
    _ entryID: SessionEntry.ID,
    text: String,
    target: SessionProgressTarget?
  ) -> Bool {
    guard let session = currentSession, session.lifecycle == .active,
          CookingSessionEntryDraft.isMeaningful(text),
          session.knowsEntry(entryID) else { return false }
    return submitCommand { .reviseEntry(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date(),
      entryID: entryID,
      text: text,
      target: target
    ) }
  }

  @discardableResult
  func retargetEntry(_ entryID: SessionEntry.ID, to target: SessionProgressTarget?) -> Bool {
    guard let session = currentSession, session.lifecycle == .active,
          session.entries.contains(where: { $0.id == entryID }) else { return false }
    return submitCommand { .retargetEntry(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date(),
      entryID: entryID,
      target: target
    ) }
  }

  @discardableResult
  func withdrawEntry(_ entryID: SessionEntry.ID) -> Bool {
    guard let session = currentSession, session.lifecycle == .active,
          session.knowsEntry(entryID) else { return false }
    return submitCommand { .withdrawEntry(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date(),
      entryID: entryID
    ) }
  }

  @discardableResult
  func setOutcome(_ outcome: SessionOutcome) -> Bool {
    guard let session = currentSession, session.lifecycle == .active else { return false }
    return submitCommand { .setOutcome(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date(),
      outcome: outcome
    ) }
  }

  @discardableResult
  func clearOutcome() -> Bool {
    guard let session = currentSession, session.lifecycle == .active,
          session.outcome != nil || session.hasOutcomeConflict else { return false }
    return submitCommand { .clearOutcome(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date()
    ) }
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
    return submitCommand { .continueSession(
      sessionID: CookingSession.ID(),
      sourceSessionID: draft.sessionID,
      startedAt: Date()
    ) }
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
