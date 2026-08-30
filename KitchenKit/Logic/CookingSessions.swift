// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Product intentions and classified reads for one Kitchen's Cooking Sessions.
///
/// Callers never coordinate Recipe reads, immutable snapshot creation, Session
/// evidence appends, or post-write reconstruction themselves.
@MainActor
public struct CookingSessions {
  let kitchenID: Kitchen.ID
  private let recipeRepository: any RecipeRepository
  let sessionRepository: any CookingSessionRepository
  let snapshotFactory: CookingSessionSnapshotFactory
  let commandFactory: CookingSessionCommandFactory
  let dispositionFactory: CookingSessionDispositionFactory

  public init(
    kitchenID: Kitchen.ID,
    recipeRepository: any RecipeRepository,
    sessionRepository: any CookingSessionRepository
  ) {
    self.kitchenID = kitchenID
    self.recipeRepository = recipeRepository
    self.sessionRepository = sessionRepository
    let encoding = CanonicalCookingSessionEncoding()
    let commands = CookingSessionCommandFactory(encoding: encoding)
    snapshotFactory = CookingSessionSnapshotFactory(encoding: encoding)
    commandFactory = commands
    dispositionFactory = CookingSessionDispositionFactory(commands: commands)
  }

  init(
    kitchenID: Kitchen.ID,
    recipeRepository: any RecipeRepository,
    sessionRepository: any CookingSessionRepository,
    encoding: any CookingSessionEncoding
  ) {
    self.kitchenID = kitchenID
    self.recipeRepository = recipeRepository
    self.sessionRepository = sessionRepository
    let commands = CookingSessionCommandFactory(encoding: encoding)
    snapshotFactory = CookingSessionSnapshotFactory(encoding: encoding)
    commandFactory = commands
    dispositionFactory = CookingSessionDispositionFactory(commands: commands)
  }

  public func session(id: CookingSession.ID) throws -> SessionProjectionResult? {
    guard let evidence = try retainedEvidence(id: id), evidenceBelongsToKitchen(evidence) else {
      return nil
    }
    return SessionEvidenceProjector.project(evidence)
  }

  public func sessions() throws -> [SessionProjectionResult] {
    do { return try sessionRepository.sessions(in: kitchenID) } catch {
      throw CookingSessionLogicError.sessionReadFailed
    }
  }

  public func sessions(for recipeID: Recipe.ID) throws -> [SessionProjectionResult] {
    do { return try sessionRepository.sessions(for: recipeID, in: kitchenID) } catch {
      throw CookingSessionLogicError.sessionReadFailed
    }
  }

  public func finishedSessions(limit: Int) throws -> [SessionProjectionResult] {
    do { return try sessionRepository.finishedSessions(in: kitchenID, limit: limit) } catch {
      throw CookingSessionLogicError.sessionReadFailed
    }
  }

  /// The complete locally observed deletion frontier that an explicit Restore
  /// must resolve. The subsequent command revalidates this plan so evidence
  /// arriving between presentation and acceptance cannot be silently ignored.
  public func unresolvedDeletionIDs(
    for sessionID: CookingSession.ID
  ) throws -> [SessionDeletion.ID] {
    let evidence = try requiredEvidence(id: sessionID)
    let projected = SessionEvidenceProjector.project(evidence)
    guard case let .session(session) = projected,
          case .deleted = session.disposition
    else { return [] }
    let resolved = Set(evidence.restorations.map(\.deletionID))
    return Dictionary(grouping: evidence.deletions, by: \SessionDeletionEvidence.id)
      .compactMap { $0.value.first }
      .filter { !resolved.contains($0.id) }
      .map(\.id)
      .sorted { $0.rawValue.uuidString < $1.rawValue.uuidString }
  }

  /// The complete, unambiguous Closure choices that can be presented for an
  /// explicit competing-Closure decision. Any other Recovery reason or an
  /// identity collision remains inspectable but is not directly resolvable.
  public static func closureCandidates(
    for recovery: SessionRecovery
  ) -> [SessionClosureEvidence] {
    guard recovery.reasons == [.competingClosures] else { return [] }
    let grouped = Dictionary(grouping: recovery.evidence.closures, by: \.id)
    guard grouped.values.allSatisfy({ values in
      guard let first = values.first else { return false }
      return values.allSatisfy { $0 == first }
    }) else { return [] }
    return grouped.values.compactMap(\.first).sorted {
      if $0.finishedAt != $1.finishedAt { return $0.finishedAt < $1.finishedAt }
      return $0.id.rawValue.uuidString < $1.id.rawValue.uuidString
    }
  }

