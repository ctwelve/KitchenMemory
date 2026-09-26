// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
@MainActor
extension CookingSessionPresentationModel {
  @discardableResult
  func start(from recipe: StoredRecipe) -> Bool {
    return submitCommand { .start(
      sessionID: CookingSession.ID(),
      recipeID: recipe.recipe.id,
      revisionID: recipe.revision.id,
      startedAt: Date()
    ) }
  }
  @discardableResult
  func stopCurrentSession() -> Bool {
    guard let session = currentSession, session.lifecycle == .active else { return false }
    return submitCommand { .stop(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date()
    ) }
  }
  @discardableResult
  func resumeCurrentSession() -> Bool {
    guard let session = currentSession, session.lifecycle == .stopped else { return false }
    return submitCommand { .resume(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date()
    ) }
  }
  @discardableResult
  func setIngredient(_ id: SessionIngredient.ID, to state: SessionIngredientProgress) -> Bool {
    guard let session = currentSession, session.lifecycle == .active,
          session.snapshot.ingredientSections.flatMap(\.ingredients).contains(where: {
            $0.id == id
          }) else { return false }
    return submitIndependentCommand(.progress(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date(),
      progress: SessionProgress(target: .ingredient(id), state: .ingredient(state))
    ))
  }
  @discardableResult
  func setInstruction(_ id: SessionInstruction.ID, to state: SessionInstructionProgress) -> Bool {
    guard let session = currentSession, session.lifecycle == .active,
          session.snapshot.instructionSections.flatMap(\.steps).contains(where: {
            $0.id == id
          }) else { return false }
    return submitIndependentCommand(.progress(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date(),
      progress: SessionProgress(target: .instruction(id), state: .instruction(state))
    ))
  }
  @discardableResult
  func replaceWorkingScale(with scale: RecipeScale) -> Bool {
    guard let session = currentSession, session.lifecycle == .active,
          let replacement = workingScale(for: session.snapshot, scale: scale)
    else { return false }
    guard session.workingScale != replacement else { return true }
    return submitIndependentCommand(.replaceWorkingScale(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date(),
      scale: replacement
    ))
  }

  @discardableResult
  func finishCurrentSession() -> Bool {
    guard let session = currentSession,
          session.lifecycle == .active || session.lifecycle == .stopped else { return false }
    if currentEntryDraft?.isMeaningful == true {
      present(.attention(.meaningfulDraft))
      return false
    }
    discardCurrentEntryDraft()
    return submitCommand { .finish(
      closureID: SessionClosure.ID(),
      sessionID: session.id,
      finishedAt: Date()
    ) }
  }

  func retryPendingCommands() {
    consume(delivery.retry())
  }
}

extension CookingSessionPresentationModel {
  func submitCommand(_ makeCommand: () throws -> PendingCookingSessionCommand?) -> Bool {
    let report = delivery.submit(makeCommand)
    consume(report.events)
    return report.wasAccepted || report.completedRestore
  }

  func submitIndependentCommand(_ command: PendingCookingSessionCommand) -> Bool {
    let report = delivery.submitIndependent(command)
    consume(report.events)
    return report.wasAccepted
  }

  private func consume(_ events: [CookingSessionDelivery.Event]) {
    for event in events {
      switch event {
      case let .failed(_, failure):
        switch failure {
        case let .command(error): present(.command(error))
        case let .attention(attention): present(.attention(attention))
        case .unavailable: present(.read)
        }
      case let .resolved(pending, resolution):
        switch resolution {
        case let .accepted(session):
          refreshDetachedEntryDraft()
          issue = nil
          isShowingIssue = false
          upsert(session)
          applySelection(for: session, pending: pending)
          if pending.refreshesClassification { reload() }
        case .rejectedByFinishedSource:
          issue = nil
          isShowingIssue = false
        case let .retiredStaleConsent(attention):
          reload()
          present(.attention(attention))
        case .retiredCompletedRestore:
          issue = nil
          isShowingIssue = false
          reload()
        case let .attention(attention):
          present(.attention(attention))
        }
      }
    }
  }

