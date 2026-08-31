// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import SwiftData
import XCTest

@MainActor
final class KitchenConvergenceWorkflowTests: XCTestCase {
  func testConvergedAlphaLibraryCanResetAndStartCooking() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let context = ModelContext(container)
    let legacyKitchenID = Kitchen.ID()
    let recipeID = Recipe.ID()
    let oldRevision = RecipeRevision(recipeID: recipeID, revisionNumber: 1, title: "Old Sample")
    context.insert(KitchenRecord(id: legacyKitchenID.rawValue, name: "Legacy"))
    context.insert(KitchenRecord(
      id: KitchenBootstrapService.personalKitchenID.rawValue,
      name: "Home Kitchen"
    ))
    for kitchenID in [legacyKitchenID, KitchenBootstrapService.personalKitchenID] {
      context.insert(RecipeRecord(
        id: recipeID.rawValue,
        kitchenID: kitchenID.rawValue,
        currentRevisionID: oldRevision.id.rawValue
      ))
    }
    context.insert(revisionRecord(oldRevision))
    try context.save()
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let ownerID = KitchenOwner.ID(rawValue: "cloudkit:production:current-user")
    let kitchen = try KitchenBootstrapService(repository: repository)
      .prepareInitialKitchenWithStatus(ownerID: ownerID).kitchen
    let sample = storedRecipe(recipeID: recipeID, kitchenID: kitchen.id)

    try KitchenResetService(
      repository: repository,
      samples: OneSampleRecipe(stored: sample)
    ).reset(kitchenID: kitchen.id)
    let resetRecipe = try XCTUnwrap(repository.recipe(id: recipeID))
    let sessions = CookingSessions(
      kitchenID: kitchen.id,
      recipeRepository: repository,
      sessionRepository: InMemoryCookingSessionRepository()
    )

    guard case .accepted = try sessions.start(StartCookingSessionIntention(
      sessionID: CookingSession.ID(),
      recipeID: resetRecipe.id,
      recipeRevisionID: resetRecipe.revision.id,
      startedAt: Date(timeIntervalSince1970: 100)
    )) else {
      XCTFail("Expected the reset recipe to start a Cooking Session")
      return
    }
  }

  private func storedRecipe(recipeID: Recipe.ID, kitchenID: Kitchen.ID) -> StoredRecipe {
    let revision = RecipeRevision(recipeID: recipeID, revisionNumber: 1, title: "Sample")
    return StoredRecipe(
      recipe: Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: revision.id),
      revision: revision
    )
  }

  private func revisionRecord(_ revision: RecipeRevision) -> RecipeRevisionRecord {
    RecipeRevisionRecord(
      id: revision.id.rawValue,
      recipeID: revision.recipeID.rawValue,
      revisionNumber: revision.revisionNumber,
      title: revision.title,
      summary: nil,
      authorName: nil,
      contentLanguage: nil,
      sourceData: nil,
      yieldData: nil,
      prepSeconds: nil,
      cookSeconds: nil,
      totalSeconds: nil,
      cuisinesData: Data("[]".utf8),
      categoriesData: Data("[]".utf8),
      keywordsData: Data("[]".utf8)
    )
  }
}

@MainActor
private struct OneSampleRecipe: SampleRecipeProviding {
  let stored: StoredRecipe

  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] {
    [stored]
  }
}
