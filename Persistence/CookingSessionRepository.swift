// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain

/// One complete local append boundary from the frozen V3 persistence contract.
public enum CookingSessionTransaction: Equatable, Sendable {
  case start(CookingSessionRootEvidence)
  case activity(SessionFactEvidence)
  case finish(SessionClosureEvidence)
  case finishAndDelete(SessionClosureEvidence, SessionDeletionEvidence)
  case delete(SessionDeletionEvidence)
  case restore([SessionDeletionResolutionEvidence])
  case resolveClosure(SessionFactEvidence)
  case continueSession(CookingSessionRootEvidence)
}

public enum CookingSessionRepositoryError: Error, Equatable {
  case incompleteTransaction
  case placeholderBearingEvidence
}

/// Domain-facing access to complete, classified Cooking Session evidence.
///
/// Implementations retain immutable evidence and use the deterministic Domain
/// projector for every read. No managed object or transport metadata crosses
/// this seam.
@MainActor
public protocol CookingSessionRepository: AnyObject {
  func append(_ transaction: CookingSessionTransaction) throws
  /// Returns the retained evidence needed by Logic to prepare an idempotent command.
  func evidence(id: CookingSession.ID) throws -> SessionEvidence?
  func session(id: CookingSession.ID) throws -> SessionProjectionResult?
  func sessions(in kitchenID: Kitchen.ID) throws -> [SessionProjectionResult]
  func sessions(for recipeID: Recipe.ID) throws -> [SessionProjectionResult]
  func sessions(
    for recipeID: Recipe.ID,
    in kitchenID: Kitchen.ID
  ) throws -> [SessionProjectionResult]
  func finishedSessions(
    in kitchenID: Kitchen.ID,
    limit: Int
  ) throws -> [SessionProjectionResult]
  func deletions(in kitchenID: Kitchen.ID) throws -> [SessionDeletionEvidence]
  func deletions(for sessionID: CookingSession.ID) throws -> [SessionDeletionEvidence]
  func deletions(id: SessionDeletion.ID) throws -> [SessionDeletionEvidence]
  func restorations(
    for deletionID: SessionDeletion.ID
  ) throws -> [SessionDeletionResolutionEvidence]
}

/// Deterministic adapter for Logic tests and persistence-independent workflows.
@MainActor
public final class InMemoryCookingSessionRepository: CookingSessionRepository {
  private var evidenceBySession: [CookingSession.ID: SessionEvidence] = [:]

  public init() {}

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

  public func session(id: CookingSession.ID) throws -> SessionProjectionResult? {
    evidenceBySession[id].map(SessionEvidenceProjector.project)
  }

  public func evidence(id: CookingSession.ID) throws -> SessionEvidence? {
    evidenceBySession[id]
  }

  public func sessions(in kitchenID: Kitchen.ID) throws -> [SessionProjectionResult] {
    classifiedEvidence {
      $0.belongs(to: kitchenID)
    }
  }

  public func sessions(for recipeID: Recipe.ID) throws -> [SessionProjectionResult] {
    classifiedEvidence {
      $0.roots.contains { $0.recipeID == recipeID }
    }
  }

  public func sessions(
    for recipeID: Recipe.ID,
    in kitchenID: Kitchen.ID
  ) throws -> [SessionProjectionResult] {
    classifiedEvidence {
      $0.roots.contains { $0.recipeID == recipeID && $0.kitchenID == kitchenID }
    }
  }

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

  public func deletions(in kitchenID: Kitchen.ID) throws -> [SessionDeletionEvidence] {
    evidenceBySession.values.flatMap(\.deletions)
      .filter { $0.kitchenID == kitchenID }
      .sorted(by: cookingSessionDeletionOrder)
  }

  public func deletions(for sessionID: CookingSession.ID) throws -> [SessionDeletionEvidence] {
    (evidenceBySession[sessionID]?.deletions ?? []).sorted(by: cookingSessionDeletionOrder)
  }

  public func deletions(id: SessionDeletion.ID) throws -> [SessionDeletionEvidence] {
    evidenceBySession.values.flatMap(\.deletions)
      .filter { $0.id == id }
      .sorted(by: cookingSessionDeletionOrder)
  }

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
