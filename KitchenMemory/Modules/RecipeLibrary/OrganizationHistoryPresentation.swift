// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import Observation
import UndoKit

/// The initiating logical scene's presentation of KitchenKit's organization history.
@MainActor
@Observable
final class OrganizationHistoryPresentation {
  private let history: RecipeOrganizationHistory
  private let organization: RecipeOrganizationModel
  private let scope: RecipeOrganizationHistoryScope
  private let historyURL: URL
  private let dispose: () -> Void
  private let recordSession: (String) -> Void
  private let refreshSessions: () -> Void
  var pendingSessionID: CookingSession.ID? { history.pendingSessionID }
  private var locale = Locale.current
  private var available: Bool
  private var opening = false
  @ObservationIgnored private var pendingMove: Task<Void, Never>?
  @ObservationIgnored private var attachment: HistoryAttachment?
  private(set) var canUndo = false
  private(set) var canRedo = false
  private(set) var ready = false
  private(set) var busy = false
  private(set) var canDiscardRejectedCompensation = false
  var failed = false
  private(set) var failureMessage: LocalizedStringResource = .organizationUndoUnavailableMessage
  @ObservationIgnored private let withheldUndoManager = UndoManager()
  var nativeUndoManager: UndoManager? {
    guard available else { return nil }
    return history.sessionDeliveryIsBlocked ? withheldUndoManager : attachment?.undoManager
  }

  init(history: RecipeOrganizationHistory, organization: RecipeOrganizationModel,
       scope: RecipeOrganizationHistoryScope, historyURL: URL, available: Bool = true,
       dispose: @escaping () -> Void = {}, recordSession: @escaping (String) -> Void = { _ in },
       refreshSessions: @escaping () -> Void = {}) {
    self.history = history
    self.organization = organization
    self.scope = scope
    self.historyURL = historyURL
    self.available = available
    self.dispose = dispose
    self.recordSession = recordSession
    self.refreshSessions = refreshSessions
  }

