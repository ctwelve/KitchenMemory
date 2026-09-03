// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import SwiftData
import XCTest

@MainActor
// The suite keeps one authority writer fixture boundary visible in one place.
// swiftlint:disable:next type_body_length
final class SwiftDataRecipeAuthoritySaveTests: XCTestCase {
  func testFirstSaveAndExactRetryCoalesceAllLogicalRowsAcrossRelaunch() throws {
    try withStore { storeURL in
      let container = try KitchenMemorySchema.makeContainer(storeURL: storeURL)
      let repository = SwiftDataRecipeRepository(modelContainer: container)
      let kitchen = Kitchen(name: "Home")
      try repository.save(kitchen)
      let command = makeCommand(kitchenID: kitchen.id, number: 1, title: "Soup")

      try repository.save(command)
      try repository.save(command)

      XCTAssertEqual(try repository.recipe(id: command.recipe.id)?.revision, command.revision)
      assertAuthorityCounts(container: container, saves: 1, selections: 1, revisions: 1)

      let reopenedContainer = try KitchenMemorySchema.makeContainer(storeURL: storeURL)
      let reopened = SwiftDataRecipeRepository(modelContainer: reopenedContainer)
      XCTAssertEqual(try reopened.recipe(id: command.recipe.id)?.revision, command.revision)
      assertAuthorityCounts(container: reopenedContainer, saves: 1, selections: 1, revisions: 1)
    }
  }

  func testLaterSavePreservesPriorRevisionAndCanonicalExplicitParents() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let first = makeCommand(kitchenID: kitchen.id, number: 1, title: "Soup")
    try repository.save(first)
    let second = makeCommand(
      kitchenID: kitchen.id,
      recipeID: first.recipe.id,
      number: 2,
      title: "Better Soup",
      parents: [first.revision.id],
      observedSelections: [first.selection.id]
    )

    try repository.save(second)

