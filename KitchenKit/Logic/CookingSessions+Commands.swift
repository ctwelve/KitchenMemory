// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT
import Foundation
// The exhaustive public command router and its retry contracts stay together.
// swiftlint:disable file_length
@MainActor
extension CookingSessions {
  // This switch is the complete public intention vocabulary; keeping it in one
  // place makes newly added commands fail compilation until they are routed.
  // swiftlint:disable:next cyclomatic_complexity function_body_length
  public func perform(
    _ intention: CookingSessionIntention
  ) throws -> CookingSessionCommandResult {
    switch intention {
    case let .stop(value):
      try performFact(value, description: .empty(.stop), requiredLifecycle: .active)
    case let .resume(value):
      try performFact(value, description: .empty(.resume), requiredLifecycle: .stopped)
    case let .progress(value, progress):
      try performFact(
        value,
        description: SessionFactDescription(
          kind: .progress,
          payload: .progress(progress.state),
          target: targetIdentifier(progress.target)
        ),
        requiredLifecycle: .active
      )
    case let .replaceWorkingScale(value, scale):
      try performFact(
        value,
        description: SessionFactDescription(
          kind: .workingScale,
          payload: .workingScale(scale),
          target: nil
        ),
        requiredLifecycle: .active
      )
    case let .submitEntry(value, text, target):
      try performFact(
        value,
        description: SessionFactDescription(
          kind: .sessionEntry,
          payload: .sessionEntry(.submit(
            entryID: .init(rawValue: value.id.rawValue),
            text: text
          )),
          target: target.map(targetIdentifier)
        ),
        requiredLifecycle: .active
      )
    case let .reviseEntry(value, entryID, text, target):
      try performFact(
        value,
        description: SessionFactDescription(
          kind: .sessionEntry,
          payload: .sessionEntry(.revise(entryID: entryID, text: text)),
          target: target.map(targetIdentifier)
        ),
        requiredLifecycle: .active
      )
    case let .retargetEntry(value, entryID, target):
      try performRetarget(value, entryID: entryID, target: target)
    case let .withdrawEntry(value, entryID):
      try performFact(
        value,
        description: SessionFactDescription(
          kind: .sessionEntry,
          payload: .sessionEntry(.withdraw(entryID: entryID)),
          target: nil
        ),
        requiredLifecycle: .active
      )
    case let .setOutcome(value, outcome):
      try performFact(
        value,
        description: SessionFactDescription(
          kind: .sessionOutcome,
          payload: .sessionOutcome(.set(outcome)),
          target: nil
        ),
        requiredLifecycle: .active
      )
    case let .clearOutcome(value):
      try performFact(
        value,
        description: SessionFactDescription(
          kind: .sessionOutcome,
          payload: .sessionOutcome(.clear),
          target: nil
        ),
        requiredLifecycle: .active
      )
    case let .finish(value):
      try performFinish(value)
    case let .delete(value):
      try performDelete(value)
    case let .restore(value):
      try performRestore(value)
    case let .resolveClosure(value):
      try performClosureResolution(value)
    case let .continueSession(value):
      try performContinuation(value)
    }
  }

