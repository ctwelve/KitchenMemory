// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Immutable acceptance evidence binding one Save identity to ancestry and complete content.
///
/// Manifest membership and the canonical revision digest are checked during projection;
/// this initializer only retains the supplied envelope.
public struct RecipeSaveEvidence: Equatable, Sendable {
  /// The caller-owned immutable operation identity.
  ///
  /// Exact retries reuse it with identical content; conflicting reuse requires rejection
  /// or recovery rather than another accepted effect.
  public let id: UUID
  /// The Kitchen ownership boundary for this value; transport identity cannot substitute for it.
  public let kitchenID: Kitchen.ID
  /// The stable maintained Recipe identity, independent of a particular Revision.
  public let recipeID: Recipe.ID
  /// The accepted immutable content identity bound to this Save.
  public let revisionID: RecipeRevision.ID
  /// The authored acceptance date, without electing currentness.
  public let savedAt: Date
  /// The codec version for the complete parent UUID set.
  public let ancestryFormatVersion: Int
  /// Canonical complete parent UUID bytes; empty data represents a root Revision.
  public let parentRevisionIDsData: Data
  /// The codec version for the ordered payload manifest.
  public let payloadManifestFormatVersion: Int
  /// The exact expected child-row identities, including authored ordering.
  public let payloadManifestData: Data
  /// The codec version whose canonical content bytes produced the commitment.
  public let revisionFormatVersion: Int
  /// SHA-256 committing the complete canonical Revision, excluding local image availability.
  public let revisionDigest: Data

  /// Retains the supplied immutable envelope without validating completeness or integrity.
  ///
  /// Use the evidence projector before presenting ordinary domain content; keep the
  /// identity and bytes unchanged when transporting or retrying this evidence.
  public init(
    id: UUID, kitchenID: Kitchen.ID, recipeID: Recipe.ID,
    revisionID: RecipeRevision.ID, savedAt: Date,
    ancestryFormatVersion: Int, parentRevisionIDsData: Data,
    payloadManifestFormatVersion: Int, payloadManifestData: Data,
    revisionFormatVersion: Int, revisionDigest: Data
  ) {
    self.id = id
    self.kitchenID = kitchenID
    self.recipeID = recipeID
    self.revisionID = revisionID
    self.savedAt = savedAt
    self.ancestryFormatVersion = ancestryFormatVersion
    self.parentRevisionIDsData = parentRevisionIDsData
    self.payloadManifestFormatVersion = payloadManifestFormatVersion
    self.payloadManifestData = payloadManifestData
    self.revisionFormatVersion = revisionFormatVersion
    self.revisionDigest = revisionDigest
  }
}

/// Immutable evidence choosing an accepted Revision while naming observed prior selections.
///
/// Causal heads determine currentness. The date supports history presentation and
/// does not choose among competing selections.
public struct RecipeSelectionEvidence: Equatable, Sendable {
  /// The caller-owned immutable operation identity.
  ///
  /// Exact retries reuse it with identical content; conflicting reuse requires rejection
  /// or recovery rather than another accepted effect.
  public let id: UUID
  /// The Kitchen ownership boundary for this value; transport identity cannot substitute for it.
  public let kitchenID: Kitchen.ID
  /// The stable maintained Recipe identity, independent of a particular Revision.
  public let recipeID: Recipe.ID
  /// The existing accepted Revision selected by this immutable choice.
  public let selectedRevisionID: RecipeRevision.ID
  /// The authored selection date; it does not break concurrent selection ties.
  public let selectedAt: Date
  /// The codec version for the observed Selection UUID set.
  public let frontierFormatVersion: Int
  /// Canonical bytes naming the complete observed prior Selection frontier.
  public let observedSelectionIDsData: Data

