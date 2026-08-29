// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import SwiftData
import XCTest

@MainActor
final class RecipeRepositoryReconciliationTests: XCTestCase {
  private struct Fixture {
    let container: ModelContainer
    let repository: SwiftDataRecipeRepository
    let kitchen: Kitchen
    let recipeID: UUID
  }

  func testAllRevisionsReconcileWhenCloudKitKeepsOneMutablePointer() throws {
    let fixture = try makeFixture()
    let lowerID = try XCTUnwrap(UUID(uuidString: "10000000-0000-0000-0000-000000000000"))
    let higherID = try XCTUnwrap(UUID(uuidString: "F0000000-0000-0000-0000-000000000000"))
    let context = ModelContext(fixture.container)
    let recipeRecord = try XCTUnwrap(context.fetch(FetchDescriptor<RecipeRecord>()).first)
    recipeRecord.currentRevisionID = lowerID
    context.insert(makeRevision(id: lowerID, recipeID: fixture.recipeID, title: "Pointer winner"))
    context.insert(makeRevision(id: higherID, recipeID: fixture.recipeID, title: "Rule winner"))
    try context.save()

    let repository = SwiftDataRecipeRepository(modelContainer: fixture.container)
    let stored = try XCTUnwrap(repository.recipe(id: .init(rawValue: fixture.recipeID)))

    XCTAssertEqual(stored.revision.title, "Rule winner")
    XCTAssertEqual(stored.recipe.currentRevisionID.rawValue, higherID)
    XCTAssertEqual(
      try repository.revisions(for: stored.id).map(\.title),
      ["Rule winner", "Pointer winner", "Original"]
    )
  }

  func testDeletionHidesStaleCloudRowsUntilExplicitlyRestored() throws {
    let fixture = try makeFixture()
    try fixture.repository.replaceRecipes(in: fixture.kitchen.id, with: [])
    let staleRevisionID = UUID()
    let context = ModelContext(fixture.container)
    context.insert(RecipeRecord(
      id: fixture.recipeID,
      kitchenID: fixture.kitchen.id.rawValue,
      currentRevisionID: staleRevisionID
    ))
    context.insert(makeRevision(
      id: staleRevisionID,
      recipeID: fixture.recipeID,
      title: "Disconnected edit"
    ))
    try context.save()
    let repository = SwiftDataRecipeRepository(modelContainer: fixture.container)
    let recipeID = Recipe.ID(rawValue: fixture.recipeID)

    XCTAssertNil(try repository.recipe(id: recipeID))

    let restored = makeRestoredRecipe(
      recipeID: recipeID,
      revisionID: staleRevisionID,
      kitchenID: fixture.kitchen.id
    )
    try repository.addRecipes([restored], to: fixture.kitchen.id)

    XCTAssertEqual(try repository.recipe(id: recipeID), restored)
    try assertOneDeletionAndResolution(in: fixture.container)
  }

  private func makeFixture() throws -> Fixture {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    let recipeID = Recipe.ID()
    let revision = RecipeRevision(recipeID: recipeID, revisionNumber: 1, title: "Original")
    try repository.save(kitchen)
    try repository.save(
      recipe: Recipe(id: recipeID, kitchenID: kitchen.id, currentRevisionID: revision.id),
      revision: revision
    )
    return Fixture(
      container: container,
      repository: repository,
      kitchen: kitchen,
      recipeID: recipeID.rawValue
    )
  }

  private func makeRestoredRecipe(
    recipeID: Recipe.ID,
    revisionID: UUID,
    kitchenID: Kitchen.ID
  ) -> StoredRecipe {
    let revision = RecipeRevision(
      id: .init(rawValue: revisionID),
      recipeID: recipeID,
      revisionNumber: 2,
      title: "Deliberately restored"
    )
    return StoredRecipe(
      recipe: Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: revision.id),
      revision: revision
    )
  }

  private func makeRevision(id: UUID, recipeID: UUID, title: String) -> RecipeRevisionRecord {
    let emptyList = Data("[]".utf8)
    return RecipeRevisionRecord(
      id: id,
      recipeID: recipeID,
      revisionNumber: 2,
      title: title,
      summary: nil,
      authorName: nil,
      contentLanguage: nil,
      sourceData: nil,
      yieldData: nil,
      prepSeconds: nil,
      cookSeconds: nil,
      totalSeconds: nil,
      cuisinesData: emptyList,
      categoriesData: emptyList,
      keywordsData: emptyList
    )
  }

  private func assertOneDeletionAndResolution(in container: ModelContainer) throws {
    let context = ModelContext(container)
    XCTAssertEqual(try context.fetch(FetchDescriptor<RecipeDeletionRecord>()).count, 1)
    XCTAssertEqual(
      try context.fetch(FetchDescriptor<RecipeDeletionResolutionRecord>()).count,
      1
    )
  }
}
