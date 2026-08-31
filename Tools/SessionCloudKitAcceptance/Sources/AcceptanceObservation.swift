// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CryptoKit
import Foundation
import KitchenKit

enum AcceptanceCheckpoint: String {
  case deleted
  case final
  case first
  case partial
}

enum AcceptanceClassification: String {
  case deletedActive = "deleted-active"
  case deletedAttentionActive = "deleted-attention-active"
  case deletedAttentionFinished = "deleted-attention-finished"
  case deletedAttentionStopped = "deleted-attention-stopped"
  case deletedFinished = "deleted-finished"
  case deletedStopped = "deleted-stopped"
  case ordinaryActive = "ordinary-active"
  case ordinaryFinished = "ordinary-finished"
  case ordinaryStopped = "ordinary-stopped"
  case recovery
  case unavailable
}

struct AcceptanceObservation {
  let sessionID: CookingSession.ID
  let classification: AcceptanceClassification
  let evidence: SessionEvidence
  let digest: String

  var output: [String: Any] {
    [
      "session": sessionID.rawValue.uuidString,
      "classification": classification.rawValue,
      "roots": evidence.roots.count,
      "facts": evidence.facts.count,
      "closures": evidence.closures.count,
      "deletions": evidence.deletions.count,
      "restorations": evidence.restorations.count,
      "digest": digest,
    ]
  }

  @MainActor
  static func read(
    sessionID: CookingSession.ID,
    repository: any CookingSessionRepository
  ) throws -> AcceptanceObservation? {
    guard let evidence = try repository.evidence(id: sessionID),
          let result = try repository.session(id: sessionID)
    else { return nil }
    let classification: AcceptanceClassification
    switch result {
    case let .session(session):
      classification = classify(session)
    case .unavailable:
      classification = .unavailable
    case .recovery:
      classification = .recovery
    }
    let rows = evidence.roots.map { String(reflecting: $0) }
      + evidence.facts.map { String(reflecting: $0) }
      + evidence.closures.map { String(reflecting: $0) }
      + evidence.deletions.map { String(reflecting: $0) }
      + evidence.restorations.map { String(reflecting: $0) }
    let bytes = Data(rows.sorted().joined(separator: "|").utf8)
    let digest = SHA256.hash(data: bytes).prefix(8)
      .map { String(format: "%02x", $0) }.joined()
    return AcceptanceObservation(
      sessionID: sessionID,
      classification: classification,
      evidence: evidence,
      digest: digest
    )
  }

  func matches(_ expected: AcceptanceObservation) -> Bool {
    sessionID == expected.sessionID
      && classification == expected.classification
      && evidence.hasSameRows(as: expected.evidence)
  }

  private static func classify(
    _ session: CookingSessionProjection
  ) -> AcceptanceClassification {
    switch (session.disposition, session.lifecycle) {
    case (.ordinary, .active): .ordinaryActive
    case (.ordinary, .stopped): .ordinaryStopped
    case (.ordinary, .finished): .ordinaryFinished
    case (.deleted(needsAttention: false), .active): .deletedActive
    case (.deleted(needsAttention: false), .stopped): .deletedStopped
    case (.deleted(needsAttention: false), .finished): .deletedFinished
    case (.deleted(needsAttention: true), .active): .deletedAttentionActive
    case (.deleted(needsAttention: true), .stopped): .deletedAttentionStopped
    case (.deleted(needsAttention: true), .finished): .deletedAttentionFinished
    }
  }
}

struct AcceptanceExpectation {
  let observations: [AcceptanceObservation]

  func isSatisfied(by actual: [AcceptanceObservation]) -> Bool {
    actual.count == observations.count
      && observations.allSatisfy { expected in
        actual.contains { $0.matches(expected) }
      }
  }
}

private extension SessionEvidence {
  func hasSameRows(as other: SessionEvidence) -> Bool {
    sessionID == other.sessionID
      && roots.unorderedElementsEqual(other.roots)
      && facts.unorderedElementsEqual(other.facts)
      && closures.unorderedElementsEqual(other.closures)
      && deletions.unorderedElementsEqual(other.deletions)
      && restorations.unorderedElementsEqual(other.restorations)
  }
}

private extension Array where Element: Equatable {
  func unorderedElementsEqual(_ other: [Element]) -> Bool {
    guard count == other.count else { return false }
    var unmatched = other
    for element in self {
      guard let index = unmatched.firstIndex(of: element) else { return false }
      unmatched.remove(at: index)
    }
    return unmatched.isEmpty
  }
}