  /// Retains the supplied immutable envelope without validating completeness or integrity.
  ///
  /// Use the evidence projector before presenting ordinary domain content; keep the
  /// identity and bytes unchanged when transporting or retrying this evidence.
  public init(
    id: UUID, kitchenID: Kitchen.ID, recipeID: Recipe.ID,
    selectedRevisionID: RecipeRevision.ID, selectedAt: Date,
    frontierFormatVersion: Int, observedSelectionIDsData: Data
  ) {
    self.id = id
    self.kitchenID = kitchenID
    self.recipeID = recipeID
    self.selectedRevisionID = selectedRevisionID
    self.selectedAt = selectedAt
    self.frontierFormatVersion = frontierFormatVersion
    self.observedSelectionIDsData = observedSelectionIDsData
  }
}

/// A retained instruction hiding a stable Recipe without removing its payload.
///
/// A missing legacy date preserves deletion but prevents age-based pruning.
public struct RecipeDeletionEvidence: Equatable, Sendable {
  /// The caller-owned immutable operation identity.
  ///
  /// Exact retries reuse it with identical content; conflicting reuse requires rejection
  /// or recovery rather than another accepted effect.
  public let id: UUID
  /// The Kitchen ownership boundary for this value; transport identity cannot substitute for it.
  public let kitchenID: Kitchen.ID
  /// The stable maintained Recipe identity, independent of a particular Revision.
  public let recipeID: Recipe.ID
  /// The authored deletion date, or nil for undated legacy evidence that must not age into pruning.
  public let deletedAt: Date?

  /// Retains the supplied immutable envelope without validating completeness or integrity.
  ///
  /// Use the evidence projector before presenting ordinary domain content; keep the
  /// identity and bytes unchanged when transporting or retrying this evidence.
  public init(
    id: UUID, kitchenID: Kitchen.ID, recipeID: Recipe.ID, deletedAt: Date?
  ) {
    self.id = id
    self.kitchenID = kitchenID
    self.recipeID = recipeID
    self.deletedAt = deletedAt
  }
}

/// One immutable resolution of an explicitly observed Recipe deletion.
///
/// A nil Kitchen identity supports legacy evidence; Recipe ownership still applies.
/// Unobserved concurrent deletions remain unresolved.
public struct RecipeRestorationEvidence: Equatable, Sendable {
  /// The caller-owned immutable operation identity.
  ///
  /// Exact retries reuse it with identical content; conflicting reuse requires rejection
  /// or recovery rather than another accepted effect.
  public let id: UUID
  /// The observed deletion resolved by this immutable restoration.
  public let deletionID: UUID
  /// The Kitchen ownership boundary for this value; transport identity cannot substitute for it.
  public let kitchenID: Kitchen.ID?
  /// The stable maintained Recipe identity, independent of a particular Revision.
  public let recipeID: Recipe.ID
  /// The authored restoration date, or nil when legacy evidence has no trustworthy date.
  public let restoredAt: Date?

  /// Retains the supplied immutable envelope without validating completeness or integrity.
  ///
  /// Use the evidence projector before presenting ordinary domain content; keep the
  /// identity and bytes unchanged when transporting or retrying this evidence.
  public init(
    id: UUID, deletionID: UUID, kitchenID: Kitchen.ID?,
    recipeID: Recipe.ID, restoredAt: Date?
  ) {
    self.id = id
    self.deletionID = deletionID
    self.kitchenID = kitchenID
    self.recipeID = recipeID
    self.restoredAt = restoredAt
  }
}

/// Compact authority retained after Recipe payload removal to prevent silent resurrection.
///
/// Projection verifies its canonical frontier and digest. Any coexisting authority or
/// payload is classified as late evidence requiring recovery.
public struct RecipePruneEvidence: Equatable, Sendable {
  /// The caller-owned immutable operation identity.
  ///
  /// Exact retries reuse it with identical content; conflicting reuse requires rejection
  /// or recovery rather than another accepted effect.
  public let id: UUID
  /// The Kitchen ownership boundary for this value; transport identity cannot substitute for it.
  public let kitchenID: Kitchen.ID
  /// The stable maintained Recipe identity, independent of a particular Revision.
  public let recipeID: Recipe.ID
  /// The local pruning date used with the stored retention promise.
  public let prunedAt: Date
  /// The minimum promised retention horizon; expiry also requires repository eligibility checks.
  public let antiResurrectionUntil: Date
  /// The codec version interpreting the compact authority frontier.
  public let frontierFormatVersion: Int
  /// Canonical bytes retaining ancestry, selection heads, and disposition identities.
  public let frontierData: Data
  /// SHA-256 of the compact frontier bytes, checked before accepting pruned authority.
  public let frontierDigest: Data

