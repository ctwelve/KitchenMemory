// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Reconstructive organization evidence with an explicit minimum retention promise.
public struct TagCheckpoint: Codable, Equatable, Sendable {
  public let id: UUID
  public let kitchenID: Kitchen.ID
  public let createdAt: Date
  public let antiResurrectionUntil: Date
  let evidence: OrganizationCheckpoint<TagChange>
}

extension TagLibrary {
  /// Compacts a causally complete frontier after at least 30 days of raw retention.
  /// Assignment dots, removal receipts, aliases, and neighbor ordering remain retained.
  /// Automatic maintenance opportunities and eventual expiry are separate policies.
  public func checkpoint(id: UUID = UUID(), at date: Date = Date()) throws -> TagCheckpoint? {
    let evidence = try tagBoundary { try OrganizationEvidence(actions, checkpoints: checkpointEvidence) }
    guard let compact = evidence.compact(rawIDs: rawActionIDs, at: date) else { return nil }
    // 1,827 days covers every five-year Gregorian interval, including leap days.
    return TagCheckpoint(id: id, kitchenID: kitchenID, createdAt: date,
                            antiResurrectionUntil: date.addingTimeInterval(1_827 * 86_400), evidence: compact)
  }
}
