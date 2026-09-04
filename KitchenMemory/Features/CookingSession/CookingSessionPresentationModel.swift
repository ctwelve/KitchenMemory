// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import Observation

@MainActor
protocol CookingSessionServing {
  func sessions() throws -> [SessionProjectionResult]
  func sessions(for recipeID: Recipe.ID) throws -> [SessionProjectionResult]
  func finishedSessions(limit: Int) throws -> [SessionProjectionResult]
  func unresolvedDeletionIDs(for sessionID: CookingSession.ID) throws -> [SessionDeletion.ID]
  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult
  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult
}

@MainActor
extension CookingSessions: CookingSessionServing {}

@MainActor
extension CookingSessionServing {
  func unresolvedDeletionIDs(for sessionID: CookingSession.ID) throws -> [SessionDeletion.ID] {
    _ = sessionID
    return []
  }
  func sessions(for recipeID: Recipe.ID) throws -> [SessionProjectionResult] {
    _ = recipeID
    return []
  }

  func finishedSessions(limit: Int) throws -> [SessionProjectionResult] {
    guard limit > 0 else { return [] }
    return Array(try sessions().filter { result in
      guard case let .session(session) = result else { return false }
      return session.lifecycle == .finished
    }.prefix(limit))
  }
}

enum CookingSessionHistoryScope: Equatable {
  case all
  case recipe(Recipe.ID)
}

enum CookingSessionLibraryDestination: Equatable {
  case deletedItems
  case recovery
}

enum CookingSessionPresentationIssue: Equatable {
  case read
  case clipboard
  case command(CookingSessionLogicError)
  case attention(CookingSessionAttention)

