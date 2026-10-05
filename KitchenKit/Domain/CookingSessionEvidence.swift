// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

// These related public values and their caller contracts form one domain boundary.
// Keep their documentation beside the declarations rather than splitting the contract.
// swiftlint:disable file_length

/// The identity and kind namespaces for one accepted cooking intention.
public enum SessionFact {
    /// A domain-typed stable UUID identity, independent of persistence record identity.
    public typealias ID = StableIdentifier<SessionFact>

    /// The supported intention kinds decoded from retained string-valued evidence.
    public enum Kind: String, CaseIterable, Sendable {
        /// An explicit move to dormant activity, with an empty payload.
        case stop
        /// An explicit move to Active activity, with an empty payload.
        case resume
        /// A resulting state for one Session-owned snapshot target.
        case progress
        /// A complete cook-specific scale replacement, independent of Recipe editing.
        case workingScale
        /// A submission, revision, or withdrawal of exact authored Entry text.
        case sessionEntry
        /// An explicit assessment set or clear intention.
        case sessionOutcome
        /// An explicit choice among observed competing Closures, without rewriting them.
        case conflictResolution
    }
}

/// Typed content for one immutable Fact; kind and target compatibility are checked during projection.
public enum SessionFactPayload: Codable, Equatable, Sendable {
    /// No content, as required by explicit Stop and Resume Facts.
    case empty
    /// A resulting state whose kind must match the Fact’s snapshot target.
    case progress(SessionProgressState)
    /// A complete working-scale replacement whose target amounts belong to the snapshot.
    case workingScale(SessionWorkingScale)
    /// An Entry operation whose identity and causal history must validate.
    case sessionEntry(SessionEntryOperation)
    /// An explicit assessment replacement or clearing intention.
    case sessionOutcome(SessionOutcomeChange)
    /// A choice naming all observed competing Closures and one selected candidate.
    case closureResolution(ClosureSelection)
}

/// An explicit choice among observed competing Closures.
///
/// Observed identities are sorted for encoding. Projection requires distinct existing
/// Closures, at least two candidates, and inclusion of the selected identity.
public struct ClosureSelection: Codable, Equatable, Sendable {
    /// The existing Closure explicitly chosen from the observed candidates.
    public let selectedClosureID: SessionClosure.ID
    /// Observed competing candidates sorted by UUID; duplicates are preserved for validation.
    public let observedClosureIDs: [SessionClosure.ID]

    /// Sorts candidate identities for canonical encoding without validating the choice.
    ///
    /// Projection requires the selected candidate to belong to a distinct multi-Closure
    /// frontier and the resolution Fact’s heads to equal that observed set.
    public init(
        selectedClosureID: SessionClosure.ID,
        observedClosureIDs: [SessionClosure.ID]
    ) {
        self.selectedClosureID = selectedClosureID
        self.observedClosureIDs = observedClosureIDs.sorted {
            $0.rawValue.uuidString < $1.rawValue.uuidString
        }
    }
}

/// One immutable cooking intention with causal heads and a canonical payload commitment.
///
/// Construction retains raw envelopes, including unknown kinds or formats. Projection
/// checks identity reuse, ownership, dependencies, target kind, and digest.
public struct SessionFactEvidence: Equatable, Sendable {
    /// The caller-owned immutable operation identity.
    ///
    /// Exact retries reuse it with identical content; conflicting reuse requires rejection
    /// or recovery rather than another accepted effect.
    public let id: SessionFact.ID
    /// The stable Cooking Session identity whose evidence owns this operation.
    public let sessionID: CookingSession.ID
    /// The Kitchen ownership boundary for this value; transport identity cannot substitute for it.
    public let kitchenID: Kitchen.ID
    /// The retained raw kind spelling, allowing unknown future kinds to remain evidence.
    public let kind: String
    /// An optional Session-owned target UUID; admissibility depends on kind and payload.
    public let targetSnapshotElementID: UUID?
    /// The authored history date, excluded from causal conflict winner decisions.
    public let authoredAt: Date
    /// The codec version interpreting the complete observed Session frontier.
    public let causalHeadsFormatVersion: Int
    /// Canonical observed predecessor UUID bytes, not a delivery-order index.
    public let causalHeadsData: Data
    /// The codec version interpreting the typed immutable payload.
    public let payloadFormatVersion: Int
    /// The complete canonical payload bytes, retained even when this reader cannot interpret them.
    public let payloadData: Data
    /// SHA-256 commitment to `payloadData`, checked before using payload meaning.
    public let payloadDigest: Data