  /// Retains the supplied immutable envelope without validating completeness or integrity.
  ///
  /// Use the evidence projector before presenting ordinary domain content; keep the
  /// identity and bytes unchanged when transporting or retrying this evidence.
  public init(
    id: UUID, kitchenID: Kitchen.ID, recipeID: Recipe.ID,
    prunedAt: Date, antiResurrectionUntil: Date,
    frontierFormatVersion: Int, frontierData: Data, frontierDigest: Data
  ) {
    self.id = id
    self.kitchenID = kitchenID
    self.recipeID = recipeID
    self.prunedAt = prunedAt
    self.antiResurrectionUntil = antiResurrectionUntil
    self.frontierFormatVersion = frontierFormatVersion
    self.frontierData = frontierData
    self.frontierDigest = frontierDigest
  }
}

/// The unordered retained material for reconstructing one Kitchen-owned Recipe.
///
/// Exact duplicate identities coalesce; conflicting identity reuse requires recovery.
/// Construction does not validate completeness, ownership, encodings, or graph shape.
public struct RecipeAuthorityEvidence: Equatable, Sendable {
  /// The Kitchen ownership boundary for this value; transport identity cannot substitute for it.
  public let kitchenID: Kitchen.ID
  /// The stable maintained Recipe identity, independent of a particular Revision.
  public let recipeID: Recipe.ID
  /// Unordered immutable Save envelopes; exact physical duplicates may be present.
  public let saves: [RecipeSaveEvidence]
  /// Unordered Selection envelopes whose causal graph elects current content.
  public let selections: [RecipeSelectionEvidence]
  /// Available content payloads; a partial set must not be presented as a complete Recipe.
  public let revisions: [RecipeRevision]
  /// Independent retained instructions hiding the aggregate.
  public let deletions: [RecipeDeletionEvidence]
  /// Resolutions of explicitly observed deletions; unseen deletions remain unresolved.
  public let restorations: [RecipeRestorationEvidence]
  /// Compact anti-resurrection evidence retained after payload removal.
  public let prunes: [RecipePruneEvidence]

  /// Collects retained evidence without sorting, coalescing, or interpreting it.
  ///
  /// Projection classifies missing material separately from contradictory evidence.
  public init(
    kitchenID: Kitchen.ID,
    recipeID: Recipe.ID,
    saves: [RecipeSaveEvidence],
    selections: [RecipeSelectionEvidence],
    revisions: [RecipeRevision],
    deletions: [RecipeDeletionEvidence] = [],
    restorations: [RecipeRestorationEvidence] = [],
    prunes: [RecipePruneEvidence] = []
  ) {
    self.kitchenID = kitchenID
    self.recipeID = recipeID
    self.saves = saves
    self.selections = selections
    self.revisions = revisions
    self.deletions = deletions
    self.restorations = restorations
    self.prunes = prunes
  }
}

/// Accepted immutable content annotated relative to the selected Revision and ancestry.
public struct ProjectedRecipeRevision: Equatable, Sendable {
  /// A presentation role derived from selection and ancestry rather than revision numbers.
  public enum State: Equatable, Sendable {
    /// The sole Revision chosen by all surviving Selection heads.
    case current
    /// An ancestor of the current Revision that is not itself marked as a reconciliation.
    case previous
    /// A surviving Revision outside the current ancestry, excluding reconciliation nodes.
    case competing
    /// A noncurrent Revision with multiple accepted parents, regardless of its current ancestry role.
    case reconciled
  }

  /// The accepted content value; presentation state does not mutate it.
  public let revision: RecipeRevision
  /// The ancestry and selection role derived for this current authority projection.
  public let state: State
}

