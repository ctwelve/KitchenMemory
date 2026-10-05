// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// One complete local append boundary from the frozen V3 persistence contract.
public enum CookingSessionTransaction: Equatable, Sendable {
  /// One complete root with no continuation source fields.
  case start(CookingSessionRootEvidence)
  /// One ordinary immutable Fact for lifecycle or authored cooking evidence.
  case activity(SessionFactEvidence)
  /// One immutable Closure sealing a complete observed Session frontier.
  case finish(SessionClosureEvidence)
  /// One Closure and matching deletion marker committed together locally.
  case finishAndDelete(SessionClosureEvidence, SessionDeletionEvidence)
  /// One deletion marker independent of Session lifecycle.
  case delete(SessionDeletionEvidence)
  /// One resolution per observed deletion, all belonging to the same Session and Kitchen.
  case restore([SessionDeletionResolutionEvidence])
  /// One narrow conflict-resolution Fact selecting among observed competing Closures.
  case resolveClosure(SessionFactEvidence)
  /// One complete new root naming both its source Session and source Closure.
  case continueSession(CookingSessionRootEvidence)
}

/// Failures validating complete append envelopes or persistence-placeholder evidence.
public enum CookingSessionRepositoryError: Error, Equatable {
  /// The supplied records do not form the transaction's required complete local boundary.
  case incompleteTransaction
  /// A stored or submitted envelope contains schema placeholders rather than complete evidence.
  case placeholderBearingEvidence
}

/// Domain-facing access to complete, classified Cooking Session evidence.
///
/// Implementations retain immutable evidence and use the deterministic Domain
/// projector for every read. No managed object or transport metadata crosses
/// this seam.
@MainActor
public protocol CookingSessionRepository: AnyObject {
  /// Appends the complete local transaction or throws before local acceptance completes.
  /// Evidence remains immutable. Local atomicity does not require managed CloudKit to
  /// deliver the remote transaction together; Logic owns exact-intention retry checks.
  func append(_ transaction: CookingSessionTransaction) throws
  /// Returns all retained evidence needed to prepare an idempotent command.
  /// Partial or conflicting evidence remains retained; nil means no evidence is known.
  func evidence(id: CookingSession.ID) throws -> SessionEvidence?
  /// Classifies retained evidence as readable, Unavailable, or requiring Recovery.
  /// Returns nil for unknown identity; no partial domain Session is fabricated.
  func session(id: CookingSession.ID) throws -> SessionProjectionResult?
  /// Reads every known Session classification routed to this Kitchen.
  /// Evidence without a root remains visible through its retained Kitchen routing.
  func sessions(in kitchenID: Kitchen.ID) throws -> [SessionProjectionResult]
  /// Reads classifications through retained root Recipe provenance, even when the source Recipe is hidden.
  func sessions(for recipeID: Recipe.ID) throws -> [SessionProjectionResult]
  /// Reads classifications through root Recipe provenance within the specified Kitchen.
  func sessions(
    for recipeID: Recipe.ID,
    in kitchenID: Kitchen.ID
  ) throws -> [SessionProjectionResult]
  /// Returns up to `limit` classifications with retained Closure evidence, newest descriptive Finish time first.
  /// Results can still be Unavailable or Recovery; Closure presence alone does not prove a valid Finished Session.
  /// A nonpositive limit returns no results.
  func finishedSessions(
    in kitchenID: Kitchen.ID,
    limit: Int
  ) throws -> [SessionProjectionResult]
  /// Reads retained deletion markers for a Kitchen without requiring a Session root.
  func deletions(in kitchenID: Kitchen.ID) throws -> [SessionDeletionEvidence]
  /// Reads retained deletion markers for a Session, independently of its lifecycle.
  func deletions(for sessionID: CookingSession.ID) throws -> [SessionDeletionEvidence]
  /// Reads every physical deletion envelope with this logical marker identity.
  /// Conflicting duplicates must remain available for classification rather than choosing one.
  func deletions(id: SessionDeletion.ID) throws -> [SessionDeletionEvidence]
  /// Reads retained resolution envelopes for an observed deletion marker.
  func restorations(
    for deletionID: SessionDeletion.ID
  ) throws -> [SessionDeletionResolutionEvidence]
}

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

struct CookingSessionTransactionRecords {
  var roots: [CookingSessionRootEvidence] = []
  var facts: [SessionFactEvidence] = []
  var closures: [SessionClosureEvidence] = []
  var deletions: [SessionDeletionEvidence] = []
  var restorations: [SessionDeletionResolutionEvidence] = []
}

extension CookingSessionTransaction {
  // The exhaustive switch is the public transaction vocabulary; splitting it
  // would obscure which physical rows each accepted intention appends.
  // swiftlint:disable:next cyclomatic_complexity
  func records() throws -> CookingSessionTransactionRecords {
    switch self {
    case let .start(root):
      guard root.sourceSessionID == nil, root.sourceClosureID == nil else {
        throw CookingSessionRepositoryError.incompleteTransaction
      }
      return CookingSessionTransactionRecords(roots: [root])
    case let .continueSession(root):
      guard root.sourceSessionID != nil, root.sourceClosureID != nil else {
        throw CookingSessionRepositoryError.incompleteTransaction
      }
      return CookingSessionTransactionRecords(roots: [root])
    case let .activity(fact):
      return CookingSessionTransactionRecords(facts: [fact])
    case let .resolveClosure(fact):
      guard fact.kind == SessionFact.Kind.conflictResolution.rawValue else {
        throw CookingSessionRepositoryError.incompleteTransaction
      }
      return CookingSessionTransactionRecords(facts: [fact])
    case let .finish(closure):
      return CookingSessionTransactionRecords(closures: [closure])
    case let .finishAndDelete(closure, deletion):
      guard closure.sessionID == deletion.sessionID,
            closure.kitchenID == deletion.kitchenID
      else { throw CookingSessionRepositoryError.incompleteTransaction }
      return CookingSessionTransactionRecords(
        closures: [closure],
        deletions: [deletion]
      )
    case let .delete(deletion):
      return CookingSessionTransactionRecords(deletions: [deletion])
    case let .restore(restorations):
      guard let first = restorations.first,
            restorations.allSatisfy({
              $0.sessionID == first.sessionID && $0.kitchenID == first.kitchenID
            })
      else { throw CookingSessionRepositoryError.incompleteTransaction }
      return CookingSessionTransactionRecords(restorations: restorations)
    }
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

func cookingSessionDeletionOrder(
  _ lhs: SessionDeletionEvidence,
  _ rhs: SessionDeletionEvidence
) -> Bool {
  if lhs.deletedAt != rhs.deletedAt { return lhs.deletedAt > rhs.deletedAt }
  return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
}
