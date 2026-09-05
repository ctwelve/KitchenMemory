// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit

@MainActor
extension CookingSessionPresentationModel {
  var deletedItemCount: Int {
    deletedSessions.count + waitingDeletedSessions.count
  }

  var recoveryItemCount: Int {
    waitingSessions.count + recoverySessions.count
  }

  var showsRecoveryDestination: Bool { recoveryItemCount > 0 }

  var isShowingDeletedItems: Bool {
    libraryDestination == .deletedItems
  }

  var isShowingRecovery: Bool {
    libraryDestination == .recovery
  }

  func showDeletedItems() {
    select(nil, recordsVisit: false)
    historyScope = nil
    observedFinishedSessionID = nil
    libraryDestination = .deletedItems
  }

  func showRecovery() {
    select(nil, recordsVisit: false)
    historyScope = nil
    observedFinishedSessionID = nil
    libraryDestination = .recovery
  }

  @discardableResult
  func deleteSession(_ sessionID: CookingSession.ID) -> Bool {
    let complete = sessions + finishedSessions
    guard complete.contains(where: { $0.id == sessionID && $0.disposition == .ordinary }),
          prepareForNewCommand()
    else { return false }
    return stageAndPerform(.delete(
      deletionID: SessionDeletion.ID(),
      sessionID: sessionID,
      deletedAt: now()
    ))
  }

  @discardableResult
  func restoreSession(_ sessionID: CookingSession.ID) -> Bool {
    guard deletedSessions.contains(where: { $0.id == sessionID }),
          prepareForNewCommand()
    else { return false }
    do {
      let deletionIDs = try service.unresolvedDeletionIDs(for: sessionID)
      guard !deletionIDs.isEmpty else {
        reload()
        return false
      }
      return stageAndPerform(.restore(
        commandID: RestoreCookingSessionIntention.ID(),
        sessionID: sessionID,
        restoredAt: now(),
        observedDeletionIDs: deletionIDs
      ))
    } catch {
      present(.read)
      return false
    }
  }

  @discardableResult
  func selectClosure(
    _ selectedClosureID: SessionClosure.ID,
    for recovery: SessionRecovery
  ) -> Bool {
    let candidates = closureCandidates(for: recovery)
    guard candidates.contains(where: { $0.id == selectedClosureID }),
          prepareForNewCommand()
    else { return false }
    return stageAndPerform(.resolveClosure(
      factID: SessionFact.ID(),
      sessionID: recovery.evidence.sessionID,
      authoredAt: now(),
      selectedClosureID: selectedClosureID,
      observedClosureIDs: candidates.map(\.id)
    ))
  }

  func closureCandidates(for recovery: SessionRecovery) -> [SessionClosureEvidence] {
    CookingSessions.closureCandidates(for: recovery)
  }

  func knownDescendantCount(of sessionID: CookingSession.ID) -> Int {
    let classified = (sessions + finishedSessions + deletedSessions).map {
      SessionProjectionResult.session($0)
    } + (waitingSessions + waitingDeletedSessions).map {
      SessionProjectionResult.unavailable($0)
    } + recoverySessions.map {
      SessionProjectionResult.recovery($0)
    }
    return CookingSessions.knownDescendantCount(of: sessionID, among: classified)
  }
}
