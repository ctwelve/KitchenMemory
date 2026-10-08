// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit

struct CookingSessionHistoryGroup {
  let lifecycle: SessionLifecycle
  let sessions: [CookingSessionProjection]
}

@MainActor
extension CookingSessionPresentationModel {
  static let recentSessionLimit = 5

  var isShowingSessionHistory: Bool {
    historyScope != nil
  }

  var observedFinishedSession: CookingSessionProjection? {
    let available = finishedSessions + recipeHistorySessions
    return available.first { $0.id == observedFinishedSessionID }
  }

  /// The middle list and detail share the retained history entry context.
  var displayedHistoryScope: CookingSessionHistoryScope? {
    guard case .history(let scope) = navigation.contentDestination else { return nil }
    return scope
  }

  var displayedHistorySessions: [CookingSessionProjection] {
    displayedHistoryGroups.flatMap(\.sessions)
  }

  var displayedHistoryGroups: [CookingSessionHistoryGroup] {
    let available: [CookingSessionProjection]
    switch displayedHistoryScope {
    case .all: available = sessions + finishedSessions
    case .recipe:
      let ids = Set(recipeHistorySessions.map(\.id))
      available = (sessions + finishedSessions).filter { ids.contains($0.id) }
    case nil: return []
    }
    return [SessionLifecycle.active, .stopped, .finished].compactMap { lifecycle in
      let grouped = available.filter { $0.lifecycle == lifecycle }.sorted(by: historySessionOrder)
      return grouped.isEmpty ? nil : CookingSessionHistoryGroup(lifecycle: lifecycle, sessions: grouped)
    }
  }

  private func historySessionOrder(_ lhs: CookingSessionProjection, _ rhs: CookingSessionProjection) -> Bool {
    let lhsDate = lhs.startedAt ?? .distantPast
    let rhsDate = rhs.startedAt ?? .distantPast
    if lhsDate != rhsDate { return lhsDate > rhsDate }
    return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
  }

  var currentHistorySession: CookingSessionProjection? {
    let visitBySession = latestVisitBySession
    return sessions.filter { visitBySession[$0.id] != nil }.max { lhs, rhs in
      guard let lhsDate = visitBySession[lhs.id], let rhsDate = visitBySession[rhs.id]
      else { return false }
      if lhsDate != rhsDate { return lhsDate < rhsDate }
      return lhs.id.rawValue.uuidString > rhs.id.rawValue.uuidString
    }
  }

  func sidebarSessions(for recipeID: Recipe.ID) -> [CookingSessionProjection] {
    let matchingIDs = sidebarSessionIDsByRecipe[recipeID] ?? []
    let candidates = sessions.filter { matchingIDs.contains($0.id) }
    let active = candidates.filter { $0.lifecycle == .active }.sorted(by: sessionOrder)
    let stopped = candidates.filter { $0.lifecycle == .stopped }
    return active + recentHistorySessions(from: stopped, excluding: nil)
  }

  func refreshSidebarAssociations(for recipeIDs: [Recipe.ID]) {
    let visibleIDs = Set(recipeIDs)
    sidebarSessionIDsByRecipe = historySessionIDsByRecipe.filter { visibleIDs.contains($0.key) }
  }

  func recentHistorySessions(
    from candidates: [CookingSessionProjection],
    excluding currentID: CookingSession.ID?
  ) -> [CookingSessionProjection] {
    let visitBySession = latestVisitBySession
    let ordered = candidates.filter { $0.id != currentID }.sorted { lhs, rhs in
      let lhsDate = visitBySession[lhs.id] ?? .distantPast
      let rhsDate = visitBySession[rhs.id] ?? .distantPast
      if lhsDate != rhsDate { return lhsDate > rhsDate }
      return sessionOrder(lhs, rhs)
    }
    return Array(ordered.prefix(Self.recentSessionLimit))
  }

  var currentSessionNeedsStaleNudge: Bool {
    guard let currentSession,
          let visit = sessionVisits.first(where: { $0.sessionID == currentSession.id }),
          !visit.dismissedStaleNudge
    else { return false }
    return now().timeIntervalSince(visit.lastVisitedAt) >= Self.staleSessionInterval
  }

  func continuations(of sessionID: CookingSession.ID) -> [CookingSessionProjection] {
    (sessions + finishedSessions).filter { $0.sourceSessionID == sessionID }.sorted(by: historySessionOrder)
  }

  func retainedSession(_ id: CookingSession.ID) -> CookingSessionProjection? {
    (sessions + finishedSessions + deletedSessions).first { $0.id == id }
  }

  @discardableResult
  func selectSession(_ id: CookingSession.ID) -> Bool {
    guard sessions.contains(where: { $0.id == id }),
          navigation.move(to: .session(id, history: nil)) else { return false }
    recordVisit(to: id)
    return true
  }

  @discardableResult
  func selectSessionFromHistory(_ id: CookingSession.ID) -> Bool {
    guard let scope = displayedHistoryScope, sessions.contains(where: { $0.id == id }),
          navigation.move(to: .session(id, history: scope)) else { return false }
    recordVisit(to: id)
    return true
  }

  @discardableResult
  func leaveCurrentSession() -> Bool {
    guard currentSessionID != nil else { return false }
    return select(nil, recordsVisit: false)
  }

