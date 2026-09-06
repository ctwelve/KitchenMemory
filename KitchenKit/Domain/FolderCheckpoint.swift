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
    let old = Set(evidence.receipts.filter { $0.authoredAt <= date.addingTimeInterval(-30 * 86_400) }.map(\.id))
    let eligible = Set(old.filter { candidate in
      evidence.graph.reachableNodes(from: [candidate]).allSatisfy { old.contains($0) }
    })
    guard !rawActionIDs.isDisjoint(with: eligible) else { return nil }
    let candidates = evidence.actions.filter { eligible.contains($0.id) }
    let groups = Dictionary(grouping: candidates.filter { $0.payload.compactableRegister != nil },
                            by: { $0.payload.compactableRegister })
    var retainedIDs = Set(candidates.filter { $0.payload.compactableRegister == nil }.map(\.id))
    for group in groups.values {
      retainedIDs.formUnion(evidence.graph.maximalNodes(among: group.map(\.id)))
    }
    let compact = OrganizationCheckpoint(
      receipts: evidence.receipts.filter { eligible.contains($0.id) },
      retained: candidates.filter { retainedIDs.contains($0.id) }
    )
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
