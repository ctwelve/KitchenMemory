// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

// These related public values and their caller contracts form one domain boundary.
// Keep their documentation beside the declarations rather than splitting the contract.
// swiftlint:disable file_length

/// The identity namespace for one device-independent cooking performance.
public enum CookingSession {
    /// A domain-typed stable UUID identity, independent of persistence record identity.
    public typealias ID = StableIdentifier<CookingSession>
}

/// The self-contained cooking context captured when a Cooking Session starts.
///
/// Local construction can edit this value before encoding; an accepted root
/// commits immutable canonical bytes. Later Recipe edits and source availability
/// cannot change the meaning of the captured ingredient or instruction targets.
public struct ExecutionSnapshot: Codable, Equatable, Sendable {
    /// The authored Recipe title retained independently of the interface locale.
    public var title: String
    /// Optional authored descriptive text, without inferred cooking results.
    public var summary: String?
    /// The authored content language, or nil when unknown; it is not the interface locale.
    public var contentLanguage: RecipeContentLanguage?
    /// Human-readable content attribution, independent of Kitchen ownership.
    public var authorName: String?
    /// Optional human-readable Recipe provenance, independent of retained import evidence.
    public var source: RecipeSource?
    /// The maintained Recipe’s authored yield captured at Start.
    public var baseYield: RecipeYield?
    /// The initial cook-specific scale, independent of later scale Facts.
    public var initialWorkingScale: SessionWorkingScale?
    /// Optional active preparation duration as authored, without inferring missing timing.
    public var prepDuration: RecipeDuration?
    /// Optional authored cooking duration, independent of running Session timers.
    public var cookDuration: RecipeDuration?
    /// The authored total duration, retained independently of prep-plus-cook arithmetic.
    public var totalDuration: RecipeDuration?
    /// Authored tool requirements in retained order.
    public var equipment: [EquipmentItem]
    /// Ingredient groups and rows in authored order, preserving optional structure and wording.
    public var ingredientSections: [SessionIngredientSection]
    /// Instruction groups and steps in authored order, independent of cooking progress.
    public var instructionSections: [SessionInstructionSection]
    /// Lightweight captured image references in authored order, with no embedded image bytes.
    public var media: [SessionMediaReference]
    /// The copied inherited values and explicit target lineage when this starts a continuation.
    public var continuationBaseline: SessionContinuationBaseline?

    /// Assembles self-contained cooking context before canonical encoding and durable Start.
    ///
    /// Construction permits incomplete values; projection validates required material
    /// and Session-owned target identity uniqueness.
    public init(
        title: String,
        summary: String? = nil,
        contentLanguage: RecipeContentLanguage? = nil,
        authorName: String? = nil,
        source: RecipeSource? = nil,
        baseYield: RecipeYield? = nil,
        initialWorkingScale: SessionWorkingScale? = nil,
        prepDuration: RecipeDuration? = nil,
        cookDuration: RecipeDuration? = nil,
        totalDuration: RecipeDuration? = nil,
        equipment: [EquipmentItem] = [],
        ingredientSections: [SessionIngredientSection] = [],
        instructionSections: [SessionInstructionSection] = [],
        media: [SessionMediaReference] = [],
        continuationBaseline: SessionContinuationBaseline? = nil
    ) {
        self.title = title
        self.summary = summary
        self.contentLanguage = contentLanguage
        self.authorName = authorName
        self.source = source
        self.baseYield = baseYield
        self.initialWorkingScale = initialWorkingScale
        self.prepDuration = prepDuration
        self.cookDuration = cookDuration
        self.totalDuration = totalDuration
        self.equipment = equipment
        self.ingredientSections = ingredientSections
        self.instructionSections = instructionSections
        self.media = media
        self.continuationBaseline = continuationBaseline
    }
}

/// A Session-owned ingredient target wrapping copied Recipe content.
///
/// The source identity records provenance; progress and Entries target `id` and do
/// not depend on the source Recipe remaining available.
public struct SessionIngredient: Codable, Equatable, Identifiable, Sendable {
    /// A domain-typed stable UUID identity, independent of persistence record identity.
    public typealias ID = StableIdentifier<SessionIngredient>