  func open() async {
    guard available, !opening, !ready else { return }
    opening = true
    defer { opening = false }
    do {
      if history.session == nil {
        try FileManager.default.createDirectory(
          at: historyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try await history.open(scope: scope, historyURL: historyURL)
      }
      guard available else { await history.close(); return }
      guard let session = history.session else { return }
      installActionNameResolver()
      attachment = try session.attach(owner: self) { owner, _ in owner.refresh() }
      refresh()
      if !ready { failed = true }
    } catch { failed = true; ready = false }
  }

  func updateLocale(_ locale: Locale) {
    self.locale = locale
    installActionNameResolver()
  }

  private func installActionNameResolver() {
    history.session?.setNativeActionNameResolver { [weak self] payload in
      guard payload.family == RecipeOrganizationHistory.actionPresentationFamily,
            payload.version == 1 else { return nil }
      if payload.data == Data("session-progress".utf8) {
        return LocalizedStringResource.sessionUndoProgress.localized(for: self?.locale ?? .current)
      }
      if payload.data == Data("move-recipe".utf8) {
        return LocalizedStringResource.organizationUndoMoveRecipe.localized(for: self?.locale ?? .current)
      }
      if payload.data == Data("move-recipes".utf8) {
        return LocalizedStringResource.organizationUndoMoveRecipes.localized(for: self?.locale ?? .current)
      }
      if payload.data == Data("add-tag".utf8) {
        return LocalizedStringResource.organizationAddTag.localized(for: self?.locale ?? .current)
      }
      if payload.data == Data("remove-tag".utf8) {
        return LocalizedStringResource.organizationRemoveTag.localized(for: self?.locale ?? .current)
      }
      return nil
    }
  }

  func progress(_ sessionID: CookingSession.ID, to progress: SessionProgress) async -> Bool {
    await open()
    guard available, ready, !busy else { failed = true; return false }
    busy = true
    defer { busy = false; refresh() }
    do {
      let result = try await history.progress(sessionID, to: progress)
      receive(result)
      if case .accepted = result { return true }
    } catch { failed = true; failureMessage = .historyUndoFailureMessage }
    return false
  }

  func refreshAvailability() {
    attachment?.isAvailable = available && !history.sessionDeliveryIsBlocked
    canUndo = ready && !history.sessionDeliveryIsBlocked && history.session?.status.canUndo == true
    canRedo = ready && !history.sessionDeliveryIsBlocked && history.session?.status.canRedo == true
  }

  func requestMove(_ ids: Set<Recipe.ID>, to folder: Folder.ID?) {
    guard pendingMove == nil else { failed = true; return }
    pendingMove = Task {
      await move(ids, to: folder)
      pendingMove = nil
    }
  }

  func requestClassify(_ ids: Set<Recipe.ID>, tagID: Tag.ID, adding: Bool) {
    guard pendingMove == nil else { failed = true; return }
    pendingMove = Task {
      await classify(ids, tagID: tagID, adding: adding)
      pendingMove = nil
    }
  }

  func classify(_ ids: Set<Recipe.ID>, tagID: Tag.ID, adding: Bool) async {
    await open()
    guard available, ready, !busy else { failed = true; return }
    busy = true
    defer { busy = false; refresh() }
    do { receive(try await history.classify(ids, tagID: tagID, adding: adding)) } catch {
      failed = true
      failureMessage = .historyUndoFailureMessage
    }
  }

  func waitForPendingOperation() async { await pendingMove?.value }

  func move(_ ids: Set<Recipe.ID>, to folder: Folder.ID?) async {
    await open()
    guard available, ready, !busy else { failed = true; return }
    busy = true
    defer { busy = false; refresh() }
    do { receive(try await history.move(ids, to: folder)) } catch {
      failed = true
      failureMessage = .historyUndoFailureMessage
    }
  }

  func undo() async {
    guard available, ready, !busy else { return }
    busy = true
    receive(await history.undo())
    busy = false
    refresh()
  }

  func redo() async {
    guard available, ready, !busy else { return }
    busy = true
    receive(await history.redo())
    busy = false
    refresh()
  }

  func retry() async {
    guard available, !busy else { return }
    failed = false
    await open()
    do {
      if let result = try await history.retryPending() { receive(result) }
      if let result = await history.reconcile() { receive(result) }
    } catch { failed = true }
    refresh()
  }

  func discardRejectedCompensation() async {
    guard available, !busy, canDiscardRejectedCompensation else { return }
    busy = true
    do {
      try await history.discardRejectedCompensation()
      attachment?.disconnect()
      if let session = history.session {
        attachment = try session.attach(owner: self) { owner, _ in owner.refresh() }
      }
      installActionNameResolver()
      failed = false
    } catch { failed = true }
    busy = false
    refresh()
  }

  func reconcile() async {
    guard available, ready, !busy, history.session?.snapshot.hasPending != true else { return }
    if let result = await history.reconcile() { receive(result) }
    refresh()
  }

  /// Presentation disconnection preserves eligible history and its stable scene identity.
  func disconnect() async {
    attachment?.disconnect()
    attachment = nil
    ready = false
    canUndo = false
    canRedo = false
    canDiscardRejectedCompensation = false
    await history.close()
  }

  func recordSceneSession(_ identifier: String) { recordSession(identifier) }

  func disposeScene() { dispose() }

  func block() {
    available = false
    attachment?.isAvailable = false
    canUndo = false
    canRedo = false
    canDiscardRejectedCompensation = false
    ready = false
    Task { await disconnect() }
  }

  func waitForNativeOperations() async {
    await history.session?.waitForNativeOperations()
    refresh()
  }

  func refresh() {
    refreshSessions()
    let previous = organization.snapshot
    organization.refresh()
    if previous != organization.snapshot { organization.organizationDidChange() }
    ready = available && history.session?.status.phase == .ready
    refreshAvailability()
    canDiscardRejectedCompensation = available && history.canDiscardRejectedCompensation
    if history.hasPendingCompensation {
      failed = true
      failureMessage = .historyUndoFailureMessage
    } else if history.session?.status.issue != nil {
      failed = true
      failureMessage = ready ? .historyUndoFailureMessage : .organizationUndoUnavailableMessage
    }
  }

  private func receive(_ result: HistorySubmissionResult) {
    switch result {
    case .accepted, .rejected: break
    case .failed, .unexecuted, .unresolved:
      failed = true
      failureMessage = .historyUndoFailureMessage
    }
  }
}
