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
          session.lifecycle == .active || session.lifecycle == .stopped else { return false }
    if currentEntryDraft?.isMeaningful == true {
      present(.attention(.meaningfulDraft))
      return false
    }
    discardCurrentEntryDraft()
    guard prepareForNewCommand() else { return false }
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

  func apply(
    _ result: CookingSessionCommandResult,
    for pending: PendingCookingSessionCommand
  ) -> Bool {
    switch PendingCookingSessionResolution(result: result, pending: pending) {
    case let .accepted(session):
      guard pendingCommands.first == pending else { return false }
      // Draft state crosses its local durability boundary before the outbox
      // identity is cleared. A process interruption can therefore replay the
      // accepted command, but can never strand or lose the user's text.
      applyDraftAcceptance(for: pending, session: session)
      pendingCommands.removeFirst()
      persistPendingCommands()
      issue = nil
      isShowingIssue = false
      upsert(session)
      applySelection(for: session, pending: pending)
      if pending.refreshesClassification { reload() }
      return true
    case .rejectedByFinishedSource:
      guard pendingCommands.first == pending else { return false }
      // Logic has definitively rejected this specific identity because its
      // source Session is already Finished. The command can never become
      // eligible on retry, while any exact local draft remains separately
      // durable for explicit continuation, copy, or discard.
      pendingCommands.removeFirst()
      persistPendingCommands()
      issue = nil
      isShowingIssue = false
      return true
    case let .retiredStaleRestore(attention):
      guard pendingCommands.first == pending else { return false }
      // Restore is consent to resolve one observed frontier. If concurrent
      // evidence changes that frontier, this durable command must not retry
      // forever or silently expand the user's original confirmation.
      pendingCommands.removeFirst()
      persistPendingCommands()
      reload()
      present(.attention(attention))
      return true
    case .retiredCompletedRestore:
      guard pendingCommands.first == pending else { return false }
      // Another replica may already have restored the observed frontier. The
      // local intention is then complete and safe to retire idempotently.
      pendingCommands.removeFirst()
      persistPendingCommands()
      issue = nil
      isShowingIssue = false
      reload()
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
    if case .delete = pending {
      if currentSessionID == session.id { select(nil, recordsVisit: false) }
      historyScope = nil
      observedFinishedSessionID = nil
      libraryDestination = .deletedItems
    } else if case .restore = pending {
      select(nil, recordsVisit: false)
      historyScope = nil
      observedFinishedSessionID = nil
      libraryDestination = .deletedItems
    } else if case .resolveClosure = pending {
      select(nil, recordsVisit: false)
      historyScope = nil
      observedFinishedSessionID = nil
      libraryDestination = .recovery
    } else if case .continueSession = pending {
      select(session.id)
      historyScope = nil
      libraryDestination = nil
      observedFinishedSessionID = nil
    } else if session.lifecycle == .finished {
      sessions.removeAll { $0.id == session.id }
      if currentSessionID == session.id { select(nil, recordsVisit: false) }
      historyScope = .all
      libraryDestination = nil
      observedFinishedSessionID = session.id
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

  func applyDraftAcceptance(
    for pending: PendingCookingSessionCommand,
    session: CookingSessionProjection
  ) {
    switch pending {
    case .submitEntry:
      removeDraft(for: pending.sessionID)
    case let .continueSession(newSessionID, sourceSessionID, _):
      guard let draft = entryDrafts.first(where: { $0.sessionID == sourceSessionID }) else { return }
      let mappedTarget = draft.target.flatMap { sourceTarget in
        session.snapshot.continuationBaseline?.targetMappings.first(where: {
          $0.sourceTarget == sourceTarget
        })?.target
      }
      moveDraft(from: sourceSessionID, to: newSessionID, target: mappedTarget)
    case .start, .stop, .resume, .progress, .replaceWorkingScale, .reviseEntry,
         .retargetEntry, .withdrawEntry, .setOutcome, .clearOutcome, .finish,
         .delete, .restore, .resolveClosure:
      break
    }
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

private enum PendingCookingSessionResolution {
  case accepted(CookingSessionProjection)
  case rejectedByFinishedSource
  case retiredStaleRestore(CookingSessionAttention)
  case retiredCompletedRestore
  case attention(CookingSessionAttention)

  init(
    result: CookingSessionCommandResult,
    pending: PendingCookingSessionCommand
  ) {
    switch (result, pending) {
    case let (.accepted(session), _):
      self = .accepted(session)
    case (.attention(.commandNotAllowed(lifecycle: .finished)), _):
      self = .rejectedByFinishedSource
    case let (.attention(.competingDeletions(deletionIDs)), .restore):
      self = .retiredStaleRestore(.competingDeletions(deletionIDs))
    case (.attention(.restoreNotNeeded), .restore):
      self = .retiredCompletedRestore
    case let (.attention(attention), _):
      self = .attention(attention)
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
