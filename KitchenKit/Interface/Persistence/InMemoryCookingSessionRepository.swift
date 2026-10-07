// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Deterministic adapter for Logic tests and persistence-independent workflows.
@MainActor
public final class InMemoryCookingSessionRepository: CookingSessionRepository {
  private var evidenceBySession: [CookingSession.ID: SessionEvidence] = [:]

  /// Creates an empty main-actor evidence store with process-local lifetime and no durable persistence.
  public init() {}

  /// Appends the complete local transaction or throws before local acceptance completes.
  /// Evidence remains immutable. Local atomicity does not require managed CloudKit to
  /// deliver the remote transaction together; Logic owns exact-intention retry checks.
  public func append(_ transaction: CookingSessionTransaction) throws {
    let records = try transaction.records()
    try records.validateForPersistence()
    for root in records.roots {
      update(root.id) { $0.roots.append(root) }
    }
    for fact in records.facts {
      update(fact.sessionID) { $0.facts.append(fact) }
    }
    for closure in records.closures {
      update(closure.sessionID) { $0.closures.append(closure) }
    }
    for deletion in records.deletions {
      update(deletion.sessionID) { $0.deletions.append(deletion) }
    }
    for restoration in records.restorations {
      update(restoration.sessionID) { $0.restorations.append(restoration) }
    }
  }

  /// Classifies retained evidence as readable, Unavailable, or requiring Recovery.
  /// Returns nil for unknown identity; no partial domain Session is fabricated.
  public func session(id: CookingSession.ID) throws -> SessionProjectionResult? {
    evidenceBySession[id].map(SessionEvidenceProjector.project)
  }

  /// Returns all retained evidence for this Session, or nil when nothing is known.
  /// Partial or conflicting evidence is retained for retry preparation and explicit classification.
  public func evidence(id: CookingSession.ID) throws -> SessionEvidence? {
    evidenceBySession[id]
  }

  /// Reads every known Session classification routed to this Kitchen.
  /// Evidence without a root remains visible through its retained Kitchen routing.
  public func sessions(in kitchenID: Kitchen.ID) throws -> [SessionProjectionResult] {
    classifiedEvidence {
      $0.belongs(to: kitchenID)
    }
  }

  /// Reads classifications through retained root Recipe provenance, even when the source Recipe is hidden.
  public func sessions(for recipeID: Recipe.ID) throws -> [SessionProjectionResult] {
    classifiedEvidence {
      $0.roots.contains { $0.recipeID == recipeID }
    }
  }

  /// Reads classifications through root Recipe provenance within the specified Kitchen.
  public func sessions(
    for recipeID: Recipe.ID,
    in kitchenID: Kitchen.ID
  ) throws -> [SessionProjectionResult] {
    classifiedEvidence {
      $0.roots.contains { $0.recipeID == recipeID && $0.kitchenID == kitchenID }
    }
  }

  /// Returns up to `limit` classifications with retained Closure evidence, newest descriptive Finish time first.
  /// Results can still be Unavailable or Recovery; Closure presence alone does not prove a valid Finished Session.
  /// A nonpositive limit returns no results.
  public func finishedSessions(
    in kitchenID: Kitchen.ID,
    limit: Int
  ) throws -> [SessionProjectionResult] {
    guard limit > 0 else { return [] }
    return evidenceBySession.values.compactMap { evidence in
      guard evidence.belongs(to: kitchenID),
            let finishedAt = evidence.closures.map(\.finishedAt).max()
      else { return nil }
      return (evidence, finishedAt)
    }
      .sorted(by: finishedEvidenceOrder)
      .prefix(limit)
      .map { SessionEvidenceProjector.project($0.0) }
  }

  /// Reads retained deletion markers for a Kitchen without requiring a Session root.
  public func deletions(in kitchenID: Kitchen.ID) throws -> [SessionDeletionEvidence] {
    evidenceBySession.values.flatMap(\.deletions)
      .filter { $0.kitchenID == kitchenID }
      .sorted(by: cookingSessionDeletionOrder)
  }

  /// Reads retained deletion markers for a Session, independently of its lifecycle.
  public func deletions(for sessionID: CookingSession.ID) throws -> [SessionDeletionEvidence] {
    (evidenceBySession[sessionID]?.deletions ?? []).sorted(by: cookingSessionDeletionOrder)
  }

  /// Reads every physical deletion envelope with this logical marker identity.
  /// Conflicting duplicates must remain available for classification rather than choosing one.
  public func deletions(id: SessionDeletion.ID) throws -> [SessionDeletionEvidence] {
    evidenceBySession.values.flatMap(\.deletions)
      .filter { $0.id == id }
      .sorted(by: cookingSessionDeletionOrder)
  }

  /// Reads retained resolution envelopes for an observed deletion marker.
  public func restorations(
    for deletionID: SessionDeletion.ID
  ) throws -> [SessionDeletionResolutionEvidence] {
    evidenceBySession.values.flatMap(\.restorations)
      .filter { $0.deletionID == deletionID }
      .sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
  }

  private func update(
    _ sessionID: CookingSession.ID,
    operation: (inout SessionEvidence) -> Void
  ) {
    var evidence = evidenceBySession[sessionID] ?? SessionEvidence(sessionID: sessionID)
    operation(&evidence)
    evidenceBySession[sessionID] = evidence
  }

  private func classifiedEvidence(
    matching predicate: (SessionEvidence) -> Bool
  ) -> [SessionProjectionResult] {
    evidenceBySession.values.filter(predicate)
      .sorted { $0.sessionID.rawValue.uuidString < $1.sessionID.rawValue.uuidString }
      .map { SessionEvidenceProjector.project($0) }
  }
}

private extension SessionEvidence {
  func belongs(to kitchenID: Kitchen.ID) -> Bool {
    if !roots.isEmpty {
      return roots.contains { $0.kitchenID == kitchenID }
    }
    return kitchenIDs.contains(kitchenID)
  }
}

private extension SessionEvidence {
  var kitchenIDs: Set<Kitchen.ID> {
    // `belongs(to:)` consults this aggregate only when root authority is absent.
    Set(facts.map(\.kitchenID))
      .union(closures.map(\.kitchenID))
      .union(deletions.map(\.kitchenID))
      .union(restorations.map(\.kitchenID))
  }
}

private func finishedEvidenceOrder(
  _ lhs: (SessionEvidence, Date),
  _ rhs: (SessionEvidence, Date)
) -> Bool {
  if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
  return lhs.0.sessionID.rawValue.uuidString < rhs.0.sessionID.rawValue.uuidString
}
