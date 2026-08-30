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
    guard recovery.reasons == [.competingClosures] else { return [] }
    let grouped = Dictionary(grouping: recovery.evidence.closures, by: \.id)
    guard grouped.values.allSatisfy({ values in
      guard let first = values.first else { return false }
      return values.allSatisfy { $0 == first }
    }) else { return [] }
    return grouped.values.compactMap(\.first).sorted {
      if $0.finishedAt != $1.finishedAt { return $0.finishedAt < $1.finishedAt }
      return $0.id.rawValue.uuidString < $1.id.rawValue.uuidString
    }
  }

  func knownDescendantCount(of sessionID: CookingSession.ID) -> Int {
    let complete = sessions + finishedSessions + deletedSessions
    let incompleteRoots = (waitingSessions + waitingDeletedSessions)
      .flatMap(\.evidence.roots)
    let recoveryRoots = recoverySessions.flatMap(\.evidence.roots)
    let edges = complete.compactMap { session in
      session.sourceSessionID.map { (session.id, $0) }
    } + (incompleteRoots + recoveryRoots).compactMap { root in
      root.sourceSessionID.map { (root.id, $0) }
    }
    var frontier = [sessionID]
    var descendants = Set<CookingSession.ID>()
    while let source = frontier.popLast() {
      for (candidate, parent) in edges where parent == source {
        if descendants.insert(candidate).inserted { frontier.append(candidate) }
      }
    }
    return descendants.count
  }
}
