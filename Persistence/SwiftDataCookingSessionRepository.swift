// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain
import SwiftData

/// SwiftData-backed immutable V3 Cooking Session evidence repository.
@MainActor
public final class SwiftDataCookingSessionRepository: CookingSessionRepository {
  private let context: ModelContext

  public init(modelContainer: ModelContainer) {
    context = ModelContext(modelContainer)
  }

  private init(context: ModelContext) {
    self.context = context
  }

  public func append(_ transaction: CookingSessionTransaction) throws {
    let records = try transaction.records()
    try records.validateForPersistence()
    try performIsolatedWrite { writer in
      writer.insert(records)
    }
  }

  public func session(id: CookingSession.ID) throws -> SessionProjectionResult? {
    let stored = try storedEvidence(sessionID: id)
    guard !stored.evidence.isEmpty else { return nil }
    return stored.projection
  }

  public func evidence(id: CookingSession.ID) throws -> SessionEvidence? {
    let stored = try storedEvidence(sessionID: id)
    return stored.evidence.isEmpty ? nil : stored.evidence
  }

  public func sessions(in kitchenID: Kitchen.ID) throws -> [SessionProjectionResult] {
    try storedEvidence(in: kitchenID)
      .sorted { $0.evidence.sessionID.rawValue.uuidString
        < $1.evidence.sessionID.rawValue.uuidString }
      .map(\.projection)
  }

