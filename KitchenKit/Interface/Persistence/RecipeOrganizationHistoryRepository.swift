// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import UndoKit

/// Domain-owned stable intent and anchor. Its encoded meaning belongs to KitchenKit.
public struct RecipeOrganizationHistoryChange: Codable, Equatable, Sendable {
  let anchorID: UUID
  let recipeID: Recipe.ID
  let before: Folder.ID?
  let after: Folder.ID?
  let baseline: Data
  let folderBaseline: Data

  var inverse: Self {
    Self(anchorID: anchorID, recipeID: recipeID, before: after, after: before,
         baseline: baseline, folderBaseline: folderBaseline)
  }
}

/// An exact frozen transaction retained locally before attempting domain acceptance.
public struct RecipeOrganizationHistoryDelivery: Codable, Equatable, Sendable {
  let scope: RecipeOrganizationHistoryScope
  let token: OrganizationHistoryToken
  let memberID: UUID
  let change: RecipeOrganizationHistoryChange
  let command: RecipeOrganizationCommand
  let beforeWitness: Data
}

/// Canonical accepted evidence, written atomically with the organization change.
public struct RecipeOrganizationHistoryReceipt: Codable, Equatable, Sendable {
  let delivery: RecipeOrganizationHistoryDelivery
  let afterWitness: Data

  var outcome: HistoryTypedOutcome<RecipeOrganizationHistoryChange> {
    .accepted([
      HistoryTypedEffect(memberID: delivery.memberID, undo: delivery.change.inverse, redo: delivery.change),
    ])
  }
}

/// Public organization/recovery seam; implementations own guarded atomic domain acceptance.
@MainActor
public protocol RecipeOrganizationHistoryRepository: RecipeOrganizationRepository {
  func prepareHistoryMove(_ recipeID: Recipe.ID, to folderID: Folder.ID?,
                          in scope: RecipeOrganizationHistoryScope) throws -> RecipeOrganizationHistoryChange?
  func prepareHistoryDelivery(_ change: RecipeOrganizationHistoryChange, memberID: UUID, token: HistoryToken,
                              in scope: RecipeOrganizationHistoryScope) throws -> RecipeOrganizationHistoryDelivery
  func acceptHistory(_ delivery: RecipeOrganizationHistoryDelivery) throws -> RecipeOrganizationHistoryReceipt
  func recoverHistory(_ delivery: RecipeOrganizationHistoryDelivery) throws -> RecipeOrganizationHistoryReceipt
  func historyReceipt(for token: HistoryToken, in scope: RecipeOrganizationHistoryScope)
    throws -> RecipeOrganizationHistoryReceipt?
  func historyIsEligible(in scope: RecipeOrganizationHistoryScope, generation: UUID) throws -> Bool
}

struct OrganizationHistoryToken: Codable, Equatable, Sendable {
  let scope: UUID
  let generation: UUID
  let sequence: Int64
  let command: UUID

  init(_ value: HistoryToken) {
    scope = value.scope; generation = value.generation; sequence = value.sequence; command = value.command
  }
  var value: HistoryToken { HistoryToken(scope: scope, generation: generation, sequence: sequence, command: command) }
  var recoveryReceiptID: UUID { derivedID(namespace: receiptID, kind: "recovery", source: receiptID) }
  var receiptID: UUID {
    derivedID(namespace: generation, kind: "organization-history-receipt/\(scope)/\(sequence)", source: command)
  }
}
