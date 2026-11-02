// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData
import UndoKit

extension SwiftDataRecipeOrganizationRepository {
  public func historySessionIDs(in scope: RecipeOrganizationHistoryScope, generation: UUID)
    throws -> Set<CookingSession.ID> {
    Set(try historyReceipts(in: scope.kitchenID, context: ModelContext(container)).compactMap {
      $0.delivery.scope == scope && $0.delivery.token.generation == generation
        ? $0.delivery.change.sessionID : nil
    })
  }

  public func prepareHistoryProgress(
    _ sessionID: CookingSession.ID, to progress: SessionProgress, in scope: RecipeOrganizationHistoryScope
  ) throws -> RecipeOrganizationHistoryChange? {
    let context = ModelContext(container)
    try validateHistoryScope(scope, context: context)
    let (evidence, session) = try editableHistorySession(sessionID, scope: scope, context: context)
    let before = try historyProgress(progress.target, in: session)
    guard before.state != progress.state else { return nil }
    return RecipeOrganizationHistoryChange(sessionProgress: SessionProgressHistoryChange(sessionID: sessionID,
      recipeID: evidence.roots[0].recipeID, before: before, after: progress,
      baseline: try sessionHistoryWitness(evidence)))
  }

  public func prepareHistoryScale(
    _ sessionID: CookingSession.ID, to scale: SessionWorkingScale, in scope: RecipeOrganizationHistoryScope
  ) throws -> RecipeOrganizationHistoryChange? {
    let context = ModelContext(container)
    try validateHistoryScope(scope, context: context)
    let (evidence, session) = try editableHistorySession(sessionID, scope: scope, context: context)
    guard let before = session.workingScale else { throw RecipeOrganizationHistoryError.ineligible }
    guard before != scale else { return nil }
    return RecipeOrganizationHistoryChange(sessionScale: SessionScaleHistoryChange(sessionID: sessionID,
      recipeID: evidence.roots[0].recipeID, before: before, after: scale,
      baseline: try sessionHistoryWitness(evidence)))
  }

  func prepareSessionHistoryDelivery(_ change: RecipeOrganizationHistoryChange, memberID: UUID,
                                     token: UndoKit.HistoryToken, scope: RecipeOrganizationHistoryScope)
    throws -> RecipeOrganizationHistoryDelivery {
    guard token.scope == scope.identity, let sessionID = change.sessionID else {
      throw RecipeOrganizationHistoryError.invalidScope
    }
    let repository = SwiftDataCookingSessionRepository(modelContainer: container)
    guard let evidence = try repository.evidence(id: sessionID) else {
      throw RecipeOrganizationHistoryError.ineligible
    }
    let now = Date()
    let factory = CookingSessionCommandFactory(encoding: CanonicalCookingSessionEncoding())
    let heads = try factory.maximalSessionHeads(evidence)
    return RecipeOrganizationHistoryDelivery(scope: scope, token: OrganizationHistoryToken(token), memberID: memberID,
      change: change, command: RecipeOrganizationCommand(id: token.command, kitchenID: scope.kitchenID,
        authoredAt: now, folders: [], tags: []), beforeWitness: try sessionHistoryWitness(evidence),
      sessionFact: SessionProgressHistoryFact(id: .init(rawValue: token.command), authoredAt: now,
        heads: CausalHeadsCodec.encode(heads).data))
  }

  func commitSessionHistory(_ delivery: RecipeOrganizationHistoryDelivery, recovery: Bool,
                            receipts: [RecipeOrganizationHistoryReceipt], context: ModelContext)
    throws -> RecipeOrganizationHistoryReceipt {
    try validateHistoryScope(delivery.scope, context: context)
    guard let sessionID = delivery.change.sessionID, let frozen = delivery.sessionFact,
          delivery.token.scope == delivery.scope.identity, delivery.command.id == delivery.token.command,
          delivery.command.kitchenID == delivery.scope.kitchenID,
          delivery.command.folders.isEmpty, delivery.command.tags.isEmpty,
          frozen.id.rawValue == delivery.token.command, frozen.authoredAt == delivery.command.authoredAt else {
      throw RecipeOrganizationHistoryError.invalidScope
    }
    let (evidence, session) = try editableHistorySession(sessionID, scope: delivery.scope, context: context)
    guard try sessionHistoryWitness(evidence) == delivery.beforeWitness,
          foldedSessionWitness(delivery.change, token: delivery.token, receipts: receipts) == delivery.beforeWitness
    else {
      throw RecipeOrganizationHistoryError.ineligible
    }
    let meaning = try sessionHistoryMeaning(delivery.change, in: session)
    let payload = try SessionFactPayloadCodec.encode(meaning.payload)
    let fact = SessionFactEvidence(id: frozen.id, sessionID: sessionID, kitchenID: delivery.scope.kitchenID,
      kind: meaning.kind.rawValue, targetSnapshotElementID: meaning.target,
      authoredAt: frozen.authoredAt, causalHeadsFormatVersion: 1, causalHeadsData: frozen.heads,
      payloadFormatVersion: payload.formatVersion, payloadData: payload.data, payloadDigest: payload.digest)
    var after = evidence
    after.facts.append(fact)
    guard case let .session(projected) = SessionEvidenceProjector.project(after),
          projected.lifecycle == .active, projected.conflicts.isEmpty else {
      throw RecipeOrganizationHistoryError.ineligible
    }
    let records = try CookingSessionTransaction.activity(fact).records()
    try records.validateForPersistence()
    SwiftDataCookingSessionRepository(context: context).insert(records)
    let receipt = RecipeOrganizationHistoryReceipt(delivery: delivery, afterWitness: try sessionHistoryWitness(after))
    let action = OrganizationAction(id: recovery ? delivery.token.recoveryReceiptID : delivery.token.receiptID,
      authoredAt: frozen.authoredAt, observed: [],
      payload: OrganizationHistoryReceiptPayload(version: 1, receipt: receipt))
    try historyReceiptStore(recovery: recovery).append(
      action, in: delivery.scope.kitchenID, context: context
    ) { snapshot in
      guard snapshot.checkpoints.isEmpty else { throw RecipeOrganizationHistoryError.invalidEvidence }
      _ = try OrganizationEvidence(snapshot.actions)
    }
    return receipt
  }

