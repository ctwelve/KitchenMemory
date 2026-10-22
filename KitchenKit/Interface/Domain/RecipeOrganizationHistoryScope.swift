// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// The initiating device-local scene's complete organization-history ownership.
public struct RecipeOrganizationHistoryScope: Codable, Equatable, Sendable {
  public let ownerID: KitchenOwner.ID
  public let storeID: String
  public let kitchenID: Kitchen.ID
  public let logicalSceneID: UUID

  /// Restore these identities together; a replacement scene must use a different identity.
  public init(ownerID: KitchenOwner.ID, storeID: String, kitchenID: Kitchen.ID, logicalSceneID: UUID) {
    self.ownerID = ownerID
    self.storeID = storeID
    self.kitchenID = kitchenID
    self.logicalSceneID = logicalSceneID
  }

  var identity: UUID {
    derivedID(namespace: kitchenID.rawValue,
      kind: "organization-history/\(ownerID.rawValue.utf8.count):\(ownerID.rawValue)/\(storeID)",
      source: logicalSceneID)
  }
  var workingIdentity: UUID { derivedID(namespace: identity, kind: "working", source: identity) }
}

/// Organization history cannot authorize an unavailable Recipe, target, or stale observation.
public enum RecipeOrganizationHistoryError: Error, Equatable {
  case notOpen
  case singleRecipeRequired
  case invalidScope
  case ineligible
  case invalidEvidence
}