  private func storedEvidence(in kitchenID: Kitchen.ID) throws -> [StoredSessionEvidence] {
    let identifier = kitchenID.rawValue
    var ids = Set(try context.fetch(
      FetchDescriptor<CookingSessionRecord>(predicate: #Predicate { $0.kitchenID == identifier })
    ).map(\.id))
    ids.formUnion(try context.fetch(
      FetchDescriptor<SessionFactRecord>(predicate: #Predicate { $0.kitchenID == identifier })
    ).map(\.sessionID))
    ids.formUnion(try context.fetch(
      FetchDescriptor<SessionClosureRecord>(predicate: #Predicate { $0.kitchenID == identifier })
    ).map(\.sessionID))
    ids.formUnion(try context.fetch(
      FetchDescriptor<SessionDeletionRecord>(predicate: #Predicate { $0.kitchenID == identifier })
    ).map(\.sessionID))
    ids.formUnion(try context.fetch(
      FetchDescriptor<SessionDeletionResolutionRecord>(
        predicate: #Predicate { $0.kitchenID == identifier }
      )
    ).map(\.sessionID))
    return try ids.map {
      try storedEvidence(sessionID: .init(rawValue: $0))
    }.filter { $0.evidence.belongs(to: kitchenID) }
  }

  public func sessions(for recipeID: Recipe.ID) throws -> [SessionProjectionResult] {
    let identifier = recipeID.rawValue
    let ids = Set(try context.fetch(
      FetchDescriptor<CookingSessionRecord>(predicate: #Predicate { $0.recipeID == identifier })
    ).map(\.id))
    return try classify(sessionIDs: ids)
  }

  public func sessions(
    for recipeID: Recipe.ID,
    in kitchenID: Kitchen.ID
  ) throws -> [SessionProjectionResult] {
    let recipeIdentifier = recipeID.rawValue
    let kitchenIdentifier = kitchenID.rawValue
    let ids = Set(try context.fetch(
      FetchDescriptor<CookingSessionRecord>(predicate: #Predicate {
        $0.recipeID == recipeIdentifier && $0.kitchenID == kitchenIdentifier
      })
    ).map(\.id))
    return try classify(sessionIDs: ids)
  }

  public func finishedSessions(
    in kitchenID: Kitchen.ID,
    limit: Int
  ) throws -> [SessionProjectionResult] {
    guard limit > 0 else { return [] }
    return try storedEvidence(in: kitchenID).compactMap {
      stored -> (StoredSessionEvidence, Date)? in
      guard let finishedAt = stored.evidence.closures.map(\.finishedAt).max()
      else { return nil }
      return (stored, finishedAt)
    }
      .sorted { lhs, rhs in
        if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
        return lhs.0.evidence.sessionID.rawValue.uuidString
          < rhs.0.evidence.sessionID.rawValue.uuidString
      }
      .prefix(limit)
      .map(\.0.projection)
  }

  public func deletions(in kitchenID: Kitchen.ID) throws -> [SessionDeletionEvidence] {
    let identifier = kitchenID.rawValue
    let records = try context.fetch(
      FetchDescriptor<SessionDeletionRecord>(predicate: #Predicate { $0.kitchenID == identifier })
    )
    return try completeDeletionEvidence(records)
  }

  public func deletions(for sessionID: CookingSession.ID) throws -> [SessionDeletionEvidence] {
    let identifier = sessionID.rawValue
    let records = try context.fetch(
      FetchDescriptor<SessionDeletionRecord>(predicate: #Predicate { $0.sessionID == identifier })
    )
    return try completeDeletionEvidence(records)
  }

  public func deletions(id: SessionDeletion.ID) throws -> [SessionDeletionEvidence] {
    let identifier = id.rawValue
    let records = try context.fetch(
      FetchDescriptor<SessionDeletionRecord>(predicate: #Predicate { $0.id == identifier })
    )
    return try completeDeletionEvidence(records)
  }

  public func restorations(
    for deletionID: SessionDeletion.ID
  ) throws -> [SessionDeletionResolutionEvidence] {
    let identifier = deletionID.rawValue
    let records = try context.fetch(
      FetchDescriptor<SessionDeletionResolutionRecord>(
        predicate: #Predicate { $0.deletionID == identifier }
      )
    )
    let evidence = records.map(\.evidence)
    guard evidence.allSatisfy(\.isComplete) else {
      throw CookingSessionRepositoryError.placeholderBearingEvidence
    }
    return evidence.sorted {
      $0.id.rawValue.uuidString < $1.id.rawValue.uuidString
    }
  }

  private func completeDeletionEvidence(
    _ records: [SessionDeletionRecord]
  ) throws -> [SessionDeletionEvidence] {
    let evidence = records.map(\.evidence)
    guard evidence.allSatisfy(\.isComplete) else {
      throw CookingSessionRepositoryError.placeholderBearingEvidence
    }
    return evidence.sorted(by: cookingSessionDeletionOrder)
  }

  private func performIsolatedWrite(
    _ operation: (SwiftDataCookingSessionRepository) throws -> Void
  ) throws {
    let writerContext = ModelContext(context.container)
    let writer = SwiftDataCookingSessionRepository(context: writerContext)
    do {
      try operation(writer)
      try writerContext.save()
    } catch {
      writerContext.rollback()
      throw error
    }
  }

  private func insert(_ records: CookingSessionTransactionRecords) {
    records.roots.forEach { context.insert(CookingSessionRecord($0)) }
    records.facts.forEach { context.insert(SessionFactRecord($0)) }
    records.closures.forEach { context.insert(SessionClosureRecord($0)) }
    records.deletions.forEach { context.insert(SessionDeletionRecord($0)) }
    records.restorations.forEach {
      context.insert(SessionDeletionResolutionRecord($0))
    }
  }

  private func classify(sessionIDs: Set<UUID>) throws -> [SessionProjectionResult] {
    try sessionIDs.sorted { $0.uuidString < $1.uuidString }.map {
      try storedEvidence(sessionID: .init(rawValue: $0)).projection
    }
  }

  private func storedEvidence(sessionID: CookingSession.ID) throws -> StoredSessionEvidence {
    let identifier = sessionID.rawValue
    let roots = try context.fetch(
      FetchDescriptor<CookingSessionRecord>(predicate: #Predicate { $0.id == identifier })
    ).map(\.evidence)
    let facts = try context.fetch(
      FetchDescriptor<SessionFactRecord>(predicate: #Predicate { $0.sessionID == identifier })
    ).map(\.evidence)
    let closures = try context.fetch(
      FetchDescriptor<SessionClosureRecord>(predicate: #Predicate { $0.sessionID == identifier })
    ).map(\.evidence)
    let deletions = try context.fetch(
      FetchDescriptor<SessionDeletionRecord>(predicate: #Predicate { $0.sessionID == identifier })
    ).map(\.evidence)
    let restorations = try context.fetch(
      FetchDescriptor<SessionDeletionResolutionRecord>(
        predicate: #Predicate { $0.sessionID == identifier }
      )
    ).map(\.evidence)
    let evidence = SessionEvidence(
      sessionID: sessionID,
      roots: roots,
      facts: facts,
      closures: closures,
      deletions: deletions,
      restorations: restorations
    )
    return StoredSessionEvidence(
      evidence: evidence,
      containsPlaceholder: !roots.allSatisfy(\.isComplete)
        || !facts.allSatisfy(\.isComplete)
        || !closures.allSatisfy(\.isComplete)
        || !deletions.allSatisfy(\.isComplete)
        || !restorations.allSatisfy(\.isComplete)
    )
  }
}

private extension SessionEvidence {
  var isEmpty: Bool {
    roots.isEmpty && facts.isEmpty && closures.isEmpty
      && deletions.isEmpty && restorations.isEmpty
  }

  func belongs(to kitchenID: Kitchen.ID) -> Bool {
    if !roots.isEmpty {
      return roots.contains { $0.kitchenID == kitchenID }
    }
    let kitchenIDs = Set(facts.map(\.kitchenID))
      .union(closures.map(\.kitchenID))
      .union(deletions.map(\.kitchenID))
      .union(restorations.map(\.kitchenID))
    return kitchenIDs.contains(kitchenID)
  }
}

private extension CookingSessionRecord {
  convenience init(_ root: CookingSessionRootEvidence) {
    self.init(
      id: root.id.rawValue,
      kitchenID: root.kitchenID.rawValue,
      recipeID: root.recipeID.rawValue,
      recipeRevisionID: root.recipeRevisionID.rawValue,
      startedAt: root.startedAt,
      snapshotFormatVersion: root.snapshotFormatVersion,
      snapshotData: root.snapshotData,
      snapshotDigest: root.snapshotDigest,
      sourceSessionID: root.sourceSessionID?.rawValue,
      sourceClosureID: root.sourceClosureID?.rawValue
    )
  }
}

private extension SessionFactRecord {
  convenience init(_ fact: SessionFactEvidence) {
    self.init(
      id: fact.id.rawValue,
      sessionID: fact.sessionID.rawValue,
      kitchenID: fact.kitchenID.rawValue,
      kind: fact.kind,
      targetSnapshotElementID: fact.targetSnapshotElementID,
      authoredAt: fact.authoredAt,
      causalHeadsFormatVersion: fact.causalHeadsFormatVersion,
      causalHeadsData: fact.causalHeadsData,
      payloadFormatVersion: fact.payloadFormatVersion,
      payloadData: fact.payloadData,
      payloadDigest: fact.payloadDigest
    )
  }
}

private extension SessionClosureRecord {
  convenience init(_ closure: SessionClosureEvidence) {
    self.init(
      id: closure.id.rawValue,
      sessionID: closure.sessionID.rawValue,
      kitchenID: closure.kitchenID.rawValue,
      finishedAt: closure.finishedAt,
      causalHeadsFormatVersion: closure.causalHeadsFormatVersion,
      causalHeadsData: closure.causalHeadsData,
      snapshotFormatVersion: closure.snapshotFormatVersion,
      snapshotDigest: closure.snapshotDigest,
      projectionFormatVersion: closure.projectionFormatVersion,
      projectionDigest: closure.projectionDigest,
      outcomeFormatVersion: closure.outcomeFormatVersion,
      outcomeData: closure.outcomeData
    )
  }
}

private extension SessionDeletionRecord {
  convenience init(_ deletion: SessionDeletionEvidence) {
    self.init(
      id: deletion.id.rawValue,
      sessionID: deletion.sessionID.rawValue,
      kitchenID: deletion.kitchenID.rawValue,
      deletedAt: deletion.deletedAt,
      sessionHeadsFormatVersion: deletion.sessionHeadsFormatVersion,
      sessionHeadsData: deletion.sessionHeadsData,
      dispositionHeadsFormatVersion: deletion.dispositionHeadsFormatVersion,
      dispositionHeadsData: deletion.dispositionHeadsData
    )
  }
}

private extension SessionDeletionResolutionRecord {
  convenience init(_ restoration: SessionDeletionResolutionEvidence) {
    self.init(
      id: restoration.id.rawValue,
      deletionID: restoration.deletionID.rawValue,
      sessionID: restoration.sessionID.rawValue,
      kitchenID: restoration.kitchenID.rawValue,
      restoredAt: restoration.restoredAt,
      dispositionHeadsFormatVersion: restoration.dispositionHeadsFormatVersion,
      dispositionHeadsData: restoration.dispositionHeadsData
    )
  }
}
