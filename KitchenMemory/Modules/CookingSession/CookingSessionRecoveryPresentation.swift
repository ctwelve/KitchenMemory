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
    navigation.destination == .deletedItems
  }

  var isShowingRecovery: Bool {
    navigation.destination == .recovery
  }

  func showDeletedItems() {
    navigation.move(to: .deletedItems)
  }

  func showRecovery() {
    navigation.move(to: .recovery)
  }

  @discardableResult
  func deleteSession(_ sessionID: CookingSession.ID) -> Bool {
    let complete = sessions + finishedSessions
    guard complete.contains(where: { $0.id == sessionID && $0.disposition == .ordinary })
    else { return false }
    return submitCommand { .delete(
      deletionID: SessionDeletion.ID(),
      sessionID: sessionID,
      deletedAt: now()
    ) }
  }

  @discardableResult
  func restoreSession(_ sessionID: CookingSession.ID) -> Bool {
    guard deletedSessions.contains(where: { $0.id == sessionID })
    else { return false }
    var alreadyRestored = false
    let accepted = submitCommand {
      let deletionIDs = try service.unresolvedDeletionIDs(for: sessionID)
      guard !deletionIDs.isEmpty else {
        alreadyRestored = true
        return nil
      }
      return .restore(
        commandID: RestoreCookingSessionIntention.ID(),
        sessionID: sessionID,
        restoredAt: now(),
        observedDeletionIDs: deletionIDs
      )
    }
    if alreadyRestored { reload() }
    return accepted
  }

  @discardableResult
  func selectClosure(
    _ selectedClosureID: SessionClosure.ID,
    for recovery: SessionRecovery
  ) -> Bool {
    let candidates = closureCandidates(for: recovery)
    guard candidates.contains(where: { $0.id == selectedClosureID })
    else { return false }
    return submitCommand { .resolveClosure(
      factID: SessionFact.ID(),
      sessionID: recovery.evidence.sessionID,
      authoredAt: now(),
      selectedClosureID: selectedClosureID,
      observedClosureIDs: candidates.map(\.id)
    ) }
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