    /// Retains the supplied immutable envelope without validating completeness or integrity.
    ///
    /// Use the evidence projector before presenting ordinary domain content; keep the
    /// identity and bytes unchanged when transporting or retrying this evidence.
    public init(
        id: SessionFact.ID,
        sessionID: CookingSession.ID,
        kitchenID: Kitchen.ID,
        kind: String,
        targetSnapshotElementID: UUID?,
        authoredAt: Date,
        causalHeadsFormatVersion: Int,
        causalHeadsData: Data,
        payloadFormatVersion: Int,
        payloadData: Data,
        payloadDigest: Data
    ) {
        self.id = id
        self.sessionID = sessionID
        self.kitchenID = kitchenID
        self.kind = kind
        self.targetSnapshotElementID = targetSnapshotElementID
        self.authoredAt = authoredAt
        self.causalHeadsFormatVersion = causalHeadsFormatVersion
        self.causalHeadsData = causalHeadsData
        self.payloadFormatVersion = payloadFormatVersion
        self.payloadData = payloadData
        self.payloadDigest = payloadDigest
    }
}

/// Immutable evidence sealing a snapshot and one complete observed cooking frontier.
///
/// All retained Closures must validate, including unselected competitors. Completion
/// dates explain history and never silently select among competing Closures.
public struct SessionClosureEvidence: Equatable, Sendable {
    /// The caller-owned immutable operation identity.
    ///
    /// Exact retries reuse it with identical content; conflicting reuse requires rejection
    /// or recovery rather than another accepted effect.
    public let id: SessionClosure.ID
    /// The stable Cooking Session identity whose evidence owns this operation.
    public let sessionID: CookingSession.ID
    /// The Kitchen ownership boundary for this value; transport identity cannot substitute for it.
    public let kitchenID: Kitchen.ID
    /// The authored Finish date, without electing a winner among competing Closures.
    public let finishedAt: Date
    /// The codec version for the exact observed frontier sealed by Finish.
    public let causalHeadsFormatVersion: Int
    /// Canonical heads whose ancestors define the complete closed cooking cone.
    public let causalHeadsData: Data
    /// The snapshot format this Closure commits, required to match the root.
    public let snapshotFormatVersion: Int
    /// The exact root snapshot commitment, required to match the retained root.
    public let snapshotDigest: Data
    /// The codec version for the reconstructed closed content commitment.
    public let projectionFormatVersion: Int
    /// SHA-256 of the reconstructed closed projection, which must contain no register conflicts.
    public let projectionDigest: Data
    /// Optional Outcome codec version; it must be present exactly when Outcome bytes are present.
    public let outcomeFormatVersion: Int?
    /// Optional canonical Outcome bytes, required to equal the closed projection’s assessment.
    public let outcomeData: Data?

    /// Retains the supplied immutable envelope without validating completeness or integrity.
    ///
    /// Use the evidence projector before presenting ordinary domain content; keep the
    /// identity and bytes unchanged when transporting or retrying this evidence.
    public init(
        id: SessionClosure.ID,
        sessionID: CookingSession.ID,
        kitchenID: Kitchen.ID,
        finishedAt: Date,
        causalHeadsFormatVersion: Int,
        causalHeadsData: Data,
        snapshotFormatVersion: Int,
        snapshotDigest: Data,
        projectionFormatVersion: Int,
        projectionDigest: Data,
        outcomeFormatVersion: Int?,
        outcomeData: Data?
    ) {
        self.id = id
        self.sessionID = sessionID
        self.kitchenID = kitchenID
        self.finishedAt = finishedAt
        self.causalHeadsFormatVersion = causalHeadsFormatVersion
        self.causalHeadsData = causalHeadsData
        self.snapshotFormatVersion = snapshotFormatVersion
        self.snapshotDigest = snapshotDigest
        self.projectionFormatVersion = projectionFormatVersion
        self.projectionDigest = projectionDigest
        self.outcomeFormatVersion = outcomeFormatVersion
        self.outcomeData = outcomeData
    }
}