    /// The snapshot-owned target identity; Recipe row provenance is stored separately.
    public let id: ID
    /// Optional Recipe row provenance; it is not the identity used for Session activity.
    public let sourceIngredientID: RecipeIngredient.ID?
    /// Copied authored content that remains usable without the source Recipe.
    public var value: RecipeIngredient

    /// Creates a Session-owned target retaining copied content and optional Recipe provenance.
    public init(id: ID = ID(), sourceIngredientID: RecipeIngredient.ID?, value: RecipeIngredient) {
        self.id = id
        self.sourceIngredientID = sourceIngredientID
        self.value = value
    }
}

/// An ordered snapshot ingredient group with an optional authored heading.
public struct SessionIngredientSection: Codable, Equatable, Sendable {
    /// The captured group heading, or nil for an untitled group.
    public var title: String?
    /// Session-owned targets in captured authored order.
    public var ingredients: [SessionIngredient]

    /// Preserves the supplied group heading and Session-owned ingredient order.
    public init(title: String?, ingredients: [SessionIngredient]) {
        self.title = title
        self.ingredients = ingredients
    }
}

/// A Session-owned instruction target wrapping copied Recipe content.
///
/// The source identity records provenance; later Recipe edits cannot change this target.
public struct SessionInstruction: Codable, Equatable, Identifiable, Sendable {
    /// A domain-typed stable UUID identity, independent of persistence record identity.
    public typealias ID = StableIdentifier<SessionInstruction>

    /// The snapshot-owned target identity; Recipe row provenance is stored separately.
    public let id: ID
    /// Optional Recipe step provenance, independent of Session progress identity.
    public let sourceInstructionID: InstructionStep.ID?
    /// Copied authored instruction content, independent of later Recipe edits.
    public var value: InstructionStep

    /// Creates a Session-owned instruction target with copied content and optional provenance.
    public init(id: ID = ID(), sourceInstructionID: InstructionStep.ID?, value: InstructionStep) {
        self.id = id
        self.sourceInstructionID = sourceInstructionID
        self.value = value
    }
}

/// An ordered snapshot instruction group with an optional authored heading.
public struct SessionInstructionSection: Codable, Equatable, Sendable {
    /// The captured group heading, or nil for an untitled group.
    public var title: String?
    /// Session-owned instruction targets in captured authored order.
    public var steps: [SessionInstruction]

    /// Preserves the supplied group heading and Session-owned step order.
    public init(title: String?, steps: [SessionInstruction]) {
        self.title = title
        self.steps = steps
    }
}

/// A typed Session-owned snapshot element; Recipe row identities cannot substitute for it.
public enum SessionProgressTarget: Codable, Equatable, Hashable, Sendable {
    /// Anchors activity to one ingredient identity in this Session’s snapshot.
    case ingredient(SessionIngredient.ID)
    /// Anchors activity to one instruction identity in this Session’s snapshot.
    case instruction(SessionInstruction.ID)

    var rawIdentifier: UUID {
        switch self {
        case let .ingredient(identifier): identifier.rawValue
        case let .instruction(identifier): identifier.rawValue
        }
    }
}

/// Coarse cooking progress, with no claim of measured pantry consumption.
public enum SessionIngredientProgress: String, Codable, Equatable, Hashable, Sendable {
    /// The ingredient was accounted for during this cook, without recording measured consumption.
    case accounted
    /// The ingredient remains available for accounting or was explicitly reopened.
    case open
}

/// Resulting state for an instruction, rather than a toggle or activity delta.
public enum SessionInstructionProgress: String, Codable, Equatable, Hashable, Sendable {
    /// The cook marked the instruction complete.
    case completed
    /// The cook deliberately skipped the instruction; its content remains available.
    case skipped
    /// The instruction is open or was deliberately reopened.
    case open
}

/// A progress value whose kind must agree with its snapshot target.
public enum SessionProgressState: Codable, Equatable, Hashable, Sendable {
    /// A coarse ingredient state, valid only for an ingredient target.
    case ingredient(SessionIngredientProgress)
    /// An instruction state, valid only for an instruction target.
    case instruction(SessionInstructionProgress)
}

