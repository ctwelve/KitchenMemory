// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// An application-owned UUID whose phantom entity type prevents cross-domain identity mixing.
///
/// Copies and scalar encoding preserve the UUID independently of database or
/// CloudKit record identity. Fresh construction creates a new identity rather
/// than recovering or finding an existing entity.
public struct StableIdentifier<Entity>: Codable, Hashable, RawRepresentable, Sendable {
    /// The application-owned UUID, independent of database or CloudKit identity.
    public let rawValue: UUID

    /// Preserves a supplied UUID when reconstructing an existing domain identity.
    ///
    /// The entity parameter prevents mixing otherwise identical UUIDs across domain types.
    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }

    /// Allocates a fresh random UUID for a new domain entity or operation.
    ///
    /// Retain this value across retries; constructing another ID creates another identity.
    public init() {
        self.init(rawValue: UUID())
    }

    /// Decodes one UUID scalar while preserving its domain entity type.
    ///
    /// Malformed scalar data throws the decoder’s error; no replacement identity is minted.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(UUID.self))
    }

    /// Encodes the UUID as one scalar value, without an entity name or storage identity.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