/// Visibility evidence retaining the Session frontier and prior disposition heads it observed.
///
/// Deleting changes neither cooking lifecycle nor descendant Sessions.
public struct SessionDeletionEvidence: Equatable, Sendable {
    /// The caller-owned immutable operation identity.
    ///
    /// Exact retries reuse it with identical content; conflicting reuse requires rejection
    /// or recovery rather than another accepted effect.
    public let id: SessionDeletion.ID
    /// The stable Cooking Session identity whose evidence owns this operation.
    public let sessionID: CookingSession.ID
    /// The Kitchen ownership boundary for this value; transport identity cannot substitute for it.
    public let kitchenID: Kitchen.ID
    /// The authored visibility-change date; it does not finish or stop cooking.
    public let deletedAt: Date
    /// The codec version for the observed cooking frontier.
    public let sessionHeadsFormatVersion: Int
    /// The known Session heads observed at deletion, required to form an antichain.
    public let sessionHeadsData: Data
    /// The codec version for the observed independent disposition frontier.
    public let dispositionHeadsFormatVersion: Int
    /// Canonical prior deletion/restoration heads defining causal visibility context.
    public let dispositionHeadsData: Data

    /// Retains the supplied immutable envelope without validating completeness or integrity.
    ///
    /// Use the evidence projector before presenting ordinary domain content; keep the
    /// identity and bytes unchanged when transporting or retrying this evidence.
    public init(
        id: SessionDeletion.ID,
        sessionID: CookingSession.ID,
        kitchenID: Kitchen.ID,
        deletedAt: Date,
        sessionHeadsFormatVersion: Int,
        sessionHeadsData: Data,
        dispositionHeadsFormatVersion: Int,
        dispositionHeadsData: Data
    ) {
        self.id = id
        self.sessionID = sessionID
        self.kitchenID = kitchenID
        self.deletedAt = deletedAt
        self.sessionHeadsFormatVersion = sessionHeadsFormatVersion
        self.sessionHeadsData = sessionHeadsData
        self.dispositionHeadsFormatVersion = dispositionHeadsFormatVersion
        self.dispositionHeadsData = dispositionHeadsData
    }
}

/// An immutable restoration that must causally descend from the deletion it resolves.
///
/// Concurrent unobserved deletions remain hidden and may require attention.
public struct SessionDeletionResolutionEvidence: Equatable, Sendable {
    /// The caller-owned immutable operation identity.
    ///
    /// Exact retries reuse it with identical content; conflicting reuse requires rejection
    /// or recovery rather than another accepted effect.
    public let id: SessionDeletionResolution.ID
    /// The existing deletion this restoration explicitly resolves.
    public let deletionID: SessionDeletion.ID
    /// The stable Cooking Session identity whose evidence owns this operation.
    public let sessionID: CookingSession.ID
    /// The Kitchen ownership boundary for this value; transport identity cannot substitute for it.
    public let kitchenID: Kitchen.ID
    /// The authored restoration date, excluded from causal visibility decisions.
    public let restoredAt: Date
    /// The codec version for observed deletion/restoration context.
    public let dispositionHeadsFormatVersion: Int
    /// Canonical disposition heads; the resolved deletion must be a causal ancestor.
    public let dispositionHeadsData: Data

    /// Retains the supplied immutable envelope without validating completeness or integrity.
    ///
    /// Use the evidence projector before presenting ordinary domain content; keep the
    /// identity and bytes unchanged when transporting or retrying this evidence.
    public init(
        id: SessionDeletionResolution.ID,
        deletionID: SessionDeletion.ID,
        sessionID: CookingSession.ID,
        kitchenID: Kitchen.ID,
        restoredAt: Date,
        dispositionHeadsFormatVersion: Int,
        dispositionHeadsData: Data
    ) {
        self.id = id
        self.deletionID = deletionID
        self.sessionID = sessionID
        self.kitchenID = kitchenID
        self.restoredAt = restoredAt
        self.dispositionHeadsFormatVersion = dispositionHeadsFormatVersion
        self.dispositionHeadsData = dispositionHeadsData
    }
}