    XCTAssertEqual(try repository.revisions(for: first.recipe.id), [second.revision, first.revision])
    let context = ModelContext(container)
    let record = try XCTUnwrap(
      try context.fetch(FetchDescriptor<RecipeSaveRecord>())
        .first { $0.id == second.id.rawValue }
    )
    XCTAssertEqual(
      try RecipeIdentifierSetCodec.decode(
        formatVersion: record.ancestryFormatVersion,
        data: record.parentRevisionIDsData
      ),
      [first.revision.id.rawValue]
    )
  }

  func testConflictingSaveOrSelectionIdentityIsRejectedWithoutMutation() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let original = makeCommand(kitchenID: kitchen.id, number: 1, title: "Soup")
    try repository.save(original)

    let saveCollision = RecipeSaveCommand(
      id: original.id,
      recipe: original.recipe,
      revision: original.revision,
      savedAt: original.savedAt.addingTimeInterval(1),
      parentRevisionIDs: [],
      selection: original.selection
    )
    XCTAssertThrowsError(try repository.save(saveCollision)) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .recipeSaveCommandCollision(commandID: original.id)
      )
    }

    let changedSelection = RecipeSelectionCommand(
      id: original.selection.id,
      kitchenID: kitchen.id,
      recipeID: original.recipe.id,
      selectedRevisionID: original.revision.id,
      selectedAt: original.selection.selectedAt.addingTimeInterval(1)
    )
    let selectionCollision = RecipeSaveCommand(
      id: RecipeSaveCommand.ID(),
      recipe: original.recipe,
      revision: original.revision,
      savedAt: original.savedAt,
      parentRevisionIDs: [],
      selection: changedSelection
    )
    XCTAssertThrowsError(try repository.save(selectionCollision)) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .recipeSelectionCommandCollision(commandID: original.selection.id)
      )
    }
    assertAuthorityCounts(container: container, saves: 1, selections: 1, revisions: 1)
  }

  func testReadOnlyFailureLeavesNoRecipePayloadOrAuthorityEvidence() throws {
    try withStore { storeURL in
      let writable = try KitchenMemorySchema.makeContainer(storeURL: storeURL)
      let kitchen = Kitchen(name: "Home")
      try SwiftDataRecipeRepository(modelContainer: writable).save(kitchen)

      let readOnly = try readOnlyContainer(storeURL: storeURL)
      let repository = SwiftDataRecipeRepository(modelContainer: readOnly)
      let command = makeCommand(kitchenID: kitchen.id, number: 1, title: "Phantom")
      XCTAssertThrowsError(try repository.save(command))

      let reopened = try KitchenMemorySchema.makeContainer(storeURL: storeURL)
      XCTAssertNil(
        try SwiftDataRecipeRepository(modelContainer: reopened).recipe(id: command.recipe.id)
      )
      assertAuthorityCounts(container: reopened, saves: 0, selections: 0, revisions: 0)
    }
  }

  func testLegacyBackfillCreatesDeterministicAuthorityAndIsIdempotent() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let recipeID = Recipe.ID()
    let first = makeRevision(recipeID: recipeID, number: 1, title: "First")
    let second = makeRevision(recipeID: recipeID, number: 2, title: "Second")
    let context = ModelContext(container)
    context.insert(RecipeRecord(
      id: recipeID.rawValue,
      kitchenID: kitchen.id.rawValue,
      currentRevisionID: first.id
    ))
    context.insert(RecipeRecord(
      id: recipeID.rawValue,
      kitchenID: kitchen.id.rawValue,
      currentRevisionID: second.id
    ))
    context.insert(first)
    context.insert(second)
    let deletionID = UUID()
    context.insert(RecipeDeletionRecord(
      id: deletionID,
      recipeID: recipeID.rawValue,
      kitchenID: kitchen.id.rawValue
    ))
    context.insert(RecipeDeletionResolutionRecord(
      id: UUID(),
      deletionID: deletionID,
      recipeID: recipeID.rawValue,
      kitchenID: nil
    ))
    try context.save()

    try repository.backfillLegacyRecipeAuthority(in: kitchen.id)
    try repository.backfillLegacyRecipeAuthority(in: kitchen.id)

    let reopened = ModelContext(container)
    let saves = try reopened.fetch(FetchDescriptor<RecipeSaveRecord>())
    let selections = try reopened.fetch(FetchDescriptor<RecipeSelectionRecord>())
    XCTAssertEqual(Set(saves.map(\.id)), Set([first.id, second.id]))
    XCTAssertEqual(Set(selections.map(\.id)), Set([first.id, second.id]))
    XCTAssertTrue(saves.allSatisfy { $0.parentRevisionIDsData.isEmpty })
    XCTAssertTrue(selections.allSatisfy { $0.observedSelectionIDsData.isEmpty })
    XCTAssertEqual(
      try reopened.fetch(FetchDescriptor<RecipeDeletionResolutionRecord>()).first?.kitchenID,
      kitchen.id.rawValue
    )
  }

  func testSaveRejectsUnknownCausalReferencesWithoutMutation() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)

    let missingParent = makeCommand(
      kitchenID: kitchen.id,
      number: 1,
      title: "Orphan",
      parents: [.init()]
    )
    XCTAssertThrowsError(try repository.save(missingParent))

    let missingSelection = makeCommand(
      kitchenID: kitchen.id,
      number: 1,
      title: "Unobserved",
      observedSelections: [.init()]
    )
    XCTAssertThrowsError(try repository.save(missingSelection))

    assertAuthorityCounts(container: container, saves: 0, selections: 0, revisions: 0)
  }

  private func makeCommand(
    kitchenID: Kitchen.ID,
    recipeID: Recipe.ID = Recipe.ID(),
    number: Int,
    title: String,
    parents: [RecipeRevision.ID] = [],
    observedSelections: [RecipeSelectionCommand.ID] = []
  ) -> RecipeSaveCommand {
    let revision = RecipeRevision(recipeID: recipeID, revisionNumber: number, title: title)
    let recipe = Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: revision.id)
    return RecipeSaveCommand(
      recipe: recipe,
      revision: revision,
      savedAt: Date(timeIntervalSince1970: TimeInterval(100 + number)),
      parentRevisionIDs: parents,
      selection: RecipeSelectionCommand(
        kitchenID: kitchenID,
        recipeID: recipeID,
        selectedRevisionID: revision.id,
        selectedAt: Date(timeIntervalSince1970: TimeInterval(200 + number)),
        observedSelectionIDs: observedSelections
      )
    )
  }

  private func makeRevision(
    recipeID: Recipe.ID,
    number: Int,
    title: String
  ) -> RecipeRevisionRecord {
    RecipeRevisionRecord(
      id: UUID(),
      recipeID: recipeID.rawValue,
      revisionNumber: number,
      title: title,
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

  private func assertAuthorityCounts(
    container: ModelContainer,
    saves: Int,
    selections: Int,
    revisions: Int,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let context = ModelContext(container)
    XCTAssertEqual(try context.fetchCount(FetchDescriptor<RecipeSaveRecord>()), saves, file: file, line: line)
    XCTAssertEqual(
      try context.fetchCount(FetchDescriptor<RecipeSelectionRecord>()),
      selections,
      file: file,
      line: line
    )
    XCTAssertEqual(
      try context.fetchCount(FetchDescriptor<RecipeRevisionRecord>()),
      revisions,
      file: file,
      line: line
    )
  }

  private func readOnlyContainer(storeURL: URL) throws -> ModelContainer {
    let schema = Schema(versionedSchema: KitchenMemorySchemaV5.self)
    let configuration = ModelConfiguration(
      "KitchenMemoryAuthorityReadOnly",
      schema: schema,
      url: storeURL,
      allowsSave: false,
      cloudKitDatabase: .none
    )
    return try ModelContainer(
      for: schema,
      migrationPlan: KitchenMemoryMigrationPlan.self,
      configurations: [configuration]
    )
  }

  private func withStore(_ operation: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "KitchenMemoryRecipeAuthorityTests")
      .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try operation(directory.appending(path: "KitchenMemory.store"))
  }
}