  // Finish deliberately keeps retry validation and its atomic transaction
  // selection adjacent so neither half can drift from the other.
  // swiftlint:disable:next function_body_length
  private func performFinish(
    _ intention: FinishCookingSessionIntention
  ) throws -> CookingSessionCommandResult {
    let evidence = try requiredEvidence(id: intention.sessionID)
    guard !intention.hasMeaningfulDraft else { return .attention(.meaningfulDraft) }
    if let existing = evidence.closures.first(where: { $0.id == intention.closureID }) {
      guard evidence.closures.filter({ $0.id == intention.closureID }).allSatisfy({
        $0 == existing
      }),
        existing.sessionID == intention.sessionID,
        existing.kitchenID == kitchenID,
        existing.finishedAt == intention.finishedAt
      else { throw CookingSessionLogicError.intentionIdentityCollision }
      if let deletion = intention.deletion {
        let matches = evidence.deletions.filter { $0.id == deletion.id }
        guard let first = matches.first,
              matches.allSatisfy({ $0 == first }),
              first.sessionID == intention.sessionID,
              first.kitchenID == kitchenID,
              first.deletedAt == deletion.deletedAt
        else {
          throw CookingSessionLogicError.intentionIdentityCollision
        }
      }
      return try classifiedResult(id: intention.sessionID)
    }
    let projectionResult = SessionEvidenceProjector.project(evidence)
    guard case let .session(session) = projectionResult else {
      return attention(from: projectionResult)
    }
    guard session.lifecycle == .active || session.lifecycle == .stopped else {
      return .attention(.commandNotAllowed(lifecycle: session.lifecycle))
    }
    guard session.conflicts.isEmpty else { return .attention(.conflicts(session.conflicts)) }
    let closure = try commandFactory.closure(
      intention: intention,
      kitchenID: kitchenID,
      projection: session,
      evidence: evidence
    )
    let transaction: CookingSessionTransaction
    if let deletion = intention.deletion {
      var staged = evidence
      staged.closures.append(closure)
      let disposition = try dispositionFactory.deletion(
        intention: DeleteCookingSessionIntention(
          deletionID: deletion.id,
          sessionID: intention.sessionID,
          deletedAt: deletion.deletedAt
        ),
        kitchenID: kitchenID,
        evidence: staged
      )
      transaction = .finishAndDelete(closure, disposition)
    } else {
      transaction = .finish(closure)
    }
    do {
      try sessionRepository.append(transaction)
    } catch {
      throw CookingSessionLogicError.sessionWriteFailed
    }
    return try classifiedResult(id: intention.sessionID)
  }

  private func performClosureResolution(
    _ intention: ResolveCookingSessionClosureIntention
  ) throws -> CookingSessionCommandResult {
    let evidence = try requiredEvidence(id: intention.fact.sessionID)
    guard intention.observedClosureIDs.count > 1,
          Set(intention.observedClosureIDs).count == intention.observedClosureIDs.count,
          intention.observedClosureIDs.contains(intention.selectedClosureID)
    else { throw CookingSessionLogicError.invalidIntention }
    let closures = Dictionary(grouping: evidence.closures, by: \SessionClosureEvidence.id)
      .compactMap { $0.value.first }
      .sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
    let selection = ClosureSelection(
      selectedClosureID: intention.selectedClosureID,
      observedClosureIDs: intention.observedClosureIDs
    )
    let description = SessionFactDescription(
      kind: .conflictResolution,
      payload: .closureResolution(selection),
      target: nil
    )
    if try closureResolutionAlreadyExists(intention, in: evidence) {
      return try classifiedResult(id: intention.fact.sessionID)
    }
    let projected = SessionEvidenceProjector.project(evidence)
    guard closures.map(\.id) == intention.observedClosureIDs else {
      guard Set(intention.observedClosureIDs).isSubset(of: Set(closures.map(\.id))),
            closures.count > 1,
            closures.contains(where: { $0.id == intention.selectedClosureID })
      else { throw CookingSessionLogicError.invalidIntention }
      return attention(from: projected)
    }
    guard case let .recovery(recovery) = projected,
          recovery.reasons == [.competingClosures]
    else { return attention(from: projected) }
    let fact = try commandFactory.fact(
      intention: intention.fact,
      kitchenID: kitchenID,
      description: description,
      evidence: evidence
    )
    do { try sessionRepository.append(.resolveClosure(fact)) } catch {
      throw CookingSessionLogicError.sessionWriteFailed
    }
    return try classifiedResult(id: intention.fact.sessionID)
  }