  var message: LocalizedStringResource {
    switch self {
    case .read: .sessionIssueRead
    case .clipboard: .sessionIssueClipboard
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
  static let staleSessionInterval: TimeInterval = 60 * 60 * 24 * 3

  let service: any CookingSessionServing
  let store: any CookingSessionPresentationStoring
  let now: () -> Date

  var sessions: [CookingSessionProjection] = []
  var finishedSessions: [CookingSessionProjection] = []
  var deletedSessions: [CookingSessionProjection] = []
  var waitingDeletedSessions: [UnavailableSession] = []
  var waitingSessions: [UnavailableSession] = []
  var recoverySessions: [SessionRecovery] = []
  private(set) var currentSessionID: CookingSession.ID?
  var finishedSessionCount = 0
  var unavailableSessionCount = 0
  var recoverySessionCount = 0
  var issue: CookingSessionPresentationIssue?
  var isShowingIssue = false
  private(set) var hasLoaded = false
  var outbox: CookingSessionOutbox
  var entryDrafts: [CookingSessionEntryDraft]
  var detachedEntryDraft: CookingSessionEntryDraft?
  var finishedSessionIDs: Set<CookingSession.ID> = []
  var historyScope: CookingSessionHistoryScope?
  var libraryDestination: CookingSessionLibraryDestination?
  var recipeHistorySessions: [CookingSessionProjection] = []
  var sidebarSessionIDsByRecipe: [Recipe.ID: Set<CookingSession.ID>] = [:]
  var observedFinishedSessionID: CookingSession.ID?
  var sessionVisits: [CookingSessionVisit]

  init(
    sessions: CookingSessions,
    store: any CookingSessionPresentationStoring,
    now: @escaping () -> Date = Date.init
  ) {
    service = sessions
    self.store = store
    self.now = now
    currentSessionID = store.currentSessionID
    outbox = CookingSessionOutbox(persistedCommands: store.pendingCommands)
    entryDrafts = store.entryDrafts
    sessionVisits = store.sessionVisits
  }

  init(
    sessions: any CookingSessionServing,
    store: any CookingSessionPresentationStoring,
    now: @escaping () -> Date = Date.init
  ) {
    service = sessions
    self.store = store
    self.now = now
    currentSessionID = store.currentSessionID
    outbox = CookingSessionOutbox(persistedCommands: store.pendingCommands)
    entryDrafts = store.entryDrafts
    sessionVisits = store.sessionVisits
  }

  var currentSession: CookingSessionProjection? {
    guard let session = sessions.first(where: { $0.id == currentSessionID }) else { return nil }
    return applyingPendingCommands(to: session)
  }

  var hasPendingCommand: Bool {
    !outbox.isEmpty
  }

  var pendingCommands: [PendingCookingSessionCommand] {
    outbox.commands
  }

  var currentEntryDraft: CookingSessionEntryDraft? {
    guard let currentSessionID else { return nil }
    return entryDrafts.first { $0.sessionID == currentSessionID }
  }

  func loadIfNeeded() {
    guard !hasLoaded else { return }
    if !outbox.isEmpty {
      retryPendingCommands()
    }
    reload()
    hasLoaded = true
  }

  func reloadAfterExternalStoreChange() {
    guard hasLoaded else { return }
    if !outbox.isEmpty {
      retryPendingCommands()
    }
    reload()
  }

  /// Clears every device-local and projected Session value after durable reset succeeds.
  func resetAfterKitchenReset() {
    store.clear()
    sessions = []
    finishedSessions = []
    deletedSessions = []
    waitingDeletedSessions = []
    waitingSessions = []
    recoverySessions = []
    currentSessionID = nil
    finishedSessionCount = 0
    unavailableSessionCount = 0
    recoverySessionCount = 0
    issue = nil
    isShowingIssue = false
    outbox = CookingSessionOutbox(persistedCommands: [])
    entryDrafts = []
    detachedEntryDraft = nil
    finishedSessionIDs = []
    historyScope = nil
    libraryDestination = nil
    recipeHistorySessions = []
    observedFinishedSessionID = nil
    sessionVisits = []
    hasLoaded = true
  }

  func retryCurrentIssue() {
    if !outbox.isEmpty {
      retryPendingCommands()
    } else {
      reload()
    }
  }

  func dismissIssuePresentation() {
    isShowingIssue = false
  }

  func present(_ issue: CookingSessionPresentationIssue) {
    self.issue = issue
    isShowingIssue = true
  }

  func upsert(_ session: CookingSessionProjection) {
    sessions.removeAll { $0.id == session.id }
    finishedSessions.removeAll { $0.id == session.id }
    if session.lifecycle != .finished, session.disposition == .ordinary {
      sessions.append(session)
      sessions.sort(by: sessionOrder)
    } else if session.lifecycle == .finished, session.disposition == .ordinary {
      finishedSessions.insert(session, at: 0)
      finishedSessionCount = finishedSessions.count
      finishedSessionIDs.insert(session.id)
    }
  }

  func select(_ id: CookingSession.ID?, recordsVisit: Bool = true) {
    currentSessionID = id
    store.currentSessionID = id
    if let id, recordsVisit { recordVisit(to: id) }
  }

  func replaceDraft(_ draft: CookingSessionEntryDraft) {
    entryDrafts.removeAll { $0.sessionID == draft.sessionID }
    entryDrafts.append(draft)
    persistEntryDrafts()
  }

  func removeDraft(for sessionID: CookingSession.ID) {
    entryDrafts.removeAll { $0.sessionID == sessionID }
    persistEntryDrafts()
    refreshDetachedEntryDraft()
  }

  func moveDraft(
    from sourceSessionID: CookingSession.ID,
    to destinationSessionID: CookingSession.ID,
    target: SessionProgressTarget?
  ) {
    guard let sourceDraft = entryDrafts.first(where: { $0.sessionID == sourceSessionID }) else {
      return
    }
    entryDrafts.removeAll {
      $0.sessionID == sourceSessionID || $0.sessionID == destinationSessionID
    }
    entryDrafts.append(CookingSessionEntryDraft(
      sessionID: destinationSessionID,
      text: sourceDraft.text,
      target: target
    ))
    persistEntryDrafts()
    refreshDetachedEntryDraft()
  }

  func refreshDetachedEntryDraft() {
    detachedEntryDraft = entryDrafts.first { finishedSessionIDs.contains($0.sessionID) }
  }

  private func persistEntryDrafts() {
    store.entryDrafts = entryDrafts
  }

  func sessionOrder(
    _ lhs: CookingSessionProjection,
    _ rhs: CookingSessionProjection
  ) -> Bool {
    let titleOrder = lhs.snapshot.title.localizedStandardCompare(rhs.snapshot.title)
    if titleOrder != .orderedSame { return titleOrder == .orderedAscending }
    return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
  }
}
