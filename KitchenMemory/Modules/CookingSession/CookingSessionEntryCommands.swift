// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit

@MainActor
extension CookingSessionPresentationModel {
  func updateCurrentEntryDraft(text: String, target: SessionProgressTarget?) {
    guard let session = currentSession, session.lifecycle == .active,
          !currentSessionHasPendingFinish else { return }
    replaceDraft(CookingSessionEntryDraft(sessionID: session.id, text: text, target: target))
  }

  func discardCurrentEntryDraft() {
    guard let currentSessionID else { return }
    removeDraft(for: currentSessionID)
  }

  @discardableResult
  func submitCurrentEntryDraft() -> Bool {
    guard let session = currentSession, session.lifecycle == .active,
          !currentSessionHasPendingFinish, let draft = currentEntryDraft, draft.isMeaningful else { return false }
    if let pending = pendingCommands.first(where: { command in
      guard command.sessionID == session.id, case .submitEntry = command else { return false }
      return true
    }) {
      retryPendingCommands()
      guard !pendingCommands.contains(pending),
            let accepted = sessions.first(where: { $0.id == session.id }) else { return false }
      return pending.hasAcceptedEntry(in: accepted)
    }
    return submitCommand { .submitEntry(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: now(),
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
          !currentSessionHasPendingFinish, CookingSessionEntryDraft.isMeaningful(text),
          session.knowsEntry(entryID) else { return false }
    return submitCommand { .reviseEntry(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: now(),
      entryID: entryID,
      text: text,
      target: target
    ) }
  }

  @discardableResult
  func retargetEntry(_ entryID: SessionEntry.ID, to target: SessionProgressTarget?) -> Bool {
    guard let session = currentSession, session.lifecycle == .active,
          !currentSessionHasPendingFinish, session.entries.contains(where: { $0.id == entryID }) else { return false }
    return submitCommand { .retargetEntry(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: now(),
      entryID: entryID,
      target: target
    ) }
  }

  @discardableResult
  func withdrawEntry(_ entryID: SessionEntry.ID) -> Bool {
    guard let session = currentSession, session.lifecycle == .active,
          !currentSessionHasPendingFinish, session.knowsEntry(entryID) else { return false }
    return submitCommand { .withdrawEntry(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: now(),
      entryID: entryID
    ) }
  }

  @discardableResult
  func setOutcome(_ outcome: SessionOutcome) -> Bool {
    guard let session = currentSession, session.lifecycle == .active,
          !currentSessionHasPendingFinish else { return false }
    return submitCommand { .setOutcome(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: now(),
      outcome: outcome
    ) }
  }

  @discardableResult
  func clearOutcome() -> Bool {
    guard let session = currentSession, session.lifecycle == .active,
          !currentSessionHasPendingFinish, session.outcome != nil || session.hasOutcomeConflict else { return false }
    return submitCommand { .clearOutcome(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: now()
    ) }
  }

  @discardableResult
  func finishDiscardingCurrentEntryDraft() -> Bool {
    guard !hasPendingDeliveryWork else { return false }
    discardCurrentEntryDraft()
    return finishCurrentSession()
  }

  @discardableResult
  func submitCurrentEntryDraftAndFinish() -> Bool {
    guard !currentSessionHasPendingFinish, submitCurrentEntryDraft(),
          currentEntryDraft?.isMeaningful != true else { return false }
    return finishCurrentSession()
  }

  @discardableResult
  func copyCurrentEntryDraftAndFinish(using copy: (String) -> Bool) -> Bool {
    guard !hasPendingDeliveryWork else { return false }
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
      startedAt: now()
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
