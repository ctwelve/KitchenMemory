// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

/// The ownership and collaboration boundary for Kitchen Memory content.
public struct Kitchen: Codable, Equatable, Identifiable, Sendable {
    public typealias ID = StableIdentifier<Kitchen>

    public let id: ID
    public var name: String

    public init(id: ID = ID(), name: String) {
        self.id = id
        self.name = name
    }
}
