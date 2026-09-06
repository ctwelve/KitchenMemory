// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Reconstructive organization evidence with an explicit minimum retention promise.
public struct FolderCheckpoint: Codable, Equatable, Sendable {
  public let id: UUID
  public let kitchenID: Kitchen.ID
  public let createdAt: Date
  public let antiResurrectionUntil: Date
  let evidence: OrganizationCheckpoint<FolderChange>
}

extension FolderLibrary {
  /// Compacts a causally complete frontier after at least 30 days of raw retention.
  /// Structural history remains when needed for cycle fallback and neighbor ordering.
  /// Automatic maintenance opportunities and eventual expiry are separate policies.
  public func checkpoint(id: UUID = UUID(), at date: Date = Date()) throws -> FolderCheckpoint? {
    let evidence = try OrganizationEvidence(actions, checkpoints: checkpointEvidence)
    guard let compact = evidence.compact(rawIDs: rawActionIDs, at: date) else { return nil }
    // 1,827 days covers every five-year Gregorian interval, including leap days.
    return FolderCheckpoint(id: id, kitchenID: kitchenID, createdAt: date,
                            antiResurrectionUntil: date.addingTimeInterval(1_827 * 86_400), evidence: compact)
  }
}

extension FolderChange {
  var compactableRegister: String? {
    switch self {
    case let .rename(id, _): return "name:\(id.rawValue.uuidString)"
    case let .assign(recipeID, _): return "membership:\(recipeID.rawValue.uuidString)"
    case .ordering: return "folder-ordering"
    default: return nil
    }
  }
}