  func showSessionHistory() {
    navigation.move(to: .history(.all))
  }

  @discardableResult
  func showRecipeSessionHistory(for recipeID: Recipe.ID) -> Bool {
    guard navigation.move(to: .history(.recipe(recipeID))) else { return false }
    recipeHistorySessions = recipeHistory(for: recipeID)
    return true
  }

  func showRecipes() {
    navigation.move(to: .recipe)
  }

  @discardableResult
  func observeFinishedSession(_ id: CookingSession.ID) -> Bool {
    guard finishedSessions.contains(where: { $0.id == id })
            || recipeHistorySessions.contains(where: { $0.id == id })
    else { return false }
    return navigation.move(to: .finished(id, history: displayedHistoryScope ?? .all))
  }

  func dismissObservedFinishedSession() {
    navigation.move(to: historyScope.map { .history($0) } ?? .recipe)
  }

  @discardableResult
  func continueSession(_ sourceSessionID: CookingSession.ID) -> Bool {
    guard finishedSessions.contains(where: { $0.id == sourceSessionID })
    else { return false }
    return submitCommand { .continueSession(
      sessionID: CookingSession.ID(),
      sourceSessionID: sourceSessionID,
      startedAt: now()
    ) }
  }

  func dismissStaleSessionNudge() {
    guard let currentSessionID,
          let index = sessionVisits.firstIndex(where: { $0.sessionID == currentSessionID })
    else { return }
    sessionVisits[index].dismissedStaleNudge = true
    persistSessionVisits()
  }

  func reload() {
    do {
      let read = try service.history()
      let classified = SessionHistoryClassification(read.sessions)
      let finished = ordinaryFinishedSessions(in: read)
      historySessionIDsByRecipe = read.sessionIDsByRecipe
      sidebarSessionIDsByRecipe = read.sessionIDsByRecipe
      apply(classified: classified, finished: finished)
      refreshRecipeHistory()
    } catch {
      present(.read)
    }
  }

  func refreshRecipeHistory() {
    guard case .recipe(let id) = displayedHistoryScope else { return }
    recipeHistorySessions = recipeHistory(for: id)
  }

  private func recipeHistory(for recipeID: Recipe.ID) -> [CookingSessionProjection] {
    let matchingIDs = historySessionIDsByRecipe[recipeID] ?? []
    return (sessions + finishedSessions).filter { matchingIDs.contains($0.id) }
  }

  private func ordinaryFinishedSessions(in read: CookingSessionHistoryRead) -> [CookingSessionProjection] {
    read.finishedSessions.compactMap {
      guard case let .session(session) = $0,
            session.disposition == .ordinary,
            session.lifecycle == .finished
      else { return nil }
      return session
    }
  }

  private func apply(
    classified: SessionHistoryClassification,
    finished: [CookingSessionProjection]
  ) {
    let finishedIDs = Set(finished.map(\.id))
    sessions = classified.ordinary.sorted(by: sessionOrder)
    finishedSessions = finished
    deletedSessions = classified.deleted.sorted(by: sessionOrder)
    waitingDeletedSessions = classified.waitingDeleted
    waitingSessions = classified.waiting
    recoverySessions = classified.recovery
    finishedSessionCount = finished.count
    unavailableSessionCount = classified.waiting.count + classified.waitingDeleted.count
    recoverySessionCount = classified.recovery.count
    finishedSessionIDs = finishedIDs
    refreshDetachedEntryDraft()
    if let currentSessionID, finishedIDs.contains(currentSessionID) {
      navigation.move(to: .finished(currentSessionID, history: historyScope))
    }
    if let observedFinishedSessionID, !finishedIDs.contains(observedFinishedSessionID) {
      dismissObservedFinishedSession()
    }
    if pendingCommands.isEmpty {
      issue = nil
      isShowingIssue = false
    }
  }

  func recordVisit(to sessionID: CookingSession.ID) {
    sessionVisits.removeAll { $0.sessionID == sessionID }
    sessionVisits.append(CookingSessionVisit(
      sessionID: sessionID,
      lastVisitedAt: now(),
      dismissedStaleNudge: false
    ))
    persistSessionVisits()
  }

  private func persistSessionVisits() {
    store.sessionVisits = sessionVisits
  }

  private var latestVisitBySession: [CookingSession.ID: Date] {
    sessionVisits.reduce(into: [:]) { latestVisits, visit in
      latestVisits[visit.sessionID] = max(
        latestVisits[visit.sessionID] ?? .distantPast,
        visit.lastVisitedAt
      )
    }
  }
}

private struct SessionHistoryClassification {
  var ordinary: [CookingSessionProjection] = []
  var deleted: [CookingSessionProjection] = []
  var waitingDeleted: [UnavailableSession] = []
  var waiting: [UnavailableSession] = []
  var recovery: [SessionRecovery] = []

  init(_ results: [SessionProjectionResult]) {
    for result in results {
      switch result {
      case let .session(session):
        if case .deleted = session.disposition {
          deleted.append(session)
        } else if session.lifecycle != .finished {
          ordinary.append(session)
        }
      case let .unavailable(unavailable):
        if unavailable.evidence.deletions.isEmpty {
          waiting.append(unavailable)
        } else {
          waitingDeleted.append(unavailable)
        }
      case let .recovery(item):
        recovery.append(item)
      }
    }
  }
}
