// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import UndoKit

/// Durable organization history for one initiating logical scene. KitchenKit owns
/// meaning and recovery; the application attaches native presentation to `session`.
@MainActor
public final class RecipeOrganizationHistory {
  public static let actionPresentationFamily = "kitchenmemory.recipe-organization.action"
  public private(set) var session: HistorySession?
  public var hasPendingCompensation: Bool { host?.pending?.inverse == true }
  /// Only a durably proved rejection can be discarded; ambiguous effects require recovery.
  public var canDiscardRejectedCompensation: Bool {
    host?.pending?.inverse == true && host?.pending?.terminalRejected == true
  }

  private let repository: any RecipeOrganizationHistoryRepository
  private let sessions: HistorySessions
  private let sessionAdmission: (CookingSession.ID) -> Bool
  private var host: OrganizationHistoryHost?
  private var operation: HistoryOperation<RecipeOrganizationHistoryChange>?

  public init(repository: any RecipeOrganizationHistoryRepository, sessions: HistorySessions = HistorySessions(),
              sessionAdmission: @escaping (CookingSession.ID) -> Bool = { _ in true }) {
    self.repository = repository
    self.sessions = sessions
    self.sessionAdmission = sessionAdmission
  }

  /// Session whose frozen change is still awaiting a conclusive result.
  public var pendingSessionID: CookingSession.ID? { host?.pending?.delivery.change.sessionProgress?.sessionID }

  /// Discovers unresolved Session delivery before opening any scene. Unreadable
  /// recovery evidence throws and must continue to block ordinary delivery.
  public static func pendingSessionID(in scope: RecipeOrganizationHistoryScope, historyURL: URL)
    throws -> CookingSession.ID? {
    try OrganizationHistoryHost.readPending(at: historyURL.appendingPathExtension("organization-pending.json"),
      scope: scope)?.delivery.change.sessionProgress?.sessionID
  }

  /// Pending domain work temporarily withholds this scene's app history without deleting it.
  public var sessionDeliveryIsBlocked: Bool {
    guard let host, let generation = session?.snapshot.generation else { return false }
    guard let ids = try? repository.historySessionIDs(in: host.scope, generation: generation) else { return true }
    return ids.contains { !sessionAdmission($0) }
  }

  /// Opens existing history without replay; missing existing local evidence is never replaced.
  public func open(scope: RecipeOrganizationHistoryScope, historyURL: URL) async throws {
    guard session == nil else { throw RecipeOrganizationHistoryError.invalidScope }
    let host = OrganizationHistoryHost(repository: repository, scope: scope,
      pendingURL: historyURL.appendingPathExtension("organization-pending.json"), sessionAdmission: sessionAdmission)
    let operation = try HistoryOperation(operation: "kitchenmemory.recipe-organization", commandCodec: .json(),
      effectCodec: .json(), handler: host, fingerprint: { try OrganizationCoding.digest($0) }, metadata: { changes in
        let name: String
        if changes.first?.sessionProgress != nil {
          name = "session-progress"
        } else if let tag = changes.first?.tagChange {
          name = tag.adding ? "add-tag" : "remove-tag"
        } else {
          let changedRecipeCount = changes.reduce(0) { $0 + $1.changedMembers.count }
          name = changedRecipeCount == 1 ? "move-recipe" : "move-recipes"
        }
        return HistoryOperationMetadata(presentation: HistoryPayload(
          family: "kitchenmemory.recipe-organization.action", data: Data(name.utf8)))
      })
    let existing = FileManager.default.fileExists(atPath: historyURL.path)
      || FileManager.default.fileExists(atPath: historyURL.appendingPathExtension("organization-pending.json").path)
    let session = await sessions.open(configuration: HistorySessionConfiguration(historyURL: historyURL,
      scope: scope.identity, workingIdentity: scope.workingIdentity, mode: existing ? .existing : .create,
      limits: HistoryLimits(maxUndoGroups: 100)), lease: host, operations: [operation.erased])
    self.host = host
    self.operation = operation
    self.session = session
    if session.status.phase == .ready {
      do { _ = try await invalidateInterference() } catch {
        await close()
        throw error
      }
    }
  }

  /// Moves the selected saved Recipes as one atomic, undoable history group.
  public func move(_ recipeIDs: Set<Recipe.ID>, to folderID: Folder.ID?) async throws -> HistorySubmissionResult {
    guard let session, let host, let operation else { throw RecipeOrganizationHistoryError.notOpen }
    _ = try await invalidateInterference()
    guard host.pending == nil, !sessionDeliveryIsBlocked else { throw RecipeOrganizationHistoryError.ineligible }
    guard let change = try repository.prepareHistoryMove(recipeIDs, to: folderID, in: host.scope)
    else { return .rejected }
    return await (try session.commands(for: operation)).submit(change)
  }

