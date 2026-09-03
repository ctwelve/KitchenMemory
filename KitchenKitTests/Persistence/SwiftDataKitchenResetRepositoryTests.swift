// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import SwiftData
import XCTest

@MainActor
final class SwiftDataKitchenResetRepositoryTests: XCTestCase {
  func testResetAtomicallyLeavesOnlySamplesAndPreservesAnotherKitchen() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let recipes = SwiftDataRecipeRepository(modelContainer: container)
    let target = Kitchen(name: "Home")
    let other = Kitchen(name: "Cabin")
    try recipes.save(target)
    try recipes.save(other)
    let userRecipe = storedRecipe(kitchenID: target.id, title: "User")
    let otherRecipe = storedRecipe(kitchenID: other.id, title: "Other")
    let sample = storedRecipe(kitchenID: target.id, title: "Sample")
    try recipes.save(recipe: userRecipe.recipe, revision: userRecipe.revision)
    try recipes.save(recipe: otherRecipe.recipe, revision: otherRecipe.revision)
    let context = ModelContext(container)
    insertSessionFamilies(kitchenID: target.id.rawValue, marker: 1, context: context)
    insertSessionFamilies(kitchenID: other.id.rawValue, marker: 2, context: context)
    context.insert(RecipeDeletionRecord(
      id: UUID(),
      recipeID: userRecipe.id.rawValue,
      kitchenID: target.id.rawValue,
      deletedAt: Date()
    ))
    try context.save()

    try SwiftDataKitchenResetRepository(modelContainer: container)
      .reset(kitchenID: target.id, to: [sample])

