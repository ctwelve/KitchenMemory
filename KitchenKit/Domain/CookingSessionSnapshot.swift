// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

public struct SessionMediaReference: Codable, Equatable, Identifiable, Sendable {
    public typealias ID = StableIdentifier<SessionMediaReference>

    public let id: ID
    public let sourceMediaID: RecipeMedia.ID?
    public var role: RecipeMedia.Role
    public var accessibilityDescription: String?

    public init(
        id: ID = ID(),
        sourceMediaID: RecipeMedia.ID?,
        role: RecipeMedia.Role,
        accessibilityDescription: String?
    ) {
        self.id = id
        self.sourceMediaID = sourceMediaID
        self.role = role
        self.accessibilityDescription = accessibilityDescription
    }
}

public struct SessionContinuationEntry: Codable, Equatable, Sendable {
    public let entry: SessionEntry
    public let sourceEntryID: SessionEntry.ID?

    public init(entry: SessionEntry, sourceEntryID: SessionEntry.ID?) {
        self.entry = entry
        self.sourceEntryID = sourceEntryID
    }
}

public struct SessionContinuationTargetMapping: Codable, Equatable, Sendable {
    public let target: SessionProgressTarget
    public let sourceTarget: SessionProgressTarget

    public init(target: SessionProgressTarget, sourceTarget: SessionProgressTarget) {
        self.target = target
        self.sourceTarget = sourceTarget
    }
}

public struct SessionContinuationBaseline: Codable, Equatable, Sendable {
    public var workingScale: SessionWorkingScale?
    public var progress: [SessionProgress]
    public var entries: [SessionContinuationEntry]
    public var targetMappings: [SessionContinuationTargetMapping]

    public init(
        workingScale: SessionWorkingScale? = nil,
        progress: [SessionProgress] = [],
        entries: [SessionContinuationEntry] = [],
        targetMappings: [SessionContinuationTargetMapping] = []
    ) {
        self.workingScale = workingScale
        self.progress = progress.sorted {
            $0.target.rawIdentifier.uuidString < $1.target.rawIdentifier.uuidString
        }
        self.entries = entries.sorted {
            $0.entry.id.rawValue.uuidString < $1.entry.id.rawValue.uuidString
        }
        self.targetMappings = targetMappings.sorted {
            $0.target.rawIdentifier.uuidString < $1.target.rawIdentifier.uuidString
        }
    }
}