  /// Adds or removes one Tag for the changed selected Recipes as one accepted group.
  public func classify(_ recipeIDs: Set<Recipe.ID>, tagID: Tag.ID, adding: Bool)
    async throws -> HistorySubmissionResult {
    guard let session, let host, let operation else { throw RecipeOrganizationHistoryError.notOpen }
    _ = try await invalidateInterference()
    guard host.pending == nil, !sessionDeliveryIsBlocked else { throw RecipeOrganizationHistoryError.ineligible }
    guard let change = try repository.prepareHistoryTags(recipeIDs, tagID: tagID, adding: adding, in: host.scope)
    else { return .rejected }
    return await (try session.commands(for: operation)).submit(change)
  }

  /// Records one accepted resulting progress state in the initiating scene's timeline.
  public func progress(_ sessionID: CookingSession.ID, to progress: SessionProgress)
    async throws -> HistorySubmissionResult {
    guard let session, let host, let operation else { throw RecipeOrganizationHistoryError.notOpen }
    _ = try await invalidateInterference()
    guard host.pending == nil, !sessionDeliveryIsBlocked else { throw RecipeOrganizationHistoryError.ineligible }
    guard sessionAdmission(sessionID) else { throw RecipeOrganizationHistoryError.ineligible }
    guard let change = try repository.prepareHistoryProgress(sessionID, to: progress, in: host.scope)
    else { return .rejected }
    return await (try session.commands(for: operation)).submit(change)
  }

  public func undo() async -> HistorySubmissionResult {
    guard let session, !sessionDeliveryIsBlocked else { return .rejected }
    return await session.undo()
  }

  public func redo() async -> HistorySubmissionResult {
    guard let session, !sessionDeliveryIsBlocked else { return .rejected }
    return await session.redo()
  }

  /// Resolves accepted domain receipts and retires history affected by external evidence.
  public func reconcile() async -> HistorySubmissionResult? {
    guard let session else { return nil }
    let result = await session.reconcile()
    do { _ = try await invalidateInterference() } catch {
      await close()
      return .unresolved(historyFailure(error))
    }
    return result
  }

  /// Retries the exact frozen domain transaction and token. A previously rejected
  /// inverse stays retired; completing its retry never invents a Redo registration.
  public func retryPending() async throws -> HistorySubmissionResult? {
    guard let host, let session else { throw RecipeOrganizationHistoryError.notOpen }
    guard let pending = host.pending else { return nil }
    let outcome = host.retryPending()
    if pending.terminalRejected {
      guard case .rejected = outcome else { throw RecipeOrganizationHistoryError.ineligible }
      _ = try repository.recoverHistory(pending.delivery)
      _ = try session.advanced.clearHistory(adopting: HistoryPayload(
        family: "kitchenmemory.recipe-organization.baseline", data: Data("recovered-compensation".utf8)))
      try host.clearPending()
      return nil
    }
    let result = await session.reconcile()
    if case .rejected = result, host.pending?.inverse == false { try host.clearPending() }
    return result
  }

  /// Explicitly retires a proved failed inverse. Current Recipe organization is retained.
  public func discardRejectedCompensation() async throws {
    guard let session, let host else { throw RecipeOrganizationHistoryError.notOpen }
    guard canDiscardRejectedCompensation, let pending = host.pending,
          case .rejected = await host.outcome(for: pending.delivery.token.value) else {
      throw RecipeOrganizationHistoryError.ineligible
    }
    _ = await session.reconcile()
    _ = try session.advanced.clearHistory(adopting: HistoryPayload(
      family: "kitchenmemory.recipe-organization.baseline", data: Data("discarded-compensation".utf8)))
    try host.clearPending()
  }

  public func close() async {
    await session?.close()
    session = nil
    operation = nil
    host = nil
  }

  private func invalidateInterference() async throws -> Bool {
    guard let session, let host, session.status.phase == .ready, let generation = session.snapshot.generation,
          !(try repository.historyIsEligible(in: host.scope, generation: generation)) else { return false }
    _ = try session.advanced.clearHistory(adopting: HistoryPayload(
      family: "kitchenmemory.recipe-organization.baseline", data: Data("external-evidence".utf8)))
    return true
  }
}

private func historyFailure(_ error: Error) -> HistoryFailure {
  HistoryFailure(.storage, stage: .delivery, disposition: .suspended, underlyingDescription: String(describing: error))
}
