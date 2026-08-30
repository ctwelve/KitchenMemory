// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// The identity namespace for one device-independent cooking performance.
public enum CookingSession {
    public typealias ID = StableIdentifier<CookingSession>
}

/// The immutable cooking context captured when a Cooking Session starts.
public struct ExecutionSnapshot: Codable, Equatable, Sendable {
    public var title: String
    public var summary: String?
    public var contentLanguage: RecipeContentLanguage?
    public var authorName: String?
    public var source: RecipeSource?
    public var baseYield: RecipeYield?
    public var initialWorkingScale: SessionWorkingScale?
    public var prepDuration: RecipeDuration?
    public var cookDuration: RecipeDuration?
    public var totalDuration: RecipeDuration?
    public var equipment: [EquipmentItem]
    public var ingredientSections: [SessionIngredientSection]
    public var instructionSections: [SessionInstructionSection]
    public var media: [SessionMediaReference]
    public var continuationBaseline: SessionContinuationBaseline?

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

public struct SessionIngredient: Codable, Equatable, Identifiable, Sendable {
    public typealias ID = StableIdentifier<SessionIngredient>

    public let id: ID
    public let sourceIngredientID: RecipeIngredient.ID?
    public var value: RecipeIngredient

    public init(id: ID = ID(), sourceIngredientID: RecipeIngredient.ID?, value: RecipeIngredient) {
        self.id = id
        self.sourceIngredientID = sourceIngredientID
        self.value = value
    }
}

public struct SessionIngredientSection: Codable, Equatable, Sendable {
    public var title: String?
    public var ingredients: [SessionIngredient]

    public init(title: String?, ingredients: [SessionIngredient]) {
        self.title = title
        self.ingredients = ingredients
    }
}

public struct SessionInstruction: Codable, Equatable, Identifiable, Sendable {
    public typealias ID = StableIdentifier<SessionInstruction>

    public let id: ID
    public let sourceInstructionID: InstructionStep.ID?
    public var value: InstructionStep

    public init(id: ID = ID(), sourceInstructionID: InstructionStep.ID?, value: InstructionStep) {
        self.id = id
        self.sourceInstructionID = sourceInstructionID
        self.value = value
    }
}

public struct SessionInstructionSection: Codable, Equatable, Sendable {
    public var title: String?
    public var steps: [SessionInstruction]

    public init(title: String?, steps: [SessionInstruction]) {
        self.title = title
        self.steps = steps
    }
}

public enum SessionProgressTarget: Codable, Equatable, Hashable, Sendable {
    case ingredient(SessionIngredient.ID)
    case instruction(SessionInstruction.ID)

    var rawIdentifier: UUID {
        switch self {
        case let .ingredient(identifier): identifier.rawValue
        case let .instruction(identifier): identifier.rawValue
        }
    }
}

public enum SessionIngredientProgress: String, Codable, Equatable, Hashable, Sendable {
    case accounted
    case open
}

public enum SessionInstructionProgress: String, Codable, Equatable, Hashable, Sendable {
    case completed
    case skipped
    case open
}

public enum SessionProgressState: Codable, Equatable, Hashable, Sendable {
    case ingredient(SessionIngredientProgress)
    case instruction(SessionInstructionProgress)
}

public struct SessionProgress: Codable, Equatable, Hashable, Sendable {
    public let target: SessionProgressTarget
    public let state: SessionProgressState

    public init(target: SessionProgressTarget, state: SessionProgressState) {
        self.target = target
        self.state = state
    }
}

public struct SessionIngredientQuantity: Codable, Equatable, Sendable {
    public let ingredientID: SessionIngredient.ID
    public let quantity: QuantityExpression

    public init(ingredientID: SessionIngredient.ID, quantity: QuantityExpression) {
        self.ingredientID = ingredientID
        self.quantity = quantity
    }
}

public struct SessionWorkingScale: Codable, Equatable, Sendable {
    public let workingYield: RecipeYield?
    public let exactScale: RationalQuantity?
    public let quantities: [SessionIngredientQuantity]

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

public struct SessionEntry: Codable, Equatable, Identifiable, Sendable {
    public typealias ID = StableIdentifier<SessionEntry>

