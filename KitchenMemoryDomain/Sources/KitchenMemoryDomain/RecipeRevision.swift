// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

/// One intentional representation of a recipe at a point in its history.
public struct RecipeRevision: Codable, Equatable, Identifiable, Sendable {
    public typealias ID = StableIdentifier<RecipeRevision>

    public let id: ID
    public let recipeID: Recipe.ID
    public let revisionNumber: Int
    public var title: String

    public init(
        id: ID = ID(),
        recipeID: Recipe.ID,
        revisionNumber: Int,
        title: String
    ) {
        self.id = id
        self.recipeID = recipeID
        self.revisionNumber = revisionNumber
        self.title = title
    }
}
