// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// A lightweight snapshot image reference, with provenance and no embedded image bytes.
public struct SessionMediaReference: Codable, Equatable, Identifiable, Sendable {
    /// A domain-typed stable UUID identity, independent of persistence record identity.
    public typealias ID = StableIdentifier<SessionMediaReference>

    /// The snapshot-owned reference identity, independent of Recipe media provenance.
    public let id: ID
    /// Optional Recipe image provenance; the snapshot never embeds its bytes.
    public let sourceMediaID: RecipeMedia.ID?
    /// The captured authored image presentation role.
    public var role: RecipeMedia.Role
    /// The retained description available without resolving source image bytes.
    public var accessibilityDescription: String?

    /// Creates a lightweight snapshot reference without loading or copying image data.
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

/// One copied baseline Entry with optional lineage to the immutable source Entry.
public struct SessionContinuationEntry: Codable, Equatable, Sendable {
    /// The new Session’s copied Entry value and remapped optional target.
    public let entry: SessionEntry
    /// Optional lineage to the immutable source Entry, without a live reconstruction dependency.
    public let sourceEntryID: SessionEntry.ID?

    /// Retains copied Entry content and lineage without fetching the source Session.
    public init(entry: SessionEntry, sourceEntryID: SessionEntry.ID?) {
        self.entry = entry
        self.sourceEntryID = sourceEntryID
    }
}

/// An explicit same-kind mapping from a source snapshot target to a new Session target.
public struct SessionContinuationTargetMapping: Codable, Equatable, Sendable {
    /// The newly minted target belonging to the continuation snapshot.
    public let target: SessionProgressTarget
    /// The same-kind target in the immutable source snapshot.
    public let sourceTarget: SessionProgressTarget

    /// Retains an explicit lineage mapping; projection verifies kind agreement and unique mappings.
    public init(target: SessionProgressTarget, sourceTarget: SessionProgressTarget) {
        self.target = target
        self.sourceTarget = sourceTarget
    }
}

/// Self-contained inherited cooking values for a new Active Session.
///
/// Progress, Entries, and mappings are sorted by new target or Entry identity. Source
/// objects explain lineage without becoming reconstruction dependencies.
public struct SessionContinuationBaseline: Codable, Equatable, Sendable {
    /// The inherited complete working scale remapped to new ingredient identities.
    public var workingScale: SessionWorkingScale?
    /// Inherited states sorted by new target identity, without carrying source Fact IDs.
    public var progress: [SessionProgress]
    /// Copied confirmed Entries sorted by their new identities with optional source lineage.
    public var entries: [SessionContinuationEntry]
    /// Explicit new-to-source target mappings sorted by new target identity.
    public var targetMappings: [SessionContinuationTargetMapping]

    /// Canonicalizes inherited collection order without changing copied content.
    ///
    /// Projection verifies target uniqueness and complete mappings for inherited values;
    /// source objects need not remain available to reconstruct this baseline.
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
