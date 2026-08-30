// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import Observation

@MainActor
protocol CookingSessionServing: AnyObject {
  func sessions() throws -> [SessionProjectionResult]
  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult
  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult
}

@MainActor
private final class CookingSessionsService: CookingSessionServing {
  let sessionsLogic: CookingSessions

  init(_ sessionsLogic: CookingSessions) {
    self.sessionsLogic = sessionsLogic
  }

  func sessions() throws -> [SessionProjectionResult] {
    try sessionsLogic.sessions()
  }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    try sessionsLogic.start(intention)
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    try sessionsLogic.perform(intention)
  }
}

enum CookingSessionPresentationIssue: Equatable {
  case read
  case command(CookingSessionLogicError)
  case attention(CookingSessionAttention)
}

/// Replaceable presentation projection over retained Cooking Session evidence.
/// It selects and translates commands but never derives lifecycle from view or
/// process state.
@MainActor
@Observable
final class CookingSessionPresentationModel {
  private let service: any CookingSessionServing
  private let store: any CookingSessionPresentationStoring

  private(set) var sessions: [CookingSessionProjection] = []
  private(set) var currentSessionID: CookingSession.ID?
  private(set) var finishedSessionCount = 0
  private(set) var unavailableSessionCount = 0
  private(set) var recoverySessionCount = 0
  private(set) var issue: CookingSessionPresentationIssue?
  private(set) var hasLoaded = false

  init(
    sessions: CookingSessions,
    store: any CookingSessionPresentationStoring
  ) {
    service = CookingSessionsService(sessions)
    self.store = store
    currentSessionID = store.currentSessionID
  }

  init(
    sessions: any CookingSessionServing,
    store: any CookingSessionPresentationStoring
  ) {
    service = sessions
    self.store = store
    currentSessionID = store.currentSessionID
  }

  var currentSession: CookingSessionProjection? {
    sessions.first { $0.id == currentSessionID }
  }

  var hasPendingCommand: Bool {
    store.pendingCommand != nil
  }

  func loadIfNeeded() {
    guard !hasLoaded else { return }
    if store.pendingCommand != nil {
      retryPendingCommand()
    }
    reload()
    hasLoaded = true
  }

  func reloadAfterExternalStoreChange() {
    guard hasLoaded else { return }
    if store.pendingCommand != nil {
      retryPendingCommand()
    }
    reload()
  }

  @discardableResult
  func start(from recipe: StoredRecipe) -> Bool {
    guard prepareForNewCommand() else { return false }
    let pending = PendingCookingSessionCommand.start(
      sessionID: CookingSession.ID(),
      recipeID: recipe.recipe.id,
      revisionID: recipe.revision.id,
      startedAt: Date()
    )
    return stageAndPerform(pending)
  }

  @discardableResult
  func stopCurrentSession() -> Bool {
    guard let session = currentSession, session.lifecycle == .active,
          prepareForNewCommand() else { return false }
    return stageAndPerform(.stop(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date()
    ))
  }

  @discardableResult
  func resumeCurrentSession() -> Bool {
    guard let session = currentSession, session.lifecycle == .stopped,
          prepareForNewCommand() else { return false }
    return stageAndPerform(.resume(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date()
    ))
  }

  @discardableResult
  func finishCurrentSession() -> Bool {
    guard let session = currentSession,
          session.lifecycle == .active || session.lifecycle == .stopped,
          prepareForNewCommand() else { return false }
    return stageAndPerform(.finish(
      closureID: SessionClosure.ID(),
      sessionID: session.id,
      finishedAt: Date()
    ))
  }

  @discardableResult
  func selectSession(_ id: CookingSession.ID) -> Bool {
    guard sessions.contains(where: { $0.id == id }) else { return false }
    select(id)
    return true
  }

  @discardableResult
  func leaveCurrentSession() -> Bool {
    guard currentSessionID != nil else { return false }
    select(nil)
    return true
  }

