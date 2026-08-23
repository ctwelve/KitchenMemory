// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemoryLogic
import KitchenMemoryDomain
import KitchenMemoryPersistence
import XCTest

@MainActor
final class SampleRecipeInstallServiceTests: XCTestCase {
  func testPresenceAndInstallationFollowStableRecipeIdentities() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let samples = FixedSampleProvider()
    let service = SampleRecipeInstallService(repository: repository, samples: samples)

    XCTAssertEqual(try service.presence(in: kitchen.id), .none)

    try repository.addRecipes([samples.recipes(in: kitchen.id)[0]], to: kitchen.id)
    XCTAssertEqual(try service.presence(in: kitchen.id), .partial)

    try service.install(in: kitchen.id)
    XCTAssertEqual(try service.presence(in: kitchen.id), .complete)
    XCTAssertEqual(try repository.recipes(in: kitchen.id).count, 2)
  }
}

@MainActor
private struct FixedSampleProvider: SampleRecipeProviding {
  private let recipeIDs = [Recipe.ID(), Recipe.ID()]
  private let revisionIDs = [RecipeRevision.ID(), RecipeRevision.ID()]

  func recipes(in kitchenID: Kitchen.ID) -> [StoredRecipe] {
    zip(recipeIDs, revisionIDs).enumerated().map { index, identities in
      let (recipeID, revisionID) = identities
      let revision = RecipeRevision(
        id: revisionID,
        recipeID: recipeID,
        revisionNumber: 1,
        title: "Sample \(index + 1)"
      )
      return StoredRecipe(
        recipe: Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: revisionID),
        revision: revision
      )
    }
  }
}