  /// Counts the transitive continuation descendants retained in a classified
  /// read. Deleting a source never cascades into these descendants, so callers
  /// can warn without reimplementing aggregate dependency rules.
  public static func knownDescendantCount(
    of sessionID: CookingSession.ID,
    among results: [SessionProjectionResult]
  ) -> Int {
    let edges = results.flatMap { result -> [(CookingSession.ID, CookingSession.ID)] in
      switch result {
      case let .session(session):
        guard let sourceSessionID = session.sourceSessionID else { return [] }
        return [(session.id, sourceSessionID)]
      case let .unavailable(unavailable):
        return unavailable.evidence.roots.compactMap { root in
          root.sourceSessionID.map { (root.id, $0) }
        }
      case let .recovery(recovery):
        return recovery.evidence.roots.compactMap { root in
          root.sourceSessionID.map { (root.id, $0) }
        }
      }
    }
    var frontier = [sessionID]
    var descendants = Set<CookingSession.ID>()
    while let source = frontier.popLast() {
      for (candidate, parent) in edges where parent == source {
        if descendants.insert(candidate).inserted { frontier.append(candidate) }
      }
    }
    return descendants.count
  }

  public func start(
    _ intention: StartCookingSessionIntention
  ) throws -> CookingSessionCommandResult {
    if let existing = try retainedEvidence(id: intention.sessionID) {
      guard evidenceBelongsToKitchen(existing),
            !existing.roots.isEmpty,
            existing.roots.allSatisfy({ startRoot($0, matches: intention) })
      else { throw CookingSessionLogicError.intentionIdentityCollision }
      return try classifiedResult(id: intention.sessionID)
    }
    let revision = try recipeRevision(for: intention)
    let root = try snapshotFactory.root(
      for: intention,
      kitchenID: kitchenID,
      revision: revision
    )
    do {
      try sessionRepository.append(.start(root))
    } catch {
      throw CookingSessionLogicError.sessionWriteFailed
    }
    return try classifiedResult(id: intention.sessionID)
  }

  private func recipeRevision(
    for intention: StartCookingSessionIntention
  ) throws -> RecipeRevision {
    let stored: StoredRecipe?
    let revisions: [RecipeRevision]
    do {
      stored = try recipeRepository.recipe(id: intention.recipeID)
      revisions = try recipeRepository.revisions(for: intention.recipeID)
    } catch {
      throw CookingSessionLogicError.recipeReadFailed
    }
    guard let stored else { throw CookingSessionLogicError.recipeNotFound }
    guard stored.recipe.kitchenID == kitchenID else {
      throw CookingSessionLogicError.recipeOutsideKitchen
    }
    guard let revision = revisions.first(where: { $0.id == intention.recipeRevisionID }) else {
      throw CookingSessionLogicError.recipeRevisionNotFound
    }
    return revision
  }

  func retainedEvidence(id: CookingSession.ID) throws -> SessionEvidence? {
    do {
      return try sessionRepository.evidence(id: id)
    } catch {
      throw CookingSessionLogicError.sessionReadFailed
    }
  }

  func requiredEvidence(id: CookingSession.ID) throws -> SessionEvidence {
    guard let evidence = try retainedEvidence(id: id) else {
      throw CookingSessionLogicError.sessionReadFailed
    }
    guard evidenceBelongsToKitchen(evidence) else {
      throw CookingSessionLogicError.sessionOutsideKitchen
    }
    return evidence
  }

  func evidenceBelongsToKitchen(_ evidence: SessionEvidence) -> Bool {
    if !evidence.roots.isEmpty {
      return evidence.roots.contains { $0.kitchenID == kitchenID }
    }
    let kitchenIDs = Set(evidence.facts.map(\.kitchenID))
      .union(evidence.closures.map(\.kitchenID))
      .union(evidence.deletions.map(\.kitchenID))
      .union(evidence.restorations.map(\.kitchenID))
    return kitchenIDs.contains(kitchenID)
  }

  func attention(from result: SessionProjectionResult) -> CookingSessionCommandResult {
    switch result {
    case let .unavailable(unavailable): return .attention(.unavailable(unavailable))
    case let .recovery(recovery): return .attention(.recovery(recovery))
    case let .session(session): return .accepted(session)
    }
  }

  func classifiedResult(
    id: CookingSession.ID
  ) throws -> CookingSessionCommandResult {
    guard let result = try session(id: id) else {
      throw CookingSessionLogicError.sessionReadFailed
    }
    switch result {
    case let .session(session): return .accepted(session)
    case let .unavailable(unavailable): return .attention(.unavailable(unavailable))
    case let .recovery(recovery): return .attention(.recovery(recovery))
    }
  }

  private func startRoot(
    _ root: CookingSessionRootEvidence,
    matches intention: StartCookingSessionIntention
  ) -> Bool {
    guard root.id == intention.sessionID,
          root.kitchenID == kitchenID,
          root.recipeID == intention.recipeID,
          root.recipeRevisionID == intention.recipeRevisionID,
          root.startedAt == intention.startedAt,
          root.sourceSessionID == nil,
          root.sourceClosureID == nil,
          let snapshot = try? ExecutionSnapshotCodec.decode(
            formatVersion: root.snapshotFormatVersion,
            data: root.snapshotData
          )
    else { return false }
    guard let scale = intention.workingScale else {
      return snapshot.initialWorkingScale?.exactScale == RationalQuantity(numerator: 1)
    }
    return snapshot.initialWorkingScale?.exactScale == scale.multiplier
      && snapshot.initialWorkingScale?.workingYield?.quantity?.lowerBound == scale.workingYield
  }
}