  func retryPendingCommand() {
    guard let pending = store.pendingCommand else { return }
    do {
      let result = try perform(pending)
      apply(result, for: pending)
    } catch let logicError as CookingSessionLogicError {
      issue = .command(logicError)
    } catch {
      issue = .read
    }
  }

  private func prepareForNewCommand() -> Bool {
    guard store.pendingCommand != nil else { return true }
    retryPendingCommand()
    return store.pendingCommand == nil
  }

  private func stageAndPerform(_ pending: PendingCookingSessionCommand) -> Bool {
    store.pendingCommand = pending
    retryPendingCommand()
    return store.pendingCommand == nil
  }

  private func perform(
    _ pending: PendingCookingSessionCommand
  ) throws -> CookingSessionCommandResult {
    switch pending {
    case let .start(sessionID, recipeID, revisionID, startedAt):
      try service.start(StartCookingSessionIntention(
        sessionID: sessionID,
        recipeID: recipeID,
        recipeRevisionID: revisionID,
        startedAt: startedAt
      ))
    case let .stop(factID, sessionID, authoredAt):
      try service.perform(.stop(SessionFactIntention(
        id: factID,
        sessionID: sessionID,
        authoredAt: authoredAt
      )))
    case let .resume(factID, sessionID, authoredAt):
      try service.perform(.resume(SessionFactIntention(
        id: factID,
        sessionID: sessionID,
        authoredAt: authoredAt
      )))
    case let .finish(closureID, sessionID, finishedAt):
      try service.perform(.finish(FinishCookingSessionIntention(
        closureID: closureID,
        sessionID: sessionID,
        finishedAt: finishedAt,
        hasMeaningfulDraft: false
      )))
    }
  }

  private func apply(
    _ result: CookingSessionCommandResult,
    for pending: PendingCookingSessionCommand
  ) {
    switch result {
    case let .accepted(session):
      store.pendingCommand = nil
      issue = nil
      upsert(session)
      if session.lifecycle == .finished {
        sessions.removeAll { $0.id == session.id }
        finishedSessionCount += 1
        if currentSessionID == session.id { select(nil) }
      } else {
        select(pending.sessionID)
      }
    case let .attention(attention):
      issue = .attention(attention)
    }
  }

  private func reload() {
    do {
      var ordinary: [CookingSessionProjection] = []
      var finishedCount = 0
      var unavailableCount = 0
      var recoveryCount = 0
      for result in try service.sessions() {
        switch result {
        case let .session(session):
          guard session.disposition == .ordinary else { continue }
          if session.lifecycle == .finished {
            finishedCount += 1
          } else {
            ordinary.append(session)
          }
        case .unavailable:
          unavailableCount += 1
        case .recovery:
          recoveryCount += 1
        }
      }
      sessions = ordinary.sorted(by: sessionOrder)
      finishedSessionCount = finishedCount
      unavailableSessionCount = unavailableCount
      recoverySessionCount = recoveryCount
      if currentSession?.lifecycle == .finished { select(nil) }
      if store.pendingCommand == nil { issue = nil }
    } catch {
      issue = .read
    }
  }

  private func upsert(_ session: CookingSessionProjection) {
    sessions.removeAll { $0.id == session.id }
    if session.lifecycle != .finished, session.disposition == .ordinary {
      sessions.append(session)
      sessions.sort(by: sessionOrder)
    }
  }

  private func select(_ id: CookingSession.ID?) {
    currentSessionID = id
    store.currentSessionID = id
  }

  private func sessionOrder(
    _ lhs: CookingSessionProjection,
    _ rhs: CookingSessionProjection
  ) -> Bool {
    let titleOrder = lhs.snapshot.title.localizedStandardCompare(rhs.snapshot.title)
    if titleOrder != .orderedSame { return titleOrder == .orderedAscending }
    return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
  }
}
