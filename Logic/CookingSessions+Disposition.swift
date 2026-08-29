// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import KitchenMemoryPersistence

@MainActor
extension CookingSessions {
  func performDelete(
    _ intention: DeleteCookingSessionIntention
  ) throws -> CookingSessionCommandResult {
    let evidence = try requiredEvidence(id: intention.sessionID)
    if let existing = evidence.deletions.first(where: { $0.id == intention.deletionID }) {
      guard evidence.deletions.filter({ $0.id == intention.deletionID }).allSatisfy({
        $0 == existing
      }),
        existing.sessionID == intention.sessionID,
        existing.kitchenID == kitchenID,
        existing.deletedAt == intention.deletedAt
      else { throw CookingSessionLogicError.intentionIdentityCollision }
      return try classifiedResult(id: intention.sessionID)
    }
    let projected = SessionEvidenceProjector.project(evidence)
    guard case .session = projected else { return attention(from: projected) }
    let deletion = try dispositionFactory.deletion(
      intention: intention,
      kitchenID: kitchenID,
      evidence: evidence
    )
    do {
      try sessionRepository.append(.delete(deletion))
    } catch {
      throw CookingSessionLogicError.sessionWriteFailed
    }
    return try classifiedResult(id: intention.sessionID)
  }

  func performRestore(
    _ intention: RestoreCookingSessionIntention
  ) throws -> CookingSessionCommandResult {
    let evidence = try requiredEvidence(id: intention.sessionID)
    guard !intention.observedDeletionIDs.isEmpty,
          Set(intention.observedDeletionIDs).count == intention.observedDeletionIDs.count
    else { throw CookingSessionLogicError.invalidIntention }
    let factory = dispositionFactory
    let observed = Set(intention.observedDeletionIDs)
    let retried = intention.observedDeletionIDs.compactMap { deletionID
      -> SessionDeletionResolutionEvidence? in
      let identifier = factory.resolutionID(commandID: intention.id, deletionID: deletionID)
      return evidence.restorations.first { $0.id == identifier }
    }
    if !retried.isEmpty {
      guard retried.count == intention.observedDeletionIDs.count,
            retried.allSatisfy({ resolution in
        resolution.sessionID == intention.sessionID
          && resolution.kitchenID == kitchenID
          && resolution.restoredAt == intention.restoredAt
          && observed.contains(resolution.deletionID)
      }) else { throw CookingSessionLogicError.intentionIdentityCollision }
      return try classifiedResult(id: intention.sessionID)
    }
    let projected = SessionEvidenceProjector.project(evidence)
    guard case let .session(session) = projected else { return attention(from: projected) }
    guard case .deleted = session.disposition else { return .attention(.restoreNotNeeded) }
    let resolved = Set(evidence.restorations.map(\.deletionID))
    let unresolved = Dictionary(grouping: evidence.deletions, by: \SessionDeletionEvidence.id)
      .compactMap { $0.value.first }
      .filter { !resolved.contains($0.id) }
      .sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
    guard !unresolved.isEmpty else { return .attention(.restoreNotNeeded) }
    guard unresolved.map(\.id) == intention.observedDeletionIDs else {
      return .attention(.competingDeletions(unresolved.map(\.id)))
    }
    let restorations = try factory.restorations(
      intention: intention,
      kitchenID: kitchenID,
      deletions: unresolved,
      evidence: evidence
    )
    do {
      try sessionRepository.append(.restore(restorations))
    } catch {
      throw CookingSessionLogicError.sessionWriteFailed
    }
    return try classifiedResult(id: intention.sessionID)
  }
}
