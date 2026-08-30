// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import Observation

@MainActor
protocol CookingSessionServing {
  func sessions() throws -> [SessionProjectionResult]
  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult
  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult
}

@MainActor
extension CookingSessions: CookingSessionServing {}

enum CookingSessionPresentationIssue: Equatable {
  case read
  case command(CookingSessionLogicError)
  case attention(CookingSessionAttention)

  var message: LocalizedStringResource {
    switch self {
    case .read: .sessionIssueRead
    case .command: .sessionIssueCommand
    case .attention: .sessionIssueAttention
    }
  }
}

/// Replaceable presentation projection over retained Cooking Session evidence.
/// It selects and translates commands but never derives lifecycle from view or
/// process state.
@MainActor
@Observable
final class CookingSessionPresentationModel {
  let service: any CookingSessionServing
  let store: any CookingSessionPresentationStoring

  var sessions: [CookingSessionProjection] = []
  private(set) var currentSessionID: CookingSession.ID?
  var finishedSessionCount = 0
  private(set) var unavailableSessionCount = 0
  private(set) var recoverySessionCount = 0
  var issue: CookingSessionPresentationIssue?
  var isShowingIssue = false
  private(set) var hasLoaded = false
  var pendingCommands: [PendingCookingSessionCommand]

  init(
    sessions: CookingSessions,
    store: any CookingSessionPresentationStoring
  ) {
    service = sessions
    self.store = store
    currentSessionID = store.currentSessionID
    pendingCommands = store.pendingCommands
  }

  init(
    sessions: any CookingSessionServing,
    store: any CookingSessionPresentationStoring
  ) {
    service = sessions
    self.store = store
    currentSessionID = store.currentSessionID
    pendingCommands = store.pendingCommands
  }

  var currentSession: CookingSessionProjection? {
    guard let session = sessions.first(where: { $0.id == currentSessionID }) else { return nil }
    return applyingPendingCommands(to: session)
  }

  var hasPendingCommand: Bool {
    !pendingCommands.isEmpty
  }

  func loadIfNeeded() {
    guard !hasLoaded else { return }
    if !pendingCommands.isEmpty {
      retryPendingCommands()
    }
    reload()
    hasLoaded = true
  }

  func reloadAfterExternalStoreChange() {
    guard hasLoaded else { return }
    if !pendingCommands.isEmpty {
      retryPendingCommands()
    }
    reload()
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

  func retryCurrentIssue() {
    if !pendingCommands.isEmpty {
      retryPendingCommands()
    } else {
      reload()
    }
  }

  func dismissIssuePresentation() {
    isShowingIssue = false
  }

  private func reload() {
    do {
      var ordinary: [CookingSessionProjection] = []
      var finishedCount = 0
      var finishedIDs: Set<CookingSession.ID> = []
      var unavailableCount = 0
      var recoveryCount = 0
      for result in try service.sessions() {
        switch result {
        case let .session(session):
          guard session.disposition == .ordinary else { continue }
          if session.lifecycle == .finished {
            finishedCount += 1
            finishedIDs.insert(session.id)
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
      if let currentSessionID, finishedIDs.contains(currentSessionID) { select(nil) }
      if pendingCommands.isEmpty {
        issue = nil
        isShowingIssue = false
      }
    } catch {
      present(.read)
    }
  }

  func present(_ issue: CookingSessionPresentationIssue) {
    self.issue = issue
    isShowingIssue = true
  }

  func upsert(_ session: CookingSessionProjection) {
    sessions.removeAll { $0.id == session.id }
    if session.lifecycle != .finished, session.disposition == .ordinary {
      sessions.append(session)
      sessions.sort(by: sessionOrder)
    }
  }

  func select(_ id: CookingSession.ID?) {
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
