// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CryptoKit
import Foundation
import KitchenKit

struct AcceptanceObservation {
  let sessionID: CookingSession.ID
  let classification: String
  let roots: Int
  let facts: Int
  let closures: Int
  let deletions: Int
  let restorations: Int
  let digest: String

  var output: [String: Any] {
    [
      "session": sessionID.rawValue.uuidString,
      "classification": classification,
      "roots": roots,
      "facts": facts,
      "closures": closures,
      "deletions": deletions,
      "restorations": restorations,
      "digest": digest,
    ]
  }

  @MainActor
  static func read(
    sessionID: CookingSession.ID,
    repository: SwiftDataCookingSessionRepository
  ) throws -> AcceptanceObservation? {
    guard let evidence = try repository.evidence(id: sessionID),
          let result = try repository.session(id: sessionID)
    else { return nil }
    let classification: String
    switch result {
    case let .session(session):
      let disposition: String
      switch session.disposition {
      case .ordinary:
        disposition = "ordinary"
      case let .deleted(needsAttention):
        disposition = needsAttention ? "deleted-attention" : "deleted"
      }
      classification = "\(disposition)-\(session.lifecycle)"
    case .unavailable:
      classification = "unavailable"
    case .recovery:
      classification = "recovery"
    }
    let identifiers = evidence.roots.map(\.id.rawValue)
      + evidence.facts.map(\.id.rawValue)
      + evidence.closures.map(\.id.rawValue)
      + evidence.deletions.map(\.id.rawValue)
      + evidence.restorations.map(\.id.rawValue)
    let bytes = Data(identifiers.map(\.uuidString).sorted().joined(separator: "|").utf8)
    let digest = SHA256.hash(data: bytes).prefix(8)
      .map { String(format: "%02x", $0) }.joined()
    return AcceptanceObservation(
      sessionID: sessionID,
      classification: classification,
      roots: evidence.roots.count,
      facts: evidence.facts.count,
      closures: evidence.closures.count,
      deletions: evidence.deletions.count,
      restorations: evidence.restorations.count,
      digest: digest
    )
  }
}

enum AcceptanceExpectation {
  static func isSatisfied(
    scenario: AcceptanceScenario,
    checkpoint: String,
    observations: [AcceptanceObservation]
  ) -> Bool {
    switch (scenario, checkpoint) {
    case (.e1, "final"):
      return observations.count == 2
        && observations.contains { $0.classification.hasPrefix("ordinary-") && $0.roots >= 2 }
        && observations.contains { $0.classification == "recovery" && $0.roots >= 2 }
    case (.e2b, "final"), (.e4b, "final"):
      return observations.count == 1
        && observations[0].classification.hasPrefix("ordinary-")
        && observations[0].facts >= 2
    case (.e3, "final"):
      return observations.count == 1
        && observations[0].classification.hasPrefix("ordinary-")
    case (.e4a, "partial"):
      return observations.count == 1 && observations[0].classification == "unavailable"
    case (.e4a, "final"):
      return observations.count == 1
        && observations[0].classification == "ordinary-finished"
        && observations[0].closures >= 1
        && observations[0].deletions >= 1
        && observations[0].restorations >= 1
    case (.e5, "deleted"):
      return observations.count == 1
        && observations[0].classification.hasPrefix("deleted")
    case (.e5, "final"):
      return observations.count == 1
        && observations[0].classification.hasPrefix("ordinary-")
        && observations[0].facts >= 1
        && observations[0].deletions >= 1
        && observations[0].restorations >= 1
    case (.e7, "first"):
      return observations.count >= 1
    case (.e7, "final"):
      return observations.count == 2
    default:
      return false
    }
  }
}
