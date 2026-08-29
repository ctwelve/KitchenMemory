// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

/// The durable identity of a maintained dish.
public struct Recipe: Codable, Equatable, Identifiable, Sendable {
    public typealias ID = StableIdentifier<Recipe>

    public let id: ID
    public let kitchenID: Kitchen.ID
    public var currentRevisionID: RecipeRevision.ID

    public init(
        id: ID = ID(),
        kitchenID: Kitchen.ID,
        currentRevisionID: RecipeRevision.ID
    ) {
        self.id = id
        self.kitchenID = kitchenID
        self.currentRevisionID = currentRevisionID
    }
}