  private func closureResolutionAlreadyExists(
    _ intention: ResolveCookingSessionClosureIntention,
    in evidence: SessionEvidence
  ) throws -> Bool {
    guard let existing = evidence.facts.first(where: { $0.id == intention.fact.id })
    else { return false }
    guard existing.sessionID == intention.fact.sessionID,
          existing.kitchenID == kitchenID,
          existing.kind == SessionFact.Kind.conflictResolution.rawValue,
          existing.targetSnapshotElementID == nil,
          existing.authoredAt == intention.fact.authoredAt,
          let payload = try? SessionFactPayloadCodec.decode(
            formatVersion: existing.payloadFormatVersion,
            data: existing.payloadData
          ),
          case let .closureResolution(stored) = payload,
          stored.selectedClosureID == intention.selectedClosureID,
          stored.observedClosureIDs == intention.observedClosureIDs
    else { throw CookingSessionLogicError.intentionIdentityCollision }
    return true
  }

  private func performContinuation(
    _ intention: ContinueCookingSessionIntention
  ) throws -> CookingSessionCommandResult {
    if let existing = try retainedEvidence(id: intention.sessionID) {
      guard evidenceBelongsToKitchen(existing),
            !existing.roots.isEmpty,
            existing.roots.allSatisfy({ root in
              root.id == intention.sessionID
                && root.kitchenID == kitchenID
                && root.startedAt == intention.startedAt
                && root.sourceSessionID == intention.sourceSessionID
                && root.sourceClosureID != nil
            })
      else { throw CookingSessionLogicError.intentionIdentityCollision }
      return try classifiedResult(id: intention.sessionID)
    }
    let sourceEvidence = try requiredEvidence(id: intention.sourceSessionID)
    let sourceResult = SessionEvidenceProjector.project(sourceEvidence)
    guard case let .session(source) = sourceResult else { return attention(from: sourceResult) }
    guard source.lifecycle == .finished, let closureID = source.selectedClosureID else {
      return .attention(.commandNotAllowed(lifecycle: source.lifecycle))
    }
    let root = try snapshotFactory.continuationRoot(
      intention: intention,
      kitchenID: kitchenID,
      source: source,
      sourceEvidence: sourceEvidence,
      sourceClosureID: closureID
    )
    do { try sessionRepository.append(.continueSession(root)) } catch {
      throw CookingSessionLogicError.sessionWriteFailed
    }
    return try classifiedResult(id: intention.sessionID)
  }

  private func performRetarget(
    _ intention: SessionFactIntention,
    entryID: SessionEntry.ID,
    target: SessionProgressTarget?
  ) throws -> CookingSessionCommandResult {
    let evidence = try requiredEvidence(id: intention.sessionID)
    if let existing = evidence.facts.first(where: { $0.id == intention.id }) {
      // Retarget is intentionally stored as a revision of the current text.
      // A caller retrying that exact durable revision through either vocabulary
      // is the same command, not a second mutation.
      guard existing.sessionID == intention.sessionID,
            existing.kitchenID == kitchenID,
            existing.kind == SessionFact.Kind.sessionEntry.rawValue,
            existing.targetSnapshotElementID == target.map(targetIdentifier),
            existing.authoredAt == intention.authoredAt,
            let payload = try? SessionFactPayloadCodec.decode(
              formatVersion: existing.payloadFormatVersion,
              data: existing.payloadData
            ),
            case let .sessionEntry(.revise(storedEntryID, _)) = payload,
            storedEntryID == entryID
      else { throw CookingSessionLogicError.intentionIdentityCollision }
      return try classifiedResult(id: intention.sessionID)
    }
    let projectionResult = SessionEvidenceProjector.project(evidence)
    guard case let .session(session) = projectionResult else {
      return attention(from: projectionResult)
    }
    guard session.lifecycle == .active else {
      return .attention(.commandNotAllowed(lifecycle: session.lifecycle))
    }
    guard let entry = session.entries.first(where: { $0.id == entryID }) else {
      let conflicts = session.conflicts.filter { conflict in
        if case let .entry(conflictedID, _, _) = conflict { return conflictedID == entryID }
        return false
      }
      guard conflicts.isEmpty else { return .attention(.conflicts(conflicts)) }
      throw CookingSessionLogicError.invalidIntention
    }
    return try performFact(
      intention,
      description: SessionFactDescription(
        kind: .sessionEntry,
        payload: .sessionEntry(.revise(entryID: entryID, text: entry.text)),
        target: target.map(targetIdentifier)
      ),
      requiredLifecycle: .active
    )
  }