    let reloadedRecipes = SwiftDataRecipeRepository(modelContainer: container)
    XCTAssertEqual(try reloadedRecipes.recipes(in: target.id), [sample])
    XCTAssertEqual(try reloadedRecipes.recipes(in: other.id), [otherRecipe])
    let verification = ModelContext(container)
    assertSessionCounts(verification, kitchenID: target.id.rawValue, expected: 0)
    assertSessionCounts(verification, kitchenID: other.id.rawValue, expected: 1)
    XCTAssertFalse(try verification.fetch(FetchDescriptor<RecipeDeletionRecord>())
      .contains { $0.recipeID == userRecipe.id.rawValue })
    XCTAssertFalse(try verification.fetch(FetchDescriptor<RecipeSaveRecord>())
      .contains { $0.recipeID == userRecipe.id.rawValue })
    XCTAssertEqual(try verification.fetch(FetchDescriptor<RecipeSaveRecord>())
      .filter { $0.kitchenID == target.id.rawValue }.map(\.recipeID), [sample.id.rawValue])
  }

  func testFailedResetLeavesRecipeAndSessionGraphsUntouchedAcrossRelaunch() throws {
    try withStore { storeURL in
      let writable = try KitchenMemorySchema.makeContainer(storeURL: storeURL)
      let recipes = SwiftDataRecipeRepository(modelContainer: writable)
      let kitchen = Kitchen(name: "Home")
      let original = storedRecipe(kitchenID: kitchen.id, title: "Original")
      let sample = storedRecipe(kitchenID: kitchen.id, title: "Sample")
      try recipes.save(kitchen)
      try recipes.save(recipe: original.recipe, revision: original.revision)
      let context = ModelContext(writable)
      insertSessionFamilies(kitchenID: kitchen.id.rawValue, marker: 1, context: context)
      try context.save()

      let readOnly = try readOnlyContainer(storeURL: storeURL)
      XCTAssertThrowsError(
        try SwiftDataKitchenResetRepository(modelContainer: readOnly)
          .reset(kitchenID: kitchen.id, to: [sample])
      )

      let reopened = try KitchenMemorySchema.makeContainer(storeURL: storeURL)
      XCTAssertEqual(
        try SwiftDataRecipeRepository(modelContainer: reopened).recipes(in: kitchen.id),
        [original]
      )
      assertSessionCounts(ModelContext(reopened), kitchenID: kitchen.id.rawValue, expected: 1)
    }
  }

  private func storedRecipe(kitchenID: Kitchen.ID, title: String) -> StoredRecipe {
    let recipeID = Recipe.ID()
    let revision = RecipeRevision(recipeID: recipeID, revisionNumber: 1, title: title)
    return StoredRecipe(
      recipe: Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: revision.id),
      revision: revision
    )
  }

  // Placeholder values are sufficient: reset owns physical removal, not projection.
  private func insertSessionFamilies(kitchenID: UUID, marker: Int, context: ModelContext) {
    let sessionID = UUID()
    context.insert(CookingSessionRecord(
      id: sessionID, kitchenID: kitchenID, recipeID: UUID(), recipeRevisionID: UUID(),
      startedAt: Date(), snapshotFormatVersion: marker, snapshotData: Data(),
      snapshotDigest: Data(), sourceSessionID: nil, sourceClosureID: nil
    ))
    context.insert(SessionFactRecord(
      id: UUID(), sessionID: sessionID, kitchenID: kitchenID, kind: "test",
      targetSnapshotElementID: nil, authoredAt: Date(), causalHeadsFormatVersion: marker,
      causalHeadsData: Data(), payloadFormatVersion: marker, payloadData: Data(),
      payloadDigest: Data()
    ))
    context.insert(SessionClosureRecord(
      id: UUID(), sessionID: sessionID, kitchenID: kitchenID, finishedAt: Date(),
      causalHeadsFormatVersion: marker, causalHeadsData: Data(), snapshotFormatVersion: marker,
      snapshotDigest: Data(), projectionFormatVersion: marker, projectionDigest: Data(),
      outcomeFormatVersion: nil, outcomeData: nil
    ))
    context.insert(SessionDeletionRecord(
      id: UUID(), sessionID: sessionID, kitchenID: kitchenID, deletedAt: Date(),
      sessionHeadsFormatVersion: marker, sessionHeadsData: Data(),
      dispositionHeadsFormatVersion: marker, dispositionHeadsData: Data()
    ))
    context.insert(SessionDeletionResolutionRecord(
      id: UUID(), deletionID: UUID(), sessionID: sessionID, kitchenID: kitchenID,
      restoredAt: Date(), dispositionHeadsFormatVersion: marker,
      dispositionHeadsData: Data()
    ))
  }

  private func assertSessionCounts(
    _ context: ModelContext,
    kitchenID: UUID,
    expected: Int,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertEqual(
      try context.fetch(FetchDescriptor<CookingSessionRecord>()).filter { $0.kitchenID == kitchenID }.count,
      expected, file: file, line: line
    )
    XCTAssertEqual(
      try context.fetch(FetchDescriptor<SessionFactRecord>()).filter { $0.kitchenID == kitchenID }.count,
      expected, file: file, line: line
    )
    XCTAssertEqual(
      try context.fetch(FetchDescriptor<SessionClosureRecord>()).filter { $0.kitchenID == kitchenID }.count,
      expected, file: file, line: line
    )
    XCTAssertEqual(
      try context.fetch(FetchDescriptor<SessionDeletionRecord>()).filter { $0.kitchenID == kitchenID }.count,
      expected, file: file, line: line
    )
    XCTAssertEqual(
      try context.fetch(FetchDescriptor<SessionDeletionResolutionRecord>())
        .filter { $0.kitchenID == kitchenID }.count,
      expected, file: file, line: line
    )
  }

  private func readOnlyContainer(storeURL: URL) throws -> ModelContainer {
    let schema = Schema(versionedSchema: KitchenMemorySchemaV5.self)
    return try ModelContainer(
      for: schema,
      migrationPlan: KitchenMemoryMigrationPlan.self,
      configurations: [ModelConfiguration(
        "KitchenMemoryResetReadOnly",
        schema: schema,
        url: storeURL,
        allowsSave: false,
        cloudKitDatabase: .none
      )],
    )
  }

  private func withStore(_ operation: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "KitchenMemoryResetTests")
      .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try operation(directory.appending(path: "KitchenMemory.store"))
  }
}
