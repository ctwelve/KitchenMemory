// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

public enum SessionFact {
    public typealias ID = StableIdentifier<SessionFact>

    public enum Kind: String, CaseIterable, Sendable {
        case stop
        case resume
        case progress
        case workingScale
        case sessionEntry
        case sessionOutcome
        case conflictResolution
    }
}

public enum SessionFactPayload: Codable, Equatable, Sendable {
    case empty
    case progress(SessionProgressState)
    case workingScale(SessionWorkingScale)
    case sessionEntry(SessionEntryOperation)
    case sessionOutcome(SessionOutcomeChange)
    case closureResolution(ClosureSelection)
}

public struct ClosureSelection: Codable, Equatable, Sendable {
    public let selectedClosureID: SessionClosure.ID
    public let observedClosureIDs: [SessionClosure.ID]

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

public struct SessionFactEvidence: Equatable, Sendable {
    public let id: SessionFact.ID
    public let sessionID: CookingSession.ID
    public let kitchenID: Kitchen.ID
    public let kind: String
    public let targetSnapshotElementID: UUID?
    public let authoredAt: Date
    public let causalHeadsFormatVersion: Int
    public let causalHeadsData: Data
    public let payloadFormatVersion: Int
    public let payloadData: Data
    public let payloadDigest: Data

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

public struct SessionClosureEvidence: Equatable, Sendable {
    public let id: SessionClosure.ID
    public let sessionID: CookingSession.ID
    public let kitchenID: Kitchen.ID
    public let finishedAt: Date
    public let causalHeadsFormatVersion: Int
    public let causalHeadsData: Data
    public let snapshotFormatVersion: Int
    public let snapshotDigest: Data
    public let projectionFormatVersion: Int
    public let projectionDigest: Data
    public let outcomeFormatVersion: Int?
    public let outcomeData: Data?

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

public struct SessionDeletionEvidence: Equatable, Sendable {
    public let id: SessionDeletion.ID
    public let sessionID: CookingSession.ID
    public let kitchenID: Kitchen.ID
    public let deletedAt: Date
    public let sessionHeadsFormatVersion: Int
    public let sessionHeadsData: Data
    public let dispositionHeadsFormatVersion: Int
    public let dispositionHeadsData: Data

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

public struct SessionDeletionResolutionEvidence: Equatable, Sendable {
    public let id: SessionDeletionResolution.ID
    public let deletionID: SessionDeletion.ID
    public let sessionID: CookingSession.ID
    public let kitchenID: Kitchen.ID
    public let restoredAt: Date
    public let dispositionHeadsFormatVersion: Int
    public let dispositionHeadsData: Data

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

public struct CookingSessionRootEvidence: Equatable, Sendable {
    public let id: CookingSession.ID
    public let kitchenID: Kitchen.ID
    public let recipeID: Recipe.ID
    public let recipeRevisionID: RecipeRevision.ID
    public let startedAt: Date
    public let snapshotFormatVersion: Int
    public let snapshotData: Data
    public let snapshotDigest: Data
    public let sourceSessionID: CookingSession.ID?
    public let sourceClosureID: SessionClosure.ID?

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

public struct SessionEvidence: Equatable, Sendable {
    public let sessionID: CookingSession.ID
    public var roots: [CookingSessionRootEvidence]
    public var facts: [SessionFactEvidence]
    public var closures: [SessionClosureEvidence]
    public var deletions: [SessionDeletionEvidence]
    public var restorations: [SessionDeletionResolutionEvidence]

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

public enum SessionProjectionResult: Equatable, Sendable {
    case session(CookingSessionProjection)
    case unavailable(UnavailableSession)
    case recovery(SessionRecovery)
}

public struct UnavailableSession: Equatable, Sendable {
    public enum Reason: Equatable, Sendable {
        case missingRoot
        case missingPredecessor(UUID)
        case incompleteDeletionDisposition(UUID)
        case unsupportedCausalHeadsFormat(Int)
        case unsupportedFactKind(String)
        case unsupportedPayloadFormat(Int)
        case unsupportedProjectionFormat(Int)
        case unsupportedOutcomeFormat(Int)
        case unsupportedSnapshotFormat(Int)
    }

    public let evidence: SessionEvidence
    public let reasons: [Reason]

    public init(evidence: SessionEvidence, reasons: [Reason]) {
        self.evidence = evidence
        self.reasons = reasons
    }
}

public struct SessionRecovery: Equatable, Sendable {
    public enum Reason: Equatable, Sendable {
        case crossSessionReference
        case digestMismatch
        case closureCollision
        case competingClosures
        case factCollision
        case deletionCollision
        case restorationCollision
        case invalidDeletionDisposition
        case invalidFact
        case invalidContinuation
        case inconsistentClosure
        case malformedCausalHeads
        case malformedPayload
        case malformedSnapshot
        case placeholderBearingRecord
        case rootCollision
        case cycle
    }

    public let evidence: SessionEvidence
    public let reasons: [Reason]

    public init(evidence: SessionEvidence, reasons: [Reason]) {
        self.evidence = evidence
        self.reasons = reasons
    }
}
