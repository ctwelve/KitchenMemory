// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit

@MainActor
extension CookingSessionPresentationModel {
  @discardableResult
  func start(from recipe: StoredRecipe) -> Bool {
    guard prepareForNewCommand() else { return false }
    return stageAndPerform(.start(
      sessionID: CookingSession.ID(),
      recipeID: recipe.recipe.id,
      revisionID: recipe.revision.id,
      startedAt: Date()
    ))
  }

  @discardableResult
  func stopCurrentSession() -> Bool {
    guard let session = currentSession, session.lifecycle == .active,
          prepareForNewCommand() else { return false }
    return stageAndPerform(.stop(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date()
    ))
  }

  @discardableResult
  func resumeCurrentSession() -> Bool {
    guard let session = currentSession, session.lifecycle == .stopped,
          prepareForNewCommand() else { return false }
    return stageAndPerform(.resume(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date()
    ))
  }

  @discardableResult
  func setIngredient(_ id: SessionIngredient.ID, to state: SessionIngredientProgress) -> Bool {
    guard let session = currentSession, session.lifecycle == .active,
          session.snapshot.ingredientSections.flatMap(\.ingredients).contains(where: {
            $0.id == id
          }) else { return false }
    return stageIndependentAndPerform(.progress(
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
    return stageIndependentAndPerform(.progress(
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
    return stageIndependentAndPerform(.replaceWorkingScale(
      factID: SessionFact.ID(),
      sessionID: session.id,
      authoredAt: Date(),
      scale: replacement
    ))
  }

  @discardableResult
  func finishCurrentSession() -> Bool {
    guard let session = currentSession,
          session.lifecycle == .active || session.lifecycle == .stopped,
          prepareForNewCommand() else { return false }
    return stageAndPerform(.finish(
      closureID: SessionClosure.ID(),
      sessionID: session.id,
      finishedAt: Date()
    ))
  }

  func retryPendingCommands() {
    while let pending = pendingCommands.first {
      do {
        let result = try perform(pending)
        guard apply(result, for: pending) else { return }
      } catch let logicError as CookingSessionLogicError {
        present(.command(logicError))
        return
      } catch {
        present(.read)
        return
      }
    }
  }
}

extension CookingSessionPresentationModel {
  func prepareForNewCommand() -> Bool {
    guard !pendingCommands.isEmpty else { return true }
    retryPendingCommands()
    return pendingCommands.isEmpty
  }

  func stageAndPerform(_ pending: PendingCookingSessionCommand) -> Bool {
    pendingCommands = [pending]
    persistPendingCommands()
    retryPendingCommands()
    return !pendingCommands.contains(pending)
  }

  func stageIndependentAndPerform(_ pending: PendingCookingSessionCommand) -> Bool {
    guard pendingCommands.allSatisfy({ $0.isIndependentActivity(for: pending.sessionID) }) else {
      return false
    }
    pendingCommands.append(pending)
    persistPendingCommands()
    retryPendingCommands()
    return !pendingCommands.contains(pending)
  }

  func perform(_ pending: PendingCookingSessionCommand) throws -> CookingSessionCommandResult {
    switch pending {
    case let .start(sessionID, recipeID, revisionID, startedAt):
      try service.start(StartCookingSessionIntention(
        sessionID: sessionID,
        recipeID: recipeID,
        recipeRevisionID: revisionID,
        startedAt: startedAt
      ))
    case let .stop(factID, sessionID, authoredAt):
      try service.perform(.stop(fact(factID, sessionID, authoredAt)))
    case let .resume(factID, sessionID, authoredAt):
      try service.perform(.resume(fact(factID, sessionID, authoredAt)))
    case let .progress(factID, sessionID, authoredAt, progress):
      try service.perform(.progress(fact(factID, sessionID, authoredAt), progress))
    case let .replaceWorkingScale(factID, sessionID, authoredAt, scale):
      try service.perform(.replaceWorkingScale(fact(factID, sessionID, authoredAt), scale))
    case let .finish(closureID, sessionID, finishedAt):
      try service.perform(.finish(FinishCookingSessionIntention(
        closureID: closureID,
        sessionID: sessionID,
        finishedAt: finishedAt,
        hasMeaningfulDraft: false
      )))
    }
  }

  func fact(
    _ id: SessionFact.ID,
    _ sessionID: CookingSession.ID,
    _ authoredAt: Date
  ) -> SessionFactIntention {
    SessionFactIntention(id: id, sessionID: sessionID, authoredAt: authoredAt)
  }

  func apply(
    _ result: CookingSessionCommandResult,
    for pending: PendingCookingSessionCommand
  ) -> Bool {
    switch result {
    case let .accepted(session):
      guard pendingCommands.first == pending else { return false }
      pendingCommands.removeFirst()
      persistPendingCommands()
      issue = nil
      isShowingIssue = false
      upsert(session)
      applySelection(for: session, pending: pending)
      return true
    case let .attention(attention):
      present(.attention(attention))
      return false
    }
  }

  func applySelection(
    for session: CookingSessionProjection,
    pending: PendingCookingSessionCommand
  ) {
    if session.lifecycle == .finished {
      sessions.removeAll { $0.id == session.id }
      finishedSessionCount += 1
      if currentSessionID == session.id { select(nil) }
    } else {
      select(pending.sessionID)
    }
  }

  func persistPendingCommands() {
    store.pendingCommands = pendingCommands
  }

  func applyingPendingCommands(
    to session: CookingSessionProjection
  ) -> CookingSessionProjection {
    var progress = session.progress
    var workingScale = session.workingScale
    for pending in pendingCommands where pending.sessionID == session.id {
      switch pending {
      case let .progress(_, _, _, value):
        progress.removeAll { $0.target == value.target }
        progress.append(value)
      case let .replaceWorkingScale(_, _, _, scale):
        workingScale = scale
      case .start, .stop, .resume, .finish:
        break
      }
    }
    return session.replacing(progress: progress, workingScale: workingScale)
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

private extension CookingSessionProjection {
  func replacing(
    progress: [SessionProgress],
    workingScale: SessionWorkingScale?
  ) -> Self {
    CookingSessionProjection(
      id: id,
      snapshot: snapshot,
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