/// A resulting state for one typed snapshot element.
///
/// Construction preserves the pair; evidence projection rejects mismatched kinds.
public struct SessionProgress: Codable, Equatable, Hashable, Sendable {
    /// The typed Session-owned snapshot identity receiving the state.
    public let target: SessionProgressTarget
    /// The resulting state, which must have the same kind as the target.
    public let state: SessionProgressState

    /// Retains a progress pair without checking target existence or kind compatibility.
    public init(target: SessionProgressTarget, state: SessionProgressState) {
        self.target = target
        self.state = state
    }
}

/// A structured working amount for one Session-owned ingredient target.
public struct SessionIngredientQuantity: Codable, Equatable, Sendable {
    /// The Session-owned ingredient whose working amount is replaced.
    public let ingredientID: SessionIngredient.ID
    /// The complete structured working amount, retaining any textual qualification.
    public let quantity: QuantityExpression

    /// Retains a working amount without validating the snapshot target.
    public init(ingredientID: SessionIngredient.ID, quantity: QuantityExpression) {
        self.ingredientID = ingredientID
        self.quantity = quantity
    }
}

/// A complete replacement of a Session’s working yield and structured quantities.
///
/// Quantities are sorted by target UUID for canonical encoding. Construction does not
/// check uniqueness, target existence, or the validity of the optional exact ratio.
public struct SessionWorkingScale: Codable, Equatable, Sendable {
    /// Optional cook-specific output wording and structure.
    public let workingYield: RecipeYield?
    /// Optional exact multiplier relative to the immutable snapshot’s base amounts.
    public let exactScale: RationalQuantity?
    /// Complete structured working amounts sorted by Session ingredient UUID.
    ///
    /// Projection requires unique targets belonging to the snapshot.
    public let quantities: [SessionIngredientQuantity]

    /// Retains a complete scale replacement and canonicalizes quantity order.
    ///
    /// It does not compute amounts or validate target uniqueness and ratio positivity.
    public init(
        workingYield: RecipeYield? = nil,
        exactScale: RationalQuantity? = nil,
        quantities: [SessionIngredientQuantity] = []
    ) {
        self.workingYield = workingYield
        self.exactScale = exactScale
        self.quantities = quantities.sorted {
            $0.ingredientID.rawValue.uuidString < $1.ingredientID.rawValue.uuidString
        }
    }
}

/// Exact confirmed cooking text, optionally anchored to a snapshot element.
///
/// This value carries no inferred Recipe change or ingredient meaning.
public struct SessionEntry: Codable, Equatable, Identifiable, Sendable {
    /// A domain-typed stable UUID identity, independent of persistence record identity.
    public typealias ID = StableIdentifier<SessionEntry>

    /// The Entry identity retained through causal revisions and withdrawal.
    public let id: ID
    /// The optional Session-owned ingredient or instruction anchor; nil means the whole Session.
    public let target: SessionProgressTarget?
    /// Exact authored Unicode text, preserved without automatic ingredient interpretation.
    public let text: String

    /// Retains the supplied Entry identity, anchor, and exact text without rewriting wording.
    public init(id: ID, target: SessionProgressTarget?, text: String) {
        self.id = id
        self.target = target
        self.text = text
    }
}

/// An immutable intention changing one Entry while retaining earlier evidence.
public enum SessionEntryOperation: Codable, Equatable, Sendable {
    /// Confirms a new Entry; projection requires its UUID to match the submitting Fact UUID.
    case submit(entryID: SessionEntry.ID, text: String)
    /// Replaces an existing causally observed Entry’s text; the Fact target can retarget it.
    case revise(entryID: SessionEntry.ID, text: String)
    /// Removes an observed Entry from presentation while retaining its earlier evidence.
    case withdraw(entryID: SessionEntry.ID)

    var entryID: SessionEntry.ID {
        switch self {
        case let .submit(entryID, _), let .revise(entryID, _), let .withdraw(entryID): entryID
        }
    }
}

/// An optional coarse assessment of the cook, independent of lifecycle and Recipe ratings.
public enum SessionOutcome: Codable, Equatable, Sendable {
    /// The cook’s deliberately coarse assessment, without inferred numeric precision.
    public enum CoarseValue: String, Codable, Equatable, Sendable {
        /// The cook’s positive coarse assessment.
        case great
        /// The cook’s neutral coarse assessment.
        case okay
        /// The cook’s unsuccessful coarse assessment.
        case unsuccessful
    }

