// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

/// The durable identity of a maintained dish.
public struct Recipe: Codable, Equatable, Identifiable, Sendable {
    /// A domain-typed stable UUID identity, independent of persistence record identity.
    public typealias ID = StableIdentifier<Recipe>

    /// The stable maintained dish identity across immutable Revisions and disposition changes.
    public let id: ID
    /// The Kitchen ownership boundary for this value; transport identity cannot substitute for it.
    public let kitchenID: Kitchen.ID
    /// The compatibility current pointer carried by this value.
    ///
    /// Immutable Recipe Selection evidence owns currentness; changing this property
    /// does not accept a Revision or publish a Selection.
    public var currentRevisionID: RecipeRevision.ID

    /// Creates a Recipe identity value; authority is established separately by an accepted first Save.
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
