// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain

/// One stable request to begin cooking from an exact Recipe Revision.
public struct StartCookingSessionIntention: Equatable, Sendable {
  public let sessionID: CookingSession.ID
  public let recipeID: Recipe.ID
  public let recipeRevisionID: RecipeRevision.ID
  public let startedAt: Date
  public let workingScale: RecipeScale?

  public init(
    sessionID: CookingSession.ID,
    recipeID: Recipe.ID,
    recipeRevisionID: RecipeRevision.ID,
    startedAt: Date,
    workingScale: RecipeScale? = nil
  ) {
    self.sessionID = sessionID
    self.recipeID = recipeID
    self.recipeRevisionID = recipeRevisionID
    self.startedAt = startedAt
    self.workingScale = workingScale
  }
}

/// Stable identity and descriptive time shared by one immutable Session Fact.
public struct SessionFactIntention: Equatable, Sendable {
  public let id: SessionFact.ID
  public let sessionID: CookingSession.ID
  public let authoredAt: Date

  public init(id: SessionFact.ID, sessionID: CookingSession.ID, authoredAt: Date) {
    self.id = id
    self.sessionID = sessionID
    self.authoredAt = authoredAt
  }
}

/// Stable Closure identity plus local Finish preconditions supplied by presentation.
public struct FinishCookingSessionIntention: Equatable, Sendable {
  public let closureID: SessionClosure.ID
  public let sessionID: CookingSession.ID
  public let finishedAt: Date
  public let hasMeaningfulDraft: Bool
  public let deletion: FinishSessionDeletion?

  public init(
    closureID: SessionClosure.ID,
    sessionID: CookingSession.ID,
    finishedAt: Date,
    hasMeaningfulDraft: Bool,
    deletion: FinishSessionDeletion? = nil
  ) {
    self.closureID = closureID
    self.sessionID = sessionID
    self.finishedAt = finishedAt
    self.hasMeaningfulDraft = hasMeaningfulDraft
    self.deletion = deletion
  }
}

public struct FinishSessionDeletion: Equatable, Sendable {
  public let id: SessionDeletion.ID
  public let deletedAt: Date

  public init(id: SessionDeletion.ID, deletedAt: Date) {
    self.id = id
    self.deletedAt = deletedAt
  }
}

public struct ResolveCookingSessionClosureIntention: Equatable, Sendable {
  public let fact: SessionFactIntention
  public let selectedClosureID: SessionClosure.ID
  public let observedClosureIDs: [SessionClosure.ID]

  public init(
    fact: SessionFactIntention,
    selectedClosureID: SessionClosure.ID,
    observedClosureIDs: [SessionClosure.ID]
  ) {
    self.fact = fact
    self.selectedClosureID = selectedClosureID
    self.observedClosureIDs = observedClosureIDs.sorted {
      $0.rawValue.uuidString < $1.rawValue.uuidString
    }
  }
}

public struct ContinueCookingSessionIntention: Equatable, Sendable {
  public let sessionID: CookingSession.ID
  public let sourceSessionID: CookingSession.ID
  public let startedAt: Date

  public init(
    sessionID: CookingSession.ID,
    sourceSessionID: CookingSession.ID,
    startedAt: Date
  ) {
    self.sessionID = sessionID
    self.sourceSessionID = sourceSessionID
    self.startedAt = startedAt
  }
}

public struct DeleteCookingSessionIntention: Equatable, Sendable {
  public let deletionID: SessionDeletion.ID
  public let sessionID: CookingSession.ID
  public let deletedAt: Date

  public init(
    deletionID: SessionDeletion.ID,
    sessionID: CookingSession.ID,
    deletedAt: Date
  ) {
    self.deletionID = deletionID
    self.sessionID = sessionID
    self.deletedAt = deletedAt
  }
}

public struct RestoreCookingSessionIntention: Equatable, Sendable {
  public typealias ID = StableIdentifier<RestoreCookingSessionIntention>

  public let id: ID
  public let sessionID: CookingSession.ID
  public let restoredAt: Date
  public let observedDeletionIDs: [SessionDeletion.ID]

  public init(
    id: ID,
    sessionID: CookingSession.ID,
    restoredAt: Date,
    observedDeletionIDs: [SessionDeletion.ID]
  ) {
    self.id = id
    self.sessionID = sessionID
    self.restoredAt = restoredAt
    self.observedDeletionIDs = observedDeletionIDs.sorted {
      $0.rawValue.uuidString < $1.rawValue.uuidString
    }
  }
}

/// Every non-Start Cooking Session intention crosses one dispatch interface.
public enum CookingSessionIntention: Equatable, Sendable {
  case stop(SessionFactIntention)
  case resume(SessionFactIntention)
  case progress(SessionFactIntention, SessionProgress)
  case replaceWorkingScale(SessionFactIntention, SessionWorkingScale)
  case submitEntry(SessionFactIntention, text: String, target: SessionProgressTarget?)
  case reviseEntry(
    SessionFactIntention,
    entryID: SessionEntry.ID,
    text: String,
    target: SessionProgressTarget?
  )
  case retargetEntry(
    SessionFactIntention,
    entryID: SessionEntry.ID,
    target: SessionProgressTarget?
  )
  case withdrawEntry(SessionFactIntention, entryID: SessionEntry.ID)
  case setOutcome(SessionFactIntention, SessionOutcome)
  case clearOutcome(SessionFactIntention)
  case finish(FinishCookingSessionIntention)
  case delete(DeleteCookingSessionIntention)
  case restore(RestoreCookingSessionIntention)
  case resolveClosure(ResolveCookingSessionClosureIntention)
  case continueSession(ContinueCookingSessionIntention)
}

/// The classified result after a command has crossed its local durability boundary.
public enum CookingSessionCommandResult: Equatable, Sendable {
  case accepted(CookingSessionProjection)
  case attention(CookingSessionAttention)
}

/// Retained evidence that requires presentation rather than an automatic choice.
public enum CookingSessionAttention: Equatable, Sendable {
  case unavailable(UnavailableSession)
  case recovery(SessionRecovery)
  case commandNotAllowed(lifecycle: SessionLifecycle)
  case conflicts([SessionConflict])
  case competingDeletions([SessionDeletion.ID])
  case meaningfulDraft
  case restoreNotNeeded
}

/// Presentation-independent failures that prevent a command from being attempted.
public enum CookingSessionLogicError: Error, Equatable {
  case recipeNotFound
  case recipeOutsideKitchen
  case recipeRevisionNotFound
  case sessionOutsideKitchen
  case insufficientSnapshot
  case intentionIdentityCollision
  case recipeReadFailed
  case sessionReadFailed
  case sessionWriteFailed
  case encodingFailed
  case invalidIntention
}