    /// A deliberately coarse authored assessment without implying Recipe fidelity or completion.
    case coarse(CoarseValue)
}

/// A resulting assessment or explicit clearing intention, rather than a lifecycle change.
public enum SessionOutcomeChange: Codable, Equatable, Sendable {
    /// Replaces the optional cook assessment with this authored value.
    case set(SessionOutcome)
    /// Explicitly removes the current assessment while preserving prior evidence.
    case clear
}

/// One surviving concurrent Entry value, including explicit withdrawal.
public enum SessionEntryConflictValue: Equatable, Sendable {
    /// A surviving authored Entry value, including its target and exact text.
    case present(SessionEntry)
    /// A concurrent explicit withdrawal competing with surviving Entry content.
    case withdrawn
}

/// One surviving concurrent Outcome value, including explicit clearing.
public enum SessionOutcomeConflictValue: Equatable, Sendable {
    /// A surviving authored assessment value.
    case value(SessionOutcome)
    /// A concurrent explicit clearing intention competing with an assessment.
    case cleared
}

/// Durable activity state changed by explicit intentions rather than navigation or elapsed time.
public enum SessionLifecycle: String, Codable, Equatable, Sendable {
    /// Accepts cooking evidence until an explicit Stop or valid Closure.
    case active
    /// Deliberately dormant and resumable; new cooking evidence requires Resume.
    case stopped
    /// Immutable performance sealed by a valid Closure; further cooking requires a new continuation.
    case finished
}

/// The identity namespace for immutable evidence sealing one observed Session frontier.
public enum SessionClosure {
    /// A domain-typed stable UUID identity, independent of persistence record identity.
    public typealias ID = StableIdentifier<SessionClosure>
}

/// Library visibility independently derived from deletion and restoration evidence.
public enum SessionDisposition: Equatable, Sendable {
    /// No unresolved deletion hides the Session from ordinary presentation.
    case ordinary
    /// At least one deletion remains unresolved.
    ///
    /// `needsAttention` marks a concurrent restoration that did not observe every
    /// remaining deletion; cooking lifecycle is preserved independently.
    case deleted(needsAttention: Bool)
}

/// The identity namespace for reversible Session deletion evidence.
public enum SessionDeletion {
    /// A domain-typed stable UUID identity, independent of persistence record identity.
    public typealias ID = StableIdentifier<SessionDeletion>
}

/// The identity namespace for one causal resolution of an observed Session deletion.
public enum SessionDeletionResolution {
    /// A domain-typed stable UUID identity, independent of persistence record identity.
    public typealias ID = StableIdentifier<SessionDeletionResolution>
}

/// Concurrent, causally maximal values requiring an explicit cooking choice.
///
/// The Fact identities and values describe the same retained competitors; projection
/// does not elect a winner using timestamps or device identity.
public enum SessionConflict: Equatable, Sendable {
    /// Competing resulting states for one snapshot target; ordinary projection keeps the target open.
    case progress(
        target: SessionProgressTarget,
        factIDs: [SessionFact.ID],
        states: [SessionProgressState]
    )
    /// Competing complete scale replacements; no scale winner is silently presented.
    case workingScale(factIDs: [SessionFact.ID], values: [SessionWorkingScale])
    /// Competing Entry content, targets, or withdrawal for one stable Entry identity.
    case entry(
        entryID: SessionEntry.ID,
        factIDs: [SessionFact.ID],
        values: [SessionEntryConflictValue]
    )
    /// Competing assessments or clearing intentions, separate from Session lifecycle.
    case outcome(factIDs: [SessionFact.ID], values: [SessionOutcomeConflictValue])
}

