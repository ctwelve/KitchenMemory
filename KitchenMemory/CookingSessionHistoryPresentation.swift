// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit

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

  var displayedHistorySessions: [CookingSessionProjection] {
    switch historyScope {
    case .all: sessions + finishedSessions
    case .recipe: recipeHistorySessions
    case nil: []
    }
  }

  var currentHistorySession: CookingSessionProjection? {
    var visitBySession: [CookingSession.ID: Date] = [:]
    for visit in sessionVisits {
      visitBySession[visit.sessionID] = max(
        visitBySession[visit.sessionID] ?? .distantPast,
        visit.lastVisitedAt
      )
    }
    return sessions.filter { visitBySession[$0.id] != nil }.max { lhs, rhs in
      guard let lhsDate = visitBySession[lhs.id], let rhsDate = visitBySession[rhs.id]
      else { return false }
      if lhsDate != rhsDate { return lhsDate < rhsDate }
      return lhs.id.rawValue.uuidString > rhs.id.rawValue.uuidString
    }
  }

  var sidebarSessions: [CookingSessionProjection] {
    let currentID = currentHistorySession?.id
    let recent = recentHistorySessions(from: sessions, excluding: currentID)
    return Array(([currentHistorySession].compactMap { $0 } + recent).prefix(3))
  }

  func recentHistorySessions(
    from candidates: [CookingSessionProjection],
    excluding currentID: CookingSession.ID?
  ) -> [CookingSessionProjection] {
    var visitBySession: [CookingSession.ID: Date] = [:]
    for visit in sessionVisits {
      visitBySession[visit.sessionID] = max(
        visitBySession[visit.sessionID] ?? .distantPast,
        visit.lastVisitedAt
      )
    }
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
    (sessions + finishedSessions).filter { $0.sourceSessionID == sessionID }
  }

  @discardableResult
  func selectSession(_ id: CookingSession.ID) -> Bool {
    guard sessions.contains(where: { $0.id == id }) else { return false }
    select(id)
    historyScope = nil
    observedFinishedSessionID = nil
    return true
  }

  @discardableResult
  func leaveCurrentSession() -> Bool {
    guard currentSessionID != nil else { return false }
    select(nil, recordsVisit: false)
    return true
  }

  func showSessionHistory() {
    select(nil, recordsVisit: false)
    historyScope = .all
    observedFinishedSessionID = nil
  }

  func showRecipeSessionHistory(for recipeID: Recipe.ID) {
    do {
      let results = try service.sessions(for: recipeID)
      let matchingIDs = Set(results.compactMap { result -> CookingSession.ID? in
        guard case let .session(session) = result, session.disposition == .ordinary
        else { return nil }
        return session.id
      })
      recipeHistorySessions = sessions.filter { matchingIDs.contains($0.id) }
        + finishedSessions.filter { matchingIDs.contains($0.id) }
      select(nil, recordsVisit: false)
      historyScope = .recipe(recipeID)
      observedFinishedSessionID = nil
    } catch {
      present(.read)
    }
  }

  func showRecipes() {
    historyScope = nil
    observedFinishedSessionID = nil
  }

  @discardableResult
  func observeFinishedSession(_ id: CookingSession.ID) -> Bool {
    guard finishedSessions.contains(where: { $0.id == id })
            || recipeHistorySessions.contains(where: { $0.id == id })
    else { return false }
    observedFinishedSessionID = id
    return true
  }

  func dismissObservedFinishedSession() {
    observedFinishedSessionID = nil
  }

  @discardableResult
  func continueSession(_ sourceSessionID: CookingSession.ID) -> Bool {
    guard finishedSessions.contains(where: { $0.id == sourceSessionID }),
          prepareForNewCommand()
    else { return false }
    return stageAndPerform(.continueSession(
      sessionID: CookingSession.ID(),
      sourceSessionID: sourceSessionID,
      startedAt: now()
    ))
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
      let classified = SessionHistoryClassification(try service.sessions())
      let finished = try ordinaryFinishedSessions()
      apply(classified: classified, finished: finished)
    } catch {
      present(.read)
    }
  }

  private func ordinaryFinishedSessions() throws -> [CookingSessionProjection] {
    try service.finishedSessions(limit: Int.max).compactMap {
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
    finishedSessionCount = finished.count
    unavailableSessionCount = classified.unavailableCount
    recoverySessionCount = classified.recoveryCount
    finishedSessionIDs = finishedIDs
    refreshDetachedEntryDraft()
    if let currentSessionID, finishedIDs.contains(currentSessionID) {
      select(nil, recordsVisit: false)
    }
    if let observedFinishedSessionID, !finishedIDs.contains(observedFinishedSessionID) {
      self.observedFinishedSessionID = nil
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
}

private struct SessionHistoryClassification {
  var ordinary: [CookingSessionProjection] = []
  var unavailableCount = 0
  var recoveryCount = 0

  init(_ results: [SessionProjectionResult]) {
    for result in results {
      switch result {
      case let .session(session):
        if session.disposition == .ordinary, session.lifecycle != .finished {
          ordinary.append(session)
        }
      case .unavailable:
        unavailableCount += 1
      case .recovery:
        recoveryCount += 1
      }
    }
  }
}
