// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import SwiftData
import XCTest

// Authority backfill scenarios intentionally share the same physical-row fixture helpers.
// swiftlint:disable file_length

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

  func testSelectingExistingRevisionIsRetrySafeAndIgnoresCompatibilityPointer() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let first = makeCommand(kitchenID: kitchen.id, number: 1, title: "First")
    let second = makeCommand(
      kitchenID: kitchen.id,
      recipeID: first.recipe.id,
      number: 2,
      title: "Second",
      parents: [first.revision.id],
      observedSelections: [first.selection.id]
    )
    try repository.save(first)
    try repository.save(second)
    let choice = RecipeSelectionCommand(
      kitchenID: kitchen.id,
      recipeID: first.recipe.id,
      selectedRevisionID: first.revision.id,
      selectedAt: Date(timeIntervalSince1970: 500),
      observedSelectionIDs: [second.selection.id]
    )

    try repository.select(choice)
    try repository.select(choice)
    let context = ModelContext(container)
    for record in try context.fetch(FetchDescriptor<RecipeRecord>()) {
      record.currentRevisionID = second.revision.id.rawValue
    }
    try context.save()

    XCTAssertEqual(try repository.recipe(id: first.recipe.id)?.revision, first.revision)
    XCTAssertEqual(try context.fetchCount(FetchDescriptor<RecipeSelectionRecord>()), 3)
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

  // The assertion keeps deterministic identities, ordering, restoration routing, and retry together.
  // swiftlint:disable:next function_body_length
  func testLegacyBackfillCreatesDeterministicAuthorityAndIsIdempotent() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let recipeID = Recipe.ID()
    let first = makeRevision(recipeID: recipeID, number: 1, title: "First")
    let second = makeRevision(recipeID: recipeID, number: 2, title: "Second")
    let otherRecipeID = Recipe.ID()
    let other = makeRevision(recipeID: otherRecipeID, number: 1, title: "Other")
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
    context.insert(RecipeRecord(
      id: otherRecipeID.rawValue,
      kitchenID: kitchen.id.rawValue,
      currentRevisionID: other.id
    ))
    context.insert(other)
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
    XCTAssertEqual(Set(saves.map(\.id)), Set([first.id, second.id, other.id]))
    XCTAssertEqual(Set(selections.map(\.id)), Set([first.id, second.id, other.id]))
    XCTAssertTrue(saves.allSatisfy { $0.parentRevisionIDsData.isEmpty })
    XCTAssertTrue(selections.allSatisfy { $0.observedSelectionIDsData.isEmpty })
    XCTAssertEqual(
      try reopened.fetch(FetchDescriptor<RecipeDeletionResolutionRecord>()).first?.kitchenID,
      kitchen.id.rawValue
    )
  }

  // Each store isolates one invalid legacy shape so transaction rollback is observable.
  func testLegacyBackfillRejectsInvalidGraphs() throws {
    do {
      let fixture = try makeBackfillStore()
      let container = fixture.container
      let repository = fixture.repository
      let kitchen = fixture.kitchen
      let context = ModelContext(container)
      context.insert(RecipeRecord(
        id: UUID(), kitchenID: kitchen.id.rawValue, currentRevisionID: UUID()
      ))
      try context.save()
      XCTAssertThrowsError(try repository.backfillLegacyRecipeAuthority(in: kitchen.id)) { error in
        XCTAssertEqual(error as? KitchenMemoryPersistenceError, .missingCurrentRevision)
      }
    }
    do {
      let fixture = try makeBackfillStore()
      let container = fixture.container
      let repository = fixture.repository
      let kitchen = fixture.kitchen
      let recipeID = Recipe.ID()
      let first = makeRevision(recipeID: recipeID, number: 1, title: "First")
      let conflict = makeRevision(recipeID: recipeID, number: 1, title: "Conflict")
      conflict.id = first.id
      let context = ModelContext(container)
      context.insert(RecipeRecord(
        id: recipeID.rawValue, kitchenID: kitchen.id.rawValue, currentRevisionID: first.id
      ))
      context.insert(first)
      context.insert(conflict)
      try context.save()
      XCTAssertThrowsError(try repository.backfillLegacyRecipeAuthority(in: kitchen.id))
    }
  }

  func testLegacyBackfillLeavesExistingV5AuthorityUntouched() throws {
    let fixture = try makeBackfillStore()
    let command = makeCommand(kitchenID: fixture.kitchen.id, number: 1, title: "Current")
    try fixture.repository.save(command)
    let context = ModelContext(fixture.container)
    context.insert(RecipeDeletionResolutionRecord(
      id: UUID(), deletionID: UUID(), recipeID: command.recipe.id.rawValue,
      kitchenID: nil, restoredAt: nil
    ))
    try context.save()

    try fixture.repository.backfillLegacyRecipeAuthority(in: fixture.kitchen.id)

    let reopened = ModelContext(fixture.container)
    XCTAssertEqual(try reopened.fetch(FetchDescriptor<RecipeSaveRecord>()).map(\.id), [
      command.id.rawValue,
    ])
    XCTAssertEqual(try reopened.fetch(FetchDescriptor<RecipeSelectionRecord>()).map(\.id), [
      command.selection.id.rawValue,
    ])
    XCTAssertEqual(
      try reopened.fetch(FetchDescriptor<RecipeDeletionResolutionRecord>()).first?.kitchenID,
      fixture.kitchen.id.rawValue
    )
  }

  func testLegacyBackfillDoesNotManufactureDelayedV5Selection() throws {
    let fixture = try makeBackfillStore()
    let command = makeCommand(kitchenID: fixture.kitchen.id, number: 1, title: "Delayed")
    try fixture.repository.save(command)
    let context = ModelContext(fixture.container)
    for selection in try context.fetch(FetchDescriptor<RecipeSelectionRecord>()) {
      context.delete(selection)
    }
    try context.save()

    try fixture.repository.backfillLegacyRecipeAuthority(in: fixture.kitchen.id)

    let reopened = ModelContext(fixture.container)
    XCTAssertEqual(try reopened.fetch(FetchDescriptor<RecipeSaveRecord>()).map(\.id), [
      command.id.rawValue,
    ])
    XCTAssertTrue(try reopened.fetch(FetchDescriptor<RecipeSelectionRecord>()).isEmpty)
  }

  func testLegacyBackfillTreatsPruneAsExistingV5Authority() throws {
    let fixture = try makeBackfillStore()
    let revision = try insertLegacyRecipe(
      in: fixture.container,
      kitchenID: fixture.kitchen.id
    )
    let context = ModelContext(fixture.container)
    context.insert(RecipePruneRecord(
      id: UUID(), kitchenID: fixture.kitchen.id.rawValue, recipeID: revision.recipeID,
      prunedAt: Date(), antiResurrectionUntil: Date(), frontierFormatVersion: 1,
      frontierData: Data(), frontierDigest: Data()
    ))
    try context.save()

    try fixture.repository.backfillLegacyRecipeAuthority(in: fixture.kitchen.id)

    let reopened = ModelContext(fixture.container)
    XCTAssertTrue(try reopened.fetch(FetchDescriptor<RecipeSaveRecord>()).isEmpty)
    XCTAssertTrue(try reopened.fetch(FetchDescriptor<RecipeSelectionRecord>()).isEmpty)
  }

  func testLegacyBackfillRejectsCrossRecipeSaveIdentityBeforeMutation() throws {
    let fixture = try makeBackfillStore()
    let revision = try insertLegacyRecipe(in: fixture.container, kitchenID: fixture.kitchen.id)
    let context = ModelContext(fixture.container)
    context.insert(RecipeSaveRecord(
      id: revision.id, kitchenID: UUID(), recipeID: UUID(), revisionID: UUID(),
      savedAt: .distantPast, ancestryFormatVersion: 1, parentRevisionIDsData: Data(),
      payloadManifestFormatVersion: 1, payloadManifestData: Data(),
      revisionFormatVersion: 1, revisionDigest: Data()
    ))
    try context.save()

    XCTAssertThrowsError(
      try fixture.repository.backfillLegacyRecipeAuthority(in: fixture.kitchen.id)
    ) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .recipeSaveCommandCollision(commandID: .init(rawValue: revision.id))
      )
    }
    assertAuthorityCounts(container: fixture.container, saves: 1, selections: 0, revisions: 1)
  }

  func testLegacyBackfillRejectsCrossRecipeSelectionIdentityAndRollsBackSave() throws {
    let fixture = try makeBackfillStore()
    let revision = try insertLegacyRecipe(in: fixture.container, kitchenID: fixture.kitchen.id)
    let context = ModelContext(fixture.container)
    context.insert(RecipeSelectionRecord(
      id: revision.id, kitchenID: UUID(), recipeID: UUID(), selectedRevisionID: UUID(),
      selectedAt: .distantPast, frontierFormatVersion: 1,
      observedSelectionIDsData: Data()
    ))
    try context.save()

    XCTAssertThrowsError(
      try fixture.repository.backfillLegacyRecipeAuthority(in: fixture.kitchen.id)
    ) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .recipeSelectionCommandCollision(commandID: .init(rawValue: revision.id))
      )
    }
    assertAuthorityCounts(container: fixture.container, saves: 0, selections: 1, revisions: 1)
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

  private func makeBackfillStore() throws -> BackfillStore {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    return BackfillStore(container: container, repository: repository, kitchen: kitchen)
  }

  @discardableResult
  private func insertLegacyRecipe(
    in container: ModelContainer,
    kitchenID: Kitchen.ID
  ) throws -> RecipeRevisionRecord {
    let recipeID = Recipe.ID()
    let revision = makeRevision(recipeID: recipeID, number: 1, title: "Legacy")
    let context = ModelContext(container)
    context.insert(RecipeRecord(
      id: recipeID.rawValue, kitchenID: kitchenID.rawValue, currentRevisionID: revision.id
    ))
    context.insert(revision)
    try context.save()
    return revision
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

@MainActor
private struct BackfillStore {
  let container: ModelContainer
  let repository: SwiftDataRecipeRepository
  let kitchen: Kitchen
}