/// The immutable root binding a stable Session to its self-contained snapshot.
///
/// Recipe identities are provenance. Continuation source Session and Closure identities
/// must appear together with a valid copied baseline, but are not live dependencies.
public struct CookingSessionRootEvidence: Equatable, Sendable {
    /// The stable domain identity retained across copies and synchronization.
    ///
    /// Identity equality alone does not authorize contradictory immutable content.
    public let id: CookingSession.ID
    /// The Kitchen ownership boundary for this value; transport identity cannot substitute for it.
    public let kitchenID: Kitchen.ID
    /// The stable maintained Recipe identity, independent of a particular Revision.
    public let recipeID: Recipe.ID
    /// The exact maintained Revision captured at Start, retained only as provenance.
    public let recipeRevisionID: RecipeRevision.ID
    /// The authored Start date, excluded from activity-state decisions.
    public let startedAt: Date
    /// The codec version interpreting the self-contained snapshot.
    public let snapshotFormatVersion: Int
    /// The complete canonical cooking context, sufficient without the source Recipe.
    public let snapshotData: Data
    /// SHA-256 of the canonical snapshot bytes, checked before interpretation.
    public let snapshotDigest: Data
    /// Optional immediate source Session of a continuation, paired with a source Closure.
    public let sourceSessionID: CookingSession.ID?
    /// Optional immutable source Closure, paired with the source Session and copied baseline.
    public let sourceClosureID: SessionClosure.ID?

    /// Retains the supplied immutable envelope without validating completeness or integrity.
    ///
    /// Use the evidence projector before presenting ordinary domain content; keep the
    /// identity and bytes unchanged when transporting or retrying this evidence.
    public init(
        id: CookingSession.ID,
        kitchenID: Kitchen.ID,
        recipeID: Recipe.ID,
        recipeRevisionID: RecipeRevision.ID,
        startedAt: Date,
        snapshotFormatVersion: Int,
        snapshotData: Data,
        snapshotDigest: Data,
        sourceSessionID: CookingSession.ID? = nil,
        sourceClosureID: SessionClosure.ID? = nil
    ) {
        self.id = id
        self.kitchenID = kitchenID
        self.recipeID = recipeID
        self.recipeRevisionID = recipeRevisionID
        self.startedAt = startedAt
        self.snapshotFormatVersion = snapshotFormatVersion
        self.snapshotData = snapshotData
        self.snapshotDigest = snapshotDigest
        self.sourceSessionID = sourceSessionID
        self.sourceClosureID = sourceClosureID
    }
}

/// The retained unordered evidence set for one Session, including independent disposition.
///
/// Partial delivery is allowed here; only projection decides whether a complete
/// Session is available, waiting for material, or requires recovery.
public struct SessionEvidence: Equatable, Sendable {
    /// The stable aggregate identity every retained root and operation must reference.
    public let sessionID: CookingSession.ID
    /// Retained immutable root copies, which must agree exactly under the stable Session identity.
    public var roots: [CookingSessionRootEvidence]
    /// Retained unordered cooking intentions, including exact physical duplicates.
    public var facts: [SessionFactEvidence]
    /// Retained Finish commitments, including competing candidates requiring explicit choice.
    public var closures: [SessionClosureEvidence]
    /// Independent visibility evidence that does not remove cooking content.
    public var deletions: [SessionDeletionEvidence]
    /// Causal resolutions of observed deletions, without rewriting lifecycle.
    public var restorations: [SessionDeletionResolutionEvidence]

    /// Collects retained evidence without validating or discarding partial deliveries.
    public init(
        sessionID: CookingSession.ID,
        roots: [CookingSessionRootEvidence] = [],
        facts: [SessionFactEvidence] = [],
        closures: [SessionClosureEvidence] = [],
        deletions: [SessionDeletionEvidence] = [],
        restorations: [SessionDeletionResolutionEvidence] = []
    ) {
        self.sessionID = sessionID
        self.roots = roots
        self.facts = facts
        self.closures = closures
        self.deletions = deletions
        self.restorations = restorations
    }
}

/// A complete Session or a retained-evidence explanation for why it cannot be presented.
public enum SessionProjectionResult: Equatable, Sendable {
    /// One complete validated cooking projection, including any ordinary register conflicts.
    case session(CookingSessionProjection)
    /// Missing or unsupported evidence prevents a complete projection without proving corruption.
    case unavailable(UnavailableSession)
    /// A positive integrity failure or unresolved competing Closure prevents ordinary presentation.
    case recovery(SessionRecovery)
}