/// A complete reading of a Session’s snapshot, activity, conflicts, and disposition.
///
/// Finished content is reconstructed only from its selected Closure’s causal cone.
/// Late evidence remains identified separately and cannot rewrite that content.
public struct CookingSessionProjection: Equatable, Sendable {
    /// The stable cooking performance identity reconstructed from retained root evidence.
    public let id: CookingSession.ID
    /// The complete immutable cooking context reconstructed from validated root bytes.
    public let snapshot: ExecutionSnapshot
    /// The immediate immutable source of a continuation, as provenance rather than a runtime dependency.
    public let sourceSessionID: CookingSession.ID?
    /// The source Closure paired with continuation lineage, independent of source availability.
    public let sourceClosureID: SessionClosure.ID?
    /// The reconstructed activity state; only a valid selected Closure yields Finished.
    public let lifecycle: SessionLifecycle
    /// The activity state inside the sealed frontier, or the current live lifecycle.
    public let lifecycleBeforeFinish: SessionLifecycle
    /// Visibility reconstructed independently from cooking activity and completion.
    public let disposition: SessionDisposition
    /// Projected target states in canonical identity order; unspecified targets remain implicitly open.
    public let progress: [SessionProgress]
    /// The agreed working scale, initial or inherited baseline, or nil when absent or competing.
    public let workingScale: SessionWorkingScale?
    /// Agreed present Entries in canonical identity order; withdrawn or competing values stay in evidence.
    public let entries: [SessionEntry]
    /// The agreed optional cook assessment; absence does not imply failure or success.
    public let outcome: SessionOutcome?
    /// Distinct concurrent register values retained for explicit human choice.
    public let conflicts: [SessionConflict]
    /// The validated Closure sealing Finished content, when one has been selected.
    public let selectedClosureID: SessionClosure.ID?
    /// Retained Fact identities outside the selected Closure’s cone, unable to rewrite Finished content.
    public let lateEvidence: [SessionFact.ID]

    /// Assembles a projection value without performing evidence validation.
    ///
    /// The lifecycle-before-Finish defaults to the supplied lifecycle. Ordinary callers
    /// should obtain validated projections through `SessionEvidenceProjector`.
    public init(
        id: CookingSession.ID,
        snapshot: ExecutionSnapshot,
        sourceSessionID: CookingSession.ID? = nil,
        sourceClosureID: SessionClosure.ID? = nil,
        lifecycle: SessionLifecycle = .active,
        lifecycleBeforeFinish: SessionLifecycle? = nil,
        disposition: SessionDisposition = .ordinary,
        progress: [SessionProgress] = [],
        workingScale: SessionWorkingScale? = nil,
        entries: [SessionEntry] = [],
        outcome: SessionOutcome? = nil,
        conflicts: [SessionConflict] = [],
        selectedClosureID: SessionClosure.ID? = nil,
        lateEvidence: [SessionFact.ID] = []
    ) {
        self.id = id
        self.snapshot = snapshot
        self.sourceSessionID = sourceSessionID
        self.sourceClosureID = sourceClosureID
        self.lifecycle = lifecycle
        self.lifecycleBeforeFinish = lifecycleBeforeFinish ?? lifecycle
        self.disposition = disposition
        self.progress = progress
        self.workingScale = workingScale
        self.entries = entries
        self.outcome = outcome
        self.conflicts = conflicts
        self.selectedClosureID = selectedClosureID
        self.lateEvidence = lateEvidence
    }
}

/// The content committed by a Session Closure’s canonical projection digest.
///
/// It excludes visibility, late evidence, and closure selection metadata so those
/// independent concerns cannot mutate the sealed performance.
public struct ClosedSessionProjection: Codable, Equatable, Sendable {
    /// The immutable context committed by this closed projection.
    public let snapshot: ExecutionSnapshot
    /// The activity state reconstructed within the Closure’s observed frontier.
    public let lifecycleBeforeFinish: SessionLifecycle
    /// The agreed target states committed by the Closure’s digest.
    public let progress: [SessionProgress]
    /// The agreed complete working-scale replacement committed by the Closure.
    public let workingScale: SessionWorkingScale?
    /// The agreed present Entry values committed by the Closure.
    public let entries: [SessionEntry]
    /// The optional assessment committed by the Closure.
    public let outcome: SessionOutcome?

    /// Copies only the content participating in a Closure commitment.
    ///
    /// This does not validate conflicts or require Finished; closure validation checks
    /// those invariants before accepting the resulting digest.
    public init(_ projection: CookingSessionProjection) {
        snapshot = projection.snapshot
        lifecycleBeforeFinish = projection.lifecycleBeforeFinish
        progress = projection.progress
        workingScale = projection.workingScale
        entries = projection.entries
        outcome = projection.outcome
    }
}

// swiftlint:enable file_length
