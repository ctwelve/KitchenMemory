// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// One stable request to begin cooking from an exact Recipe Revision.
public struct StartCookingSessionIntention: Equatable, Sendable {
  /// New Session identity allocated once and retained with this intention for retry.
  public let sessionID: CookingSession.ID
  /// Stable Recipe provenance for the exact revision selected at Start.
  public let recipeID: Recipe.ID
  /// Exact immutable Recipe Revision to capture into the Session-owned snapshot.
  public let recipeRevisionID: RecipeRevision.ID
  /// Descriptive Start time retained unchanged on retry; it is not conflict authority.
  public let startedAt: Date
  /// Optional initial scale to capture; nil uses the snapshot's ordinary initial scale.
  public let workingScale: RecipeScale?

  /// Creates a Start request with caller-retained identity, revision provenance, time, and initial scale.
  /// Preparing this value does not read or persist a Session.
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
  /// Stable Fact identity for this accepted intention; reuse only with identical authored intent.
  public let id: SessionFact.ID
  /// Identity of the existing Session addressed by this intention.
  public let sessionID: CookingSession.ID
  /// Descriptive authored time retained unchanged on retry; causal evidence establishes ordering.
  public let authoredAt: Date

  /// Freezes Fact identity, Session scope, and authored time for one command and its retries.
  public init(id: SessionFact.ID, sessionID: CookingSession.ID, authoredAt: Date) {
    self.id = id
    self.sessionID = sessionID
    self.authoredAt = authoredAt
  }
}

/// Stable Closure identity plus local Finish preconditions supplied by presentation.
public struct FinishCookingSessionIntention: Equatable, Sendable {
  /// Stable Closure and Finish retry identity.
  public let closureID: SessionClosure.ID
  /// Identity of the existing Session addressed by this intention.
  public let sessionID: CookingSession.ID
  /// Descriptive Finish time; it does not choose among competing Closures.
  public let finishedAt: Date
  /// Whether presentation still retains meaningful unconfirmed Entry text; true blocks Finish.
  public let hasMeaningfulDraft: Bool
  /// Optional deletion to commit locally with Finish, retaining lifecycle and disposition separately.
  public let deletion: FinishSessionDeletion?

  /// Freezes Finish identity and presentation preconditions, optionally including atomic local deletion.
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

/// Frozen deletion identity and time for a single Finish-and-Delete intention.
public struct FinishSessionDeletion: Equatable, Sendable {
  /// Stable deletion-marker identity retained for exact retry.
  public let id: SessionDeletion.ID
  /// Descriptive deletion time retained unchanged on retry.
  public let deletedAt: Date

  /// Freezes the deletion marker to retain with a Finish-and-Delete request.
  public init(id: SessionDeletion.ID, deletedAt: Date) {
    self.id = id
    self.deletedAt = deletedAt
  }
}

/// An explicit choice among every locally observed competing Closure, without modifying either Closure.
public struct ResolveCookingSessionClosureIntention: Equatable, Sendable {
  /// Stable resolution Fact identity, owning Session, and descriptive time.
  public let fact: SessionFactIntention
  /// Observed Closure selected by the person; it must belong to the observed set.
  public let selectedClosureID: SessionClosure.ID
  /// Complete observed competing-Closure set in stable order; later arrivals require attention again.
  public let observedClosureIDs: [SessionClosure.ID]

  /// Freezes an explicit Closure choice and sorts the observed set without removing duplicates.
  /// Logic validates completeness, distinctness, and membership at acceptance.
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

/// Frozen request for a new Active Session inheriting one Finished Session's self-contained baseline.
public struct ContinueCookingSessionIntention: Equatable, Sendable {
  /// New Session identity allocated once and retained with this intention for retry.
  public let sessionID: CookingSession.ID
  /// Finished Session supplying inherited context; its closed projection remains immutable.
  public let sourceSessionID: CookingSession.ID
  /// Descriptive Start time retained unchanged on retry; it is not conflict authority.
  public let startedAt: Date

  /// Freezes a new Session identity and Finished-source provenance before acceptance.
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

/// Explicit request to hide a Session without stopping, finishing, or pruning it.
public struct DeleteCookingSessionIntention: Equatable, Sendable {
  /// Stable deletion-marker and retry identity.
  public let deletionID: SessionDeletion.ID
  /// Identity of the existing Session addressed by this intention.
  public let sessionID: CookingSession.ID
  /// Descriptive deletion time retained unchanged on retry.
  public let deletedAt: Date

  /// Freezes one deletion marker for exact retry without changing Session lifecycle.
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

/// Explicit restoration of every observed unresolved deletion marker for one Session.
public struct RestoreCookingSessionIntention: Equatable, Sendable {
  /// Stable command identity used to derive one resolution identity per observed deletion.
  public typealias ID = StableIdentifier<RestoreCookingSessionIntention>