/// Retained Session evidence a reader cannot yet completely reconstruct.
///
/// Missing predecessors and unsupported formats are waiting states, without a claim
/// that the retained evidence is corrupt.
public struct UnavailableSession: Equatable, Sendable {
    /// A missing dependency or unsupported interpretation blocking complete reconstruction.
    public enum Reason: Equatable, Sendable {
        /// No immutable snapshot root is retained yet.
        case missingRoot
        /// A causal predecessor UUID is referenced but not retained.
        case missingPredecessor(UUID)
        /// A cooking or disposition predecessor needed to interpret deletion is absent.
        case incompleteDeletionDisposition(UUID)
        /// A retained predecessor frontier uses an unknown codec version.
        case unsupportedCausalHeadsFormat(Int)
        /// A Fact kind needed within the projected cooking cone is unknown to this reader.
        case unsupportedFactKind(String)
        /// A retained Fact payload uses an unknown codec version.
        case unsupportedPayloadFormat(Int)
        /// A Closure commits a closed-content format unknown to this reader.
        case unsupportedProjectionFormat(Int)
        /// A Closure retains an Outcome format unknown to this reader.
        case unsupportedOutcomeFormat(Int)
        /// The root’s self-contained cooking context uses an unknown format.
        case unsupportedSnapshotFormat(Int)
    }

    /// The complete supplied evidence retained for later arrival, retry, or explicit recovery.
    public let evidence: SessionEvidence
    /// The retained classification reasons; the current projector returns its first failing gate.
    public let reasons: [Reason]

    /// Pairs retained evidence with reasons without inventing a partial Session or removing records.
    public init(evidence: SessionEvidence, reasons: [Reason]) {
        self.evidence = evidence
        self.reasons = reasons
    }
}

/// Retained Session evidence that positively violates a reconstruction invariant.
///
/// The evidence remains available for recovery; no partial Session is synthesized.
public struct SessionRecovery: Equatable, Sendable {
    /// An integrity contradiction in retained evidence or an unresolved competing Closure choice.
    public enum Reason: Equatable, Sendable {
        /// Retained operations disagree on Session or Kitchen ownership.
        case crossSessionReference
        /// Retained snapshot or Fact bytes do not match their SHA-256 commitment.
        case digestMismatch
        /// One Closure identity is reused with conflicting retained evidence.
        case closureCollision
        /// Multiple complete Closures lack exactly one valid explicit selection.
        case competingClosures
        /// One Fact identity is reused with conflicting retained evidence.
        case factCollision
        /// One deletion identity is reused with conflicting retained evidence.
        case deletionCollision
        /// One restoration identity is reused with conflicting retained evidence.
        case restorationCollision
        /// Disposition heads, causal ancestry, or a deletion resolution violates visibility invariants.
        case invalidDeletionDisposition
        /// A Fact’s kind, target, payload, frontier, or Entry history violates cooking invariants.
        case invalidFact
        /// Source lineage and the inherited baseline are not paired or mapped consistently.
        case invalidContinuation
        /// A Closure’s frontier, snapshot, closed projection, or Outcome commitment contradicts reconstruction.
        case inconsistentClosure
        /// Predecessor bytes violate the declared canonical frontier format.
        case malformedCausalHeads
        /// Fact bytes cannot decode as the supported canonical payload representation.
        case malformedPayload
        /// Root bytes or decoded target material violate the supported snapshot invariants.
        case malformedSnapshot
        /// A persistence envelope contains an incomplete placeholder that cannot safely become domain evidence.
        case placeholderBearingRecord
        /// The stable Session root identity is reused with conflicting context.
        case rootCollision
        /// Cooking predecessor or Closure edges form a causal cycle.
        case cycle
    }

    /// The complete supplied evidence retained for later arrival, retry, or explicit recovery.
    public let evidence: SessionEvidence
    /// The retained classification reasons; the current projector returns its first failing gate.
    public let reasons: [Reason]

    /// Pairs retained evidence with reasons without inventing a partial Session or removing records.
    public init(evidence: SessionEvidence, reasons: [Reason]) {
        self.evidence = evidence
        self.reasons = reasons
    }
}

// swiftlint:enable file_length