  func sessionHistoryIsEligible(_ change: RecipeOrganizationHistoryChange, scope: RecipeOrganizationHistoryScope,
                                token: OrganizationHistoryToken, receipts: [RecipeOrganizationHistoryReceipt],
                                context: ModelContext) throws -> Bool {
    guard let sessionID = change.sessionID,
          let (evidence, _) = try? editableHistorySession(sessionID, scope: scope, context: context) else {
      return false
    }
    return try sessionHistoryWitness(evidence) == foldedSessionWitness(change, token: token, receipts: receipts)
  }

  private func sessionHistoryMeaning(_ change: RecipeOrganizationHistoryChange, in session: CookingSessionProjection)
    throws -> SessionHistoryMeaning {
    if let scale = change.sessionScale {
      guard session.workingScale == scale.before else { throw RecipeOrganizationHistoryError.ineligible }
      return SessionHistoryMeaning(kind: .workingScale, target: nil, payload: .workingScale(scale.after))
    }
    guard let progress = change.sessionProgress, progress.before.target == progress.after.target else {
      throw RecipeOrganizationHistoryError.invalidScope
    }
    guard try historyProgress(progress.before.target, in: session) == progress.before else {
      throw RecipeOrganizationHistoryError.ineligible
    }
    return SessionHistoryMeaning(kind: .progress, target: progress.after.target.rawIdentifier,
      payload: .progress(progress.after.state))
  }

  private func editableHistorySession(_ id: CookingSession.ID, scope: RecipeOrganizationHistoryScope,
                                      context: ModelContext) throws -> (SessionEvidence, CookingSessionProjection) {
    let repository = SwiftDataCookingSessionRepository(context: context)
    guard let evidence = try repository.evidence(id: id),
          evidence.roots.allSatisfy({ $0.kitchenID == scope.kitchenID }),
          case let .session(session) = try repository.session(id: id), session.lifecycle == .active,
          session.disposition == .ordinary, session.conflicts.isEmpty else {
      throw RecipeOrganizationHistoryError.ineligible
    }
    return (evidence, session)
  }

  private func historyProgress(_ target: SessionProgressTarget, in session: CookingSessionProjection)
    throws -> SessionProgress {
    let initial: SessionProgressState
    switch target {
    case let .ingredient(id):
      guard session.snapshot.ingredientSections.flatMap(\.ingredients).contains(where: { $0.id == id }) else {
        throw RecipeOrganizationHistoryError.ineligible
      }
      initial = .ingredient(.open)
    case let .instruction(id):
      guard session.snapshot.instructionSections.flatMap(\.steps).contains(where: { $0.id == id }) else {
        throw RecipeOrganizationHistoryError.ineligible
      }
      initial = .instruction(.open)
    }
    return session.progress.first { $0.target == target } ?? SessionProgress(target: target, state: initial)
  }

  private func foldedSessionWitness(_ change: RecipeOrganizationHistoryChange, token: OrganizationHistoryToken,
                                    receipts: [RecipeOrganizationHistoryReceipt]) -> Data? {
    var witness = change.sessionBaseline
    for receipt in receipts.filter({ $0.delivery.token.scope == token.scope
      && $0.delivery.token.generation == token.generation }).sorted(by: {
        $0.delivery.token.sequence < $1.delivery.token.sequence
      }) where receipt.delivery.change.sessionID == change.sessionID {
      if receipt.delivery.beforeWitness == witness { witness = receipt.afterWitness }
    }
    return witness
  }

  private func sessionHistoryWitness(_ evidence: SessionEvidence) throws -> Data {
    // Immutable identities detect any newly accepted evidence, including a field unrelated to progress.
    let identities: [[UUID]] = [evidence.roots.map(\.id.rawValue), evidence.facts.map(\.id.rawValue),
      evidence.closures.map(\.id.rawValue), evidence.deletions.map(\.id.rawValue),
      evidence.restorations.map(\.id.rawValue),
    ]
    return try OrganizationCoding.encode(identities.map { Set($0).sorted { $0.uuidString < $1.uuidString } })
  }
}

private struct SessionHistoryMeaning {
  let kind: SessionFact.Kind
  let target: UUID?
  let payload: SessionFactPayload
}