  /// Stable Restore command identity retained with the full observed deletion set for retry.
  public let id: ID
  /// Identity of the existing Session addressed by this intention.
  public let sessionID: CookingSession.ID
  /// Descriptive restoration time retained unchanged on retry.
  public let restoredAt: Date
  /// Complete observed unresolved deletion set in stable order; acceptance revalidates this frontier.
  public let observedDeletionIDs: [SessionDeletion.ID]

  /// Freezes Restore identity and sorts the observed deletion set without removing duplicates.
  /// Logic revalidates that set against retained evidence before acceptance.
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
  /// Makes an Active Session dormant through one immutable lifecycle Fact.
  case stop(SessionFactIntention)
  /// Makes a Stopped Session active through one immutable lifecycle Fact.
  case resume(SessionFactIntention)
  /// Records a complete resulting state for a Session-owned snapshot target.
  case progress(SessionFactIntention, SessionProgress)
  /// Records the complete resulting scale and structured working quantities, never a multiplier delta.
  case replaceWorkingScale(SessionFactIntention, SessionWorkingScale)
  /// Confirms exact Entry text and optional snapshot target; the Fact identity becomes Entry identity.
  case submitEntry(SessionFactIntention, text: String, target: SessionProgressTarget?)
  /// Records complete replacement wording and resulting target for an existing Entry.
  case reviseEntry(
    SessionFactIntention,
    entryID: SessionEntry.ID,
    text: String,
    target: SessionProgressTarget?
  )
  /// Changes an existing Entry's target while retaining its current wording in a revision Fact.
  case retargetEntry(
    SessionFactIntention,
    entryID: SessionEntry.ID,
    target: SessionProgressTarget?
  )
  /// Withdraws an Entry from current projection while retaining its earlier authored evidence.
  case withdrawEntry(SessionFactIntention, entryID: SessionEntry.ID)
  /// Records an optional coarse assessment while the Session is Active.
  case setOutcome(SessionFactIntention, SessionOutcome)
  /// Explicitly removes the current Outcome through retained immutable evidence.
  case clearOutcome(SessionFactIntention)
  /// Seals the observed conflict-free frontier after meaningful local drafts are addressed.
  case finish(FinishCookingSessionIntention)
  /// Hides the Session through disposition evidence without changing lifecycle.
  case delete(DeleteCookingSessionIntention)
  /// Resolves the complete observed deletion frontier while preserving Session lifecycle.
  case restore(RestoreCookingSessionIntention)
  /// Selects one observed competing Closure through a narrow resolution Fact.
  case resolveClosure(ResolveCookingSessionClosureIntention)
  /// Creates a new Active Session from a Finished source without reopening it.
  case continueSession(ContinueCookingSessionIntention)
}

/// Classified evidence or attention produced while validating, accepting, or retrying a command.
public enum CookingSessionCommandResult: Equatable, Sendable {
  /// The current Session reconstructs successfully after acceptance, retry, or a choice needing no append.
  /// This is local evidence, not proof of remote synchronization.
  case accepted(CookingSessionProjection)
  /// Current evidence or preconditions require presentation.
  /// This can arise before an append or while classifying retained evidence after acceptance.
  case attention(CookingSessionAttention)
}

/// Retained evidence that requires presentation rather than an automatic choice.
public enum CookingSessionAttention: Equatable, Sendable {
  /// Retained evidence is insufficient or unsupported; arrival of additional data may make it readable.
  case unavailable(UnavailableSession)
  /// Retained evidence positively violates reconstruction invariants and needs explicit recovery.
  case recovery(SessionRecovery)
  /// The current lifecycle prevents this intention; no new evidence is appended.
  case commandNotAllowed(lifecycle: SessionLifecycle)
  /// Conflicting projected values require an explicit choice before this operation.
  case conflicts([SessionConflict])
  /// The current unresolved deletion set differs from the Restore frontier the person observed.
  case competingDeletions([SessionDeletion.ID])
  /// Finish is blocked by meaningful unconfirmed local Entry text.
  case meaningfulDraft
  /// The reconstructed Session has no unresolved deletion requiring restoration.
  case restoreNotNeeded
}

/// Presentation-independent failures while reading, preparing, appending, or classifying a command.
public enum CookingSessionLogicError: Error, Equatable {
  /// The source Recipe cannot be read as maintained content for Start.
  case recipeNotFound
  /// The source Recipe belongs to another Kitchen.
  case recipeOutsideKitchen
  /// The exact source revision is absent from retained Recipe history.
  case recipeRevisionNotFound
  /// Retained Session evidence belongs outside this Logic instance's Kitchen.
  case sessionOutsideKitchen
  /// The source cannot supply a complete self-contained Execution Snapshot.
  case insufficientSnapshot
  /// A retained identity describes a different intention and cannot be reused.
  case intentionIdentityCollision
  /// The source Recipe repository read failed.
  case recipeReadFailed
  /// Session evidence could not be read or the required Session was absent.
  case sessionReadFailed
  /// The local repository append failed; callers retain the exact intention for retry.
  case sessionWriteFailed
  /// Canonical evidence encoding failed before acceptance.
  case encodingFailed
  /// The requested payload, target, or observed choice set violates this operation's preconditions.
  case invalidIntention
}
