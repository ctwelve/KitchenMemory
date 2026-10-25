// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import UndoKit

@MainActor
final class OrganizationHistoryHost: MainActorHistoryOperationHandler, HistoryHostLease {
  typealias Command = RecipeOrganizationHistoryChange
  typealias Effect = RecipeOrganizationHistoryChange

  struct Pending: Codable {
    let version: Int
    let delivery: RecipeOrganizationHistoryDelivery
    let inverse: Bool
    var terminalRejected: Bool
  }

  let scope: RecipeOrganizationHistoryScope
  private let repository: any RecipeOrganizationHistoryRepository
  private let pendingURL: URL
  private let sessionAdmission: (CookingSession.ID) -> Bool
  private(set) var pending: Pending?

  init(repository: any RecipeOrganizationHistoryRepository, scope: RecipeOrganizationHistoryScope, pendingURL: URL,
       sessionAdmission: @escaping (CookingSession.ID) -> Bool) {
    self.repository = repository
    self.scope = scope
    self.pendingURL = pendingURL
    self.sessionAdmission = sessionAdmission
  }

  func open(_ mode: HistoryOpenMode) async throws {
    if FileManager.default.fileExists(atPath: pendingURL.path) {
      let retained = try JSONDecoder().decode(Pending.self, from: Data(contentsOf: pendingURL))
      guard retained.version == 1, retained.delivery.scope == scope,
            retained.delivery.token.scope == scope.identity else { throw RecipeOrganizationHistoryError.invalidScope }
      pending = retained
    }
  }

  func close() async throws {}

  func apply(_ commands: [(UUID, Command)], context: HistoryOperationContext) async -> HistoryTypedOutcome<Effect> {
    execute(commands, context: context, inverse: false)
  }

  func undo(_ effects: [(UUID, Effect)], context: HistoryOperationContext) async -> HistoryTypedOutcome<Effect> {
    execute(effects, context: context, inverse: true)
  }

  func redo(_ effects: [(UUID, Effect)], context: HistoryOperationContext) async -> HistoryTypedOutcome<Effect> {
    execute(effects, context: context, inverse: true)
  }

  func outcome(for token: HistoryToken) async -> HistoryTypedOutcome<Effect> {
    do {
      guard let receipt = try repository.historyReceipt(for: token, in: scope) else {
        return pending?.terminalRejected == true && pending?.delivery.token == OrganizationHistoryToken(token)
          ? .rejected : .unresolved
      }
      if pending?.delivery.token == OrganizationHistoryToken(token) { try clearPending() }
      return receipt.outcome
    } catch { return .unresolved }
  }

  func clearPending() throws {
    if FileManager.default.fileExists(atPath: pendingURL.path) { try FileManager.default.removeItem(at: pendingURL) }
    pending = nil
  }

  func retryPending() -> HistoryTypedOutcome<Effect> {
    guard let pending else { return .unresolved }
    return execute([(pending.delivery.memberID, pending.delivery.change)],
      context: HistoryOperationContext(token: pending.delivery.token.value),
      inverse: pending.inverse, retainRejection: true)
  }

  private func recordRejection(inverse: Bool) -> HistoryTypedOutcome<Effect> {
    do {
      if inverse, var retained = pending {
        retained.terminalRejected = true
        try OrganizationCoding.encode(retained).write(to: pendingURL, options: .atomic)
        pending = retained
      } else { try clearPending() }
      return .rejected
    } catch { return .unresolved }
  }

  private func execute(_ changes: [(UUID, Effect)], context: HistoryOperationContext,
                       inverse: Bool, retainRejection: Bool = false) -> HistoryTypedOutcome<Effect> {
    guard changes.count == 1, let (memberID, change) = changes.first else { return .rejected }
    do {
      if let receipt = try repository.historyReceipt(for: context.token, in: scope) {
        if pending?.delivery.token == OrganizationHistoryToken(context.token) { try clearPending() }
        return receipt.outcome
      }
      let retained: Pending
      if let pending {
        guard pending.delivery.token == OrganizationHistoryToken(context.token),
              pending.delivery.memberID == memberID, pending.delivery.change == change else { return .unresolved }
        if pending.terminalRejected { return .rejected }
        retained = pending
      } else {
        let delivery = try repository.prepareHistoryDelivery(
          change, memberID: memberID, token: context.token, in: scope)
        retained = Pending(version: 1, delivery: delivery, inverse: inverse, terminalRejected: false)
        try FileManager.default.createDirectory(
          at: pendingURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try OrganizationCoding.encode(retained).write(to: pendingURL, options: .atomic)
        pending = retained
      }
      var affected = try repository.historySessionIDs(in: scope, generation: context.token.generation)
      if let sessionID = change.sessionProgress?.sessionID { affected.insert(sessionID) }
      guard affected.allSatisfy(sessionAdmission) else { return .unresolved }
      let receipt = try repository.acceptHistory(retained.delivery)
      try clearPending()
      return receipt.outcome
    } catch RecipeOrganizationHistoryError.ineligible {
      return recordRejection(inverse: inverse || retainRejection)
    } catch RecipeOrganizationHistoryError.invalidScope {
      return recordRejection(inverse: inverse || retainRejection)
    } catch { return .unresolved }
  }
}