  func applySelection(
    for session: CookingSessionProjection,
    pending: PendingCookingSessionCommand
  ) {
    if case .delete = pending {
      // Deleting another Session must not displace the continuation being read.
      if currentSessionID == nil || currentSessionID == session.id { navigation.move(to: .deletedItems) }
    } else if case .restore = pending {
      navigation.move(to: .deletedItems)
    } else if case .resolveClosure = pending {
      navigation.move(to: .recovery)
    } else if case .continueSession = pending {
      selectSession(session.id)
      refreshRecipeHistory()
    } else if session.lifecycle == .finished {
      sessions.removeAll { $0.id == session.id }
      navigation.move(to: .finished(session.id, history: .all))
    } else {
      select(pending.sessionID)
    }
  }

  func applyingPendingCommands(
    to session: CookingSessionProjection
  ) -> CookingSessionProjection {
    var progress = session.progress
    var workingScale = session.workingScale
    var entries = session.entries
    var outcome = session.outcome
    for pending in pendingCommands where pending.sessionID == session.id {
      switch pending {
      case let .progress(_, _, _, value):
        progress.removeAll { $0.target == value.target }
        progress.append(value)
      case let .replaceWorkingScale(_, _, _, scale):
        workingScale = scale
      case let .submitEntry(factID, _, _, text, target):
        entries.removeAll { $0.id.rawValue == factID.rawValue }
        entries.append(SessionEntry(
          id: .init(rawValue: factID.rawValue),
          target: target,
          text: text
        ))
      case let .reviseEntry(_, _, _, entryID, text, target):
        entries = entries.map {
          $0.id == entryID ? SessionEntry(id: entryID, target: target, text: text) : $0
        }
      case let .retargetEntry(_, _, _, entryID, target):
        entries = entries.map {
          $0.id == entryID ? SessionEntry(id: entryID, target: target, text: $0.text) : $0
        }
      case let .withdrawEntry(_, _, _, entryID):
        entries.removeAll { $0.id == entryID }
      case let .setOutcome(_, _, _, value):
        outcome = value
      case .clearOutcome:
        outcome = nil
      case .start, .stop, .resume, .finish, .delete, .restore, .resolveClosure,
           .continueSession:
        break
      }
    }
    return session.replacing(
      progress: progress,
      workingScale: workingScale,
      entries: entries,
      outcome: outcome
    )
  }

  func workingScale(
    for snapshot: ExecutionSnapshot,
    scale: RecipeScale
  ) -> SessionWorkingScale? {
    guard snapshot.baseYield?.scalingBases.contains(where: {
      $0.quantity == scale.baseYield
    }) == true else { return nil }
    var workingYield = snapshot.baseYield
    workingYield?.quantity = QuantityExpression(kind: .exact, lowerBound: scale.workingYield)
    let ingredients = snapshot.ingredientSections.flatMap(\.ingredients)
    var quantities: [SessionIngredientQuantity] = []
    for ingredient in ingredients where ingredient.value.quantity != nil {
      let scaled = ingredient.value.scaled(using: scale)
      guard scaled.status != .unchangedArithmeticFailure,
            let quantity = scaled.ingredient.quantity
      else { return nil }
      quantities.append(SessionIngredientQuantity(
        ingredientID: ingredient.id,
        quantity: quantity
      ))
    }
    return SessionWorkingScale(
      workingYield: workingYield,
      exactScale: scale.multiplier,
      quantities: quantities
    )
  }
}

private extension PendingCookingSessionCommand {
  var refreshesClassification: Bool {
    switch self {
    case .delete, .restore, .resolveClosure: true
    default: false
    }
  }
}

private extension CookingSessionProjection {
  func replacing(
    progress: [SessionProgress],
    workingScale: SessionWorkingScale?,
    entries: [SessionEntry],
    outcome: SessionOutcome?
  ) -> Self {
    CookingSessionProjection(
      id: id,
      snapshot: snapshot,
      sourceSessionID: sourceSessionID,
      sourceClosureID: sourceClosureID,
      lifecycle: lifecycle,
      lifecycleBeforeFinish: lifecycleBeforeFinish,
      disposition: disposition,
      progress: progress,
      workingScale: workingScale,
      entries: entries,
      outcome: outcome,
      conflicts: conflicts,
      selectedClosureID: selectedClosureID,
      lateEvidence: lateEvidence
    )
  }
}
