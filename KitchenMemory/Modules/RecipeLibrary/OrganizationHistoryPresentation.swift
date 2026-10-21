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
  var nativeUndoManager: UndoManager? { available ? attachment?.undoManager : nil }

  init(history: RecipeOrganizationHistory, organization: RecipeOrganizationModel,
       scope: RecipeOrganizationHistoryScope, historyURL: URL, available: Bool = true,
       dispose: @escaping () -> Void = {}, recordSession: @escaping (String) -> Void = { _ in }) {
    self.history = history
    self.organization = organization
    self.scope = scope
    self.historyURL = historyURL
    self.available = available
    self.dispose = dispose
    self.recordSession = recordSession
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
      if payload.data == Data("move-recipe".utf8) {
        return LocalizedStringResource.organizationUndoMoveRecipe.localized(for: self?.locale ?? .current)
      }
      if payload.data == Data("move-recipes".utf8) {
        return LocalizedStringResource.organizationUndoMoveRecipes.localized(for: self?.locale ?? .current)
      }
      return nil
    }
  }

  func requestMove(_ ids: Set<Recipe.ID>, to folder: Folder.ID?) {
    guard pendingMove == nil else { failed = true; return }
    pendingMove = Task {
      await move(ids, to: folder)
      pendingMove = nil
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
      failureMessage = .organizationUndoFailureMessage
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
    let previous = organization.snapshot
    organization.refresh()
    if previous != organization.snapshot { organization.organizationDidChange() }
    ready = available && history.session?.status.phase == .ready
    canUndo = ready && history.session?.status.canUndo == true
    canRedo = ready && history.session?.status.canRedo == true
    canDiscardRejectedCompensation = available && history.canDiscardRejectedCompensation
    if history.hasPendingCompensation {
      failed = true
      failureMessage = .organizationUndoFailureMessage
    } else if history.session?.status.issue != nil {
      failed = true
      failureMessage = ready ? .organizationUndoFailureMessage : .organizationUndoUnavailableMessage
    }
  }

  private func receive(_ result: HistorySubmissionResult) {
    switch result {
    case .accepted, .rejected: break
    case .failed, .unexecuted, .unresolved:
      failed = true
      failureMessage = .organizationUndoFailureMessage
    }
  }
}