    public let id: ID
    public let target: SessionProgressTarget?
    public let text: String

    public init(id: ID, target: SessionProgressTarget?, text: String) {
        self.id = id
        self.target = target
        self.text = text
    }
}

public enum SessionEntryOperation: Codable, Equatable, Sendable {
    case submit(entryID: SessionEntry.ID, text: String)
    case revise(entryID: SessionEntry.ID, text: String)
    case withdraw(entryID: SessionEntry.ID)

    var entryID: SessionEntry.ID {
        switch self {
        case let .submit(entryID, _), let .revise(entryID, _), let .withdraw(entryID): entryID
        }
    }
}

public enum SessionOutcome: Codable, Equatable, Sendable {
    public enum CoarseValue: String, Codable, Equatable, Sendable {
        case great
        case okay
        case unsuccessful
    }

    case coarse(CoarseValue)
}

public enum SessionOutcomeChange: Codable, Equatable, Sendable {
    case set(SessionOutcome)
    case clear
}

public enum SessionEntryConflictValue: Equatable, Sendable {
    case present(SessionEntry)
    case withdrawn
}

public enum SessionOutcomeConflictValue: Equatable, Sendable {
    case value(SessionOutcome)
    case cleared
}

public enum SessionLifecycle: String, Codable, Equatable, Sendable {
    case active
    case stopped
    case finished
}

public enum SessionClosure {
    public typealias ID = StableIdentifier<SessionClosure>
}

public enum SessionDisposition: Equatable, Sendable {
    case ordinary
    case deleted(needsAttention: Bool)
}

public enum SessionDeletion {
    public typealias ID = StableIdentifier<SessionDeletion>
}

public enum SessionDeletionResolution {
    public typealias ID = StableIdentifier<SessionDeletionResolution>
}

public enum SessionConflict: Equatable, Sendable {
    case progress(
        target: SessionProgressTarget,
        factIDs: [SessionFact.ID],
        states: [SessionProgressState]
    )
    case workingScale(factIDs: [SessionFact.ID], values: [SessionWorkingScale])
    case entry(
        entryID: SessionEntry.ID,
        factIDs: [SessionFact.ID],
        values: [SessionEntryConflictValue]
    )
    case outcome(factIDs: [SessionFact.ID], values: [SessionOutcomeConflictValue])
}

public struct CookingSessionProjection: Equatable, Sendable {
    public let id: CookingSession.ID
    public let snapshot: ExecutionSnapshot
    public let sourceSessionID: CookingSession.ID?
    public let sourceClosureID: SessionClosure.ID?
    public let lifecycle: SessionLifecycle
    public let lifecycleBeforeFinish: SessionLifecycle
    public let disposition: SessionDisposition
    public let progress: [SessionProgress]
    public let workingScale: SessionWorkingScale?
    public let entries: [SessionEntry]
    public let outcome: SessionOutcome?
    public let conflicts: [SessionConflict]
    public let selectedClosureID: SessionClosure.ID?
    public let lateEvidence: [SessionFact.ID]

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

public struct ClosedSessionProjection: Codable, Equatable, Sendable {
    public let snapshot: ExecutionSnapshot
    public let lifecycleBeforeFinish: SessionLifecycle
    public let progress: [SessionProgress]
    public let workingScale: SessionWorkingScale?
    public let entries: [SessionEntry]
    public let outcome: SessionOutcome?

    public init(_ projection: CookingSessionProjection) {
        snapshot = projection.snapshot
        lifecycleBeforeFinish = projection.lifecycleBeforeFinish
        progress = projection.progress
        workingScale = projection.workingScale
        entries = projection.entries
        outcome = projection.outcome
    }
}
