// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit

@MainActor
extension CookingSessionPresentationModel {
  var currentSessionHasPendingEntrySubmission: Bool {
    pendingCommands.contains {
      guard $0.sessionID == currentSessionID, case .submitEntry = $0 else { return false }
      return true
    }
  }

  var currentSessionHasPendingFinish: Bool {
    pendingCommands.contains {
      guard $0.sessionID == currentSessionID, case .finish = $0 else { return false }
      return true
    }
  }

  /// Delivery is globally ordered: another Session's unsaved work also blocks Finish.
  var currentSessionHasPendingWork: Bool { !pendingCommands.isEmpty }

  var finishBlockedByEarlierWork: Bool {
    currentSessionHasPendingWork && !currentSessionHasPendingFinish
  }

  /// All Add Note routes reopen meaningful work without replacing text or target.
  func openEntryComposer(target: SessionProgressTarget? = nil, origin: UUID? = nil) {
    guard let session = currentSession, session.lifecycle == .active,
          !currentSessionHasPendingFinish else { return }
    if currentEntryDraft?.isMeaningful != true {
      updateCurrentEntryDraft(text: currentEntryDraft?.text ?? "", target: target)
    }
    entryComposerOrigin = origin
    isShowingEntryComposer = true
  }

  func dismissEntryComposer(origin: UUID? = nil) {
    guard entryComposerOrigin == origin else { return }
    isShowingEntryComposer = false
    entryComposerOrigin = nil
  }

  /// Resume is authorized only by this explicit choice; acceptance opens the composer.
  @discardableResult
  func resumeToEditCurrentEntryDraft(origin: UUID? = nil) -> Bool {
    guard let session = currentSession, session.lifecycle == .stopped,
          !currentSessionHasPendingWork else { return false }
    return submitCommand {
      let factID = SessionFact.ID()
      self.pendingEntryComposerResumes[factID] = session.id
      self.pendingEntryComposerResumeOrigins[factID] = origin
      return .resume(factID: factID, sessionID: session.id, authoredAt: Date())
    }
  }
}
