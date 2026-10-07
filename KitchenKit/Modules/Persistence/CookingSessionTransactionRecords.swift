// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

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

func cookingSessionDeletionOrder(
  _ lhs: SessionDeletionEvidence,
  _ rhs: SessionDeletionEvidence
) -> Bool {
  if lhs.deletedAt != rhs.deletedAt { return lhs.deletedAt > rhs.deletedAt }
  return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
}