  private func performFact(
    _ intention: SessionFactIntention,
    description: SessionFactDescription,
    requiredLifecycle: SessionLifecycle
  ) throws -> CookingSessionCommandResult {
    let evidence = try requiredEvidence(id: intention.sessionID)
    if let existing = evidence.facts.first(where: { $0.id == intention.id }) {
      guard try commandFactory.matchesRetry(
        existing,
        intention: intention,
        kitchenID: kitchenID,
        description: description
      ) else { throw CookingSessionLogicError.intentionIdentityCollision }
      return try classifiedResult(id: intention.sessionID)
    }
    let projectionResult = SessionEvidenceProjector.project(evidence)
    guard case let .session(session) = projectionResult else {
      return attention(from: projectionResult)
    }
    guard session.lifecycle == requiredLifecycle else {
      return .attention(.commandNotAllowed(lifecycle: session.lifecycle))
    }
    guard factDescriptionIsValid(description, for: session) else {
      throw CookingSessionLogicError.invalidIntention
    }
    let fact = try commandFactory.fact(
      intention: intention,
      kitchenID: kitchenID,
      description: description,
      evidence: evidence
    )
    do {
      try sessionRepository.append(.activity(fact))
    } catch {
      throw CookingSessionLogicError.sessionWriteFailed
    }
    return try classifiedResult(id: intention.sessionID)
  }

  // Each payload case owns a distinct structural validity contract.
  // swiftlint:disable:next cyclomatic_complexity
  private func factDescriptionIsValid(
    _ description: SessionFactDescription,
    for session: CookingSessionProjection
  ) -> Bool {
    let snapshot = session.snapshot
    let ingredients = Set(snapshot.ingredientSections.flatMap(\.ingredients).map(\.id.rawValue))
    let instructions = Set(snapshot.instructionSections.flatMap(\.steps).map(\.id.rawValue))
    switch description.payload {
    case let .progress(state):
      switch (description.target, state) {
      case let (target?, .ingredient): return ingredients.contains(target)
      case let (target?, .instruction): return instructions.contains(target)
      default: return false
      }
    case let .workingScale(scale):
      let quantityIDs = scale.quantities.map(\.ingredientID.rawValue)
      let expectedQuantityIDs = Set(
        snapshot.ingredientSections.flatMap(\.ingredients).compactMap { ingredient in
          ingredient.value.quantity == nil ? nil : ingredient.id.rawValue
        }
      )
      let exactIsValid = scale.exactScale.map {
        $0.normalized != nil && $0.numerator > 0
      } ?? true
      let hasScaleValue = scale.workingYield != nil || scale.exactScale != nil
      return hasScaleValue
        && Set(quantityIDs).count == quantityIDs.count
        && Set(quantityIDs) == expectedQuantityIDs
        && exactIsValid
    case let .sessionEntry(operation):
      let targetExists = description.target.map {
        ingredients.contains($0) || instructions.contains($0)
      } ?? true
      let knownEntry: (SessionEntry.ID) -> Bool = { entryID in
        session.entries.contains { $0.id == entryID }
          || session.conflicts.contains { conflict in
            if case let .entry(conflictedID, _, _) = conflict { return conflictedID == entryID }
            return false
          }
      }
      switch operation {
      case let .submit(_, text): return targetExists && !text.isEmpty
      case let .revise(entryID, text):
        return targetExists && !text.isEmpty && knownEntry(entryID)
      case let .withdraw(entryID):
        return description.target == nil && knownEntry(entryID)
      }
    default:
      return description.target == nil
    }
  }

  private func targetIdentifier(_ target: SessionProgressTarget) -> UUID {
    switch target {
    case let .ingredient(identifier): identifier.rawValue
    case let .instruction(identifier): identifier.rawValue
    }
  }
}

private extension SessionFactDescription {
  static func empty(_ kind: SessionFact.Kind) -> Self {
    Self(kind: kind, payload: .empty, target: nil)
  }
}
