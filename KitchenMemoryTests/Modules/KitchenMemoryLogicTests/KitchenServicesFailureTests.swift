// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemoryLogic
import KitchenMemoryDomain
import KitchenMemoryPersistence
import XCTest

@MainActor
final class KitchenServicesFailureTests: XCTestCase {
  func testSampleFailureCannotPartiallyBootstrapAKitchen() throws {
    let repository = try makeRepository()
    let service = KitchenBootstrapService(
      repository: repository,
      samples: FailingSampleProvider()
    )

    XCTAssertThrowsError(try service.prepareInitialKitchen())
    XCTAssertTrue(try repository.kitchens().isEmpty)
  }

  func testSampleFailureCannotClearExistingRecipesDuringReset() throws {
    let repository = try makeRepository()
    let kitchen = Kitchen(name: "Home")
    let recipeID = Recipe.ID()
    let revision = RecipeRevision(recipeID: recipeID, revisionNumber: 1, title: "Keep")
    let stored = StoredRecipe(
      recipe: Recipe(
        id: recipeID,
        kitchenID: kitchen.id,
        currentRevisionID: revision.id
      ),
      revision: revision
    )
    try repository.create(kitchen, with: [stored])
    let service = KitchenResetService(repository: repository, samples: FailingSampleProvider())

    XCTAssertThrowsError(try service.reset(kitchenID: kitchen.id))
    XCTAssertEqual(try repository.recipes(in: kitchen.id), [stored])
  }

  private func makeRepository() throws -> SwiftDataRecipeRepository {
    SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
  }
}

@MainActor
private struct FailingSampleProvider: SampleRecipeProviding {
  struct Failure: Error {}

  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] {
    throw Failure()
  }
}
