// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// One complete local append boundary from the frozen V3 persistence contract.
public enum CookingSessionTransaction: Equatable, Sendable {
  /// One complete root with no continuation source fields.
  case start(CookingSessionRootEvidence)
  /// One ordinary immutable Fact for lifecycle or authored cooking evidence.
  case activity(SessionFactEvidence)
  /// One immutable Closure sealing a complete observed Session frontier.
  case finish(SessionClosureEvidence)
  /// One Closure and matching deletion marker committed together locally.
  case finishAndDelete(SessionClosureEvidence, SessionDeletionEvidence)
  /// One deletion marker independent of Session lifecycle.
  case delete(SessionDeletionEvidence)
  /// One resolution per observed deletion, all belonging to the same Session and Kitchen.
  case restore([SessionDeletionResolutionEvidence])
  /// One narrow conflict-resolution Fact selecting among observed competing Closures.
  case resolveClosure(SessionFactEvidence)
  /// One complete new root naming both its source Session and source Closure.
  case continueSession(CookingSessionRootEvidence)
}

/// Failures validating complete append envelopes or persistence-placeholder evidence.
public enum CookingSessionRepositoryError: Error, Equatable {
  /// The supplied records do not form the transaction's required complete local boundary.
  case incompleteTransaction
  /// A stored or submitted envelope contains schema placeholders rather than complete evidence.
  case placeholderBearingEvidence
}

/// Domain-facing access to complete, classified Cooking Session evidence.
///
/// Implementations retain immutable evidence and use the deterministic Domain
/// projector for every read. No managed object or transport metadata crosses
/// this seam.
@MainActor
public protocol CookingSessionRepository: AnyObject {
  /// Appends the complete local transaction or throws before local acceptance completes.
  /// Evidence remains immutable. Local atomicity does not require managed CloudKit to
  /// deliver the remote transaction together; Logic owns exact-intention retry checks.
  func append(_ transaction: CookingSessionTransaction) throws
  /// Returns all retained evidence needed to prepare an idempotent command.
  /// Partial or conflicting evidence remains retained; nil means no evidence is known.
  func evidence(id: CookingSession.ID) throws -> SessionEvidence?
  /// Classifies retained evidence as readable, Unavailable, or requiring Recovery.
  /// Returns nil for unknown identity; no partial domain Session is fabricated.
  func session(id: CookingSession.ID) throws -> SessionProjectionResult?
  /// Reads every known Session classification routed to this Kitchen.
  /// Evidence without a root remains visible through its retained Kitchen routing.
  func sessions(in kitchenID: Kitchen.ID) throws -> [SessionProjectionResult]
  /// Reads classifications through retained root Recipe provenance, even when the source Recipe is hidden.
  func sessions(for recipeID: Recipe.ID) throws -> [SessionProjectionResult]
  /// Reads classifications through root Recipe provenance within the specified Kitchen.
  func sessions(
    for recipeID: Recipe.ID,
    in kitchenID: Kitchen.ID
  ) throws -> [SessionProjectionResult]
  /// Returns up to `limit` classifications with retained Closure evidence, newest descriptive Finish time first.
  /// Results can still be Unavailable or Recovery; Closure presence alone does not prove a valid Finished Session.
  /// A nonpositive limit returns no results.
  func finishedSessions(
    in kitchenID: Kitchen.ID,
    limit: Int
  ) throws -> [SessionProjectionResult]
  /// Reads retained deletion markers for a Kitchen without requiring a Session root.
  func deletions(in kitchenID: Kitchen.ID) throws -> [SessionDeletionEvidence]
  /// Reads retained deletion markers for a Session, independently of its lifecycle.
  func deletions(for sessionID: CookingSession.ID) throws -> [SessionDeletionEvidence]
  /// Reads every physical deletion envelope with this logical marker identity.
  /// Conflicting duplicates must remain available for classification rather than choosing one.
  func deletions(id: SessionDeletion.ID) throws -> [SessionDeletionEvidence]
  /// Reads retained resolution envelopes for an observed deletion marker.
  func restorations(
    for deletionID: SessionDeletion.ID
  ) throws -> [SessionDeletionResolutionEvidence]
}
