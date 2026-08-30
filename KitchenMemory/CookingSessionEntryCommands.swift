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
          !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          session.entries.contains(where: { $0.id == entryID }),
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
          session.entries.contains(where: { $0.id == entryID }),
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
          session.outcome != nil, prepareForNewCommand() else { return false }
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

  func discardDetachedEntryDraft() {
    guard let detachedEntryDraft else { return }
    removeDraft(for: detachedEntryDraft.sessionID)
  }

  @discardableResult
  func continueDetachedEntryDraft() -> Bool {
    guard let draft = detachedEntryDraft, prepareForNewCommand() else { return false }
    return stageAndPerform(.continueSession(
      sessionID: CookingSession.ID(),
      sourceSessionID: draft.sessionID,
      startedAt: Date()
    ))
  }
}
