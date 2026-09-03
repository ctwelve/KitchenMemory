// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import XCTest

@MainActor
final class RecipeRepositoryConvergenceContractTests: XCTestCase {
  func testRepositoryWithoutOwnershipConvergenceSupportFailsExplicitly() throws {
    let repository = SessionRecipeRepository(stored: [])
    let ownerID = KitchenOwner.ID(rawValue: "test-owner")

    XCTAssertThrowsError(
      try repository.convergeKitchens(
        into: Kitchen(ownerID: ownerID, name: "Home"),
        ownedBy: ownerID
      )
    ) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .ownershipConvergenceUnsupported
      )
    }
  }

  func testDefaultAuthorityAndCommandAdaptersRemainExplicit() throws {
    let recipeID = Recipe.ID()
    let kitchenID = Kitchen.ID()
    let revision = RecipeRevision(recipeID: recipeID, revisionNumber: 1, title: "Soup")
    let stored = StoredRecipe(
      recipe: Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: revision.id),
      revision: revision
    )
    let repository = SessionRecipeRepository(stored: [stored])

    XCTAssertEqual(
      try repository.recipeAuthority(id: recipeID),
      .available(AvailableRecipeAuthority(
        recipe: stored.recipe,
        revisions: [ProjectedRecipeRevision(revision: revision, state: .current)]
      ))
    )
    XCTAssertNil(try repository.recipeAuthority(id: Recipe.ID()))

    let newRevision = RecipeRevision(recipeID: recipeID, revisionNumber: 2, title: "Better")
    try repository.save(RecipeSaveCommand(
      recipe: Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: newRevision.id),
      revision: newRevision,
      savedAt: Date(),
      parentRevisionIDs: [revision.id],
      selection: RecipeSelectionCommand(
        kitchenID: kitchenID,
        recipeID: recipeID,
        selectedRevisionID: newRevision.id,
        selectedAt: Date()
      )
    ))
    XCTAssertEqual(repository.stored.last?.revision, newRevision)

    XCTAssertThrowsError(try repository.select(RecipeSelectionCommand(
      kitchenID: kitchenID,
      recipeID: recipeID,
      selectedRevisionID: revision.id,
      selectedAt: Date()
    ))) { error in
      XCTAssertEqual(error as? KitchenMemoryPersistenceError, .recipeSelectionUnsupported)
    }
  }
}