/// A reconstructable Recipe and its accepted Revision history.
///
/// The projector constructs exactly one current Revision; `current` relies on that invariant.
public struct AvailableRecipeAuthority: Equatable, Sendable {
  /// The stable identity with its compatibility pointer populated from validated Selection evidence.
  public let recipe: Recipe
  /// Accepted Revisions in canonical identity order, including exactly one current value.
  public let revisions: [ProjectedRecipeRevision]

  /// The sole current Revision, relying on the projector’s construction invariant.
  ///
  /// This accessor traps if an internally constructed value has no current Revision.
  public var current: RecipeRevision {
    // Construction always includes exactly one current projection.
    // swiftlint:disable:next force_unwrapping
    revisions.first { $0.state == .current }!.revision
  }
}

/// Missing or unsupported material that prevents complete reconstruction without proving corruption.
public enum RecipeAuthorityUnavailableReason: Equatable, Sendable {
  /// No immutable Save acceptance is retained for this Recipe.
  case noSaveEvidence
  /// No immutable Selection is retained to determine current content.
  case noSelectionEvidence
  /// Retained evidence declares a codec version this reader does not understand.
  case unsupportedFormat(Int)
  /// A content Revision is present without its Save acceptance evidence.
  case missingSave(RecipeRevision.ID)
  /// Save evidence is present before its complete Revision payload arrives.
  case missingRevision(RecipeRevision.ID)
  /// An accepted Revision names an ancestor whose Save evidence is absent.
  case missingParent(RecipeRevision.ID)
  /// A Selection names a prior choice whose evidence is absent.
  case missingSelection(UUID)
  /// Available child rows form a strict subset of the committed manifest.
  case incompleteManifest(RecipeRevision.ID)
  /// A restoration names a deletion whose evidence is absent.
  case missingDeletion(UUID)
}

/// A positive contradiction in retained authority that cannot be resolved by choosing a clock winner.
public enum RecipeAuthorityRecoveryReason: Equatable, Sendable {
  /// One immutable command identity is reused with contradictory evidence.
  case commandCollision(UUID)
  /// One Revision identity is reused with different content values.
  case payloadCollision(RecipeRevision.ID)
  /// Evidence disagrees with the aggregate’s Recipe or Kitchen identity.
  case crossOwnership
  /// Authority bytes fail layout, canonicality, or frontier digest checks.
  case malformedEncoding
  /// Available child identities or ordering contradict the committed payload manifest.
  case manifestMismatch(RecipeRevision.ID)
  /// Complete canonical content does not match its Save commitment.
  case digestMismatch(RecipeRevision.ID)
  /// Revision parent evidence forms a causal cycle.
  case revisionCycle
  /// Selection predecessor evidence forms a causal cycle.
  case selectionCycle
  /// A Selection points to a Revision with no accepted Save in the retained set.
  case selectedRevisionIsNotAccepted(RecipeRevision.ID)
  /// Surviving causal Selection heads choose distinct Revisions and require explicit reconciliation.
  case competingSelections([RecipeRevision.ID])
  /// Payload or full authority remains alongside valid compact pruning evidence.
  case lateEvidenceAfterPrune
}

/// The complete authority classification for one stable Recipe.
///
/// Deletion is independent of payload availability. Unavailable and recovery results
/// retain a reason rather than presenting a plausible partial Recipe.
public enum RecipeAuthorityProjection: Equatable, Sendable {
  /// Complete selected content with no unresolved deletion.
  case available(AvailableRecipeAuthority)
  /// Complete selected content retained behind at least one unresolved deletion.
  case deleted(AvailableRecipeAuthority)
  /// Validated compact authority with no coexisting payload or full authority evidence.
  case pruned
  /// Incomplete or unsupported retained material, without positive proof of corruption.
  case unavailable(RecipeAuthorityUnavailableReason)
  /// Contradictory retained material or competing choices requiring explicit recovery.
  case recovery(RecipeAuthorityRecoveryReason)
}
