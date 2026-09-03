// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import SwiftData
import XCTest

// The matrix keeps all persistence-bound authority failure modes beside one shared fixture.
// swiftlint:disable file_length

@MainActor
// swiftlint:disable:next type_body_length
final class SwiftDataRecipeAuthorityFailureTests: XCTestCase {
  // This one scenario asserts each rejected Selection shape and the unchanged durable result.
  // swiftlint:disable:next function_body_length
  func testSelectionValidationAndCollisionLeaveAcceptedChoiceIntact() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let command = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(command)

    let duplicateFrontier = RecipeSelectionCommand(
      kitchenID: kitchen.id, recipeID: command.recipe.id,
      selectedRevisionID: command.revision.id, selectedAt: Date(),
      observedSelectionIDs: [command.selection.id, command.selection.id]
    )
    XCTAssertThrowsError(try repository.select(duplicateFrontier)) { error in
      XCTAssertEqual(error as? KitchenMemoryPersistenceError, .invalidRecipeSaveCommand)
    }

    let unknownRevision = RecipeSelectionCommand(
      kitchenID: kitchen.id, recipeID: command.recipe.id,
      selectedRevisionID: RecipeRevision.ID(), selectedAt: Date()
    )
    XCTAssertThrowsError(try repository.select(unknownRevision)) { error in
      XCTAssertEqual(error as? KitchenMemoryPersistenceError, .invalidRecipeSaveCommand)
    }

    let unknownObservation = RecipeSelectionCommand(
      kitchenID: kitchen.id, recipeID: command.recipe.id,
      selectedRevisionID: command.revision.id, selectedAt: Date(),
      observedSelectionIDs: [.init()]
    )
    XCTAssertThrowsError(try repository.select(unknownObservation)) { error in
      XCTAssertEqual(error as? KitchenMemoryPersistenceError, .invalidRecipeSaveCommand)
    }

    let choice = RecipeSelectionCommand(
      kitchenID: kitchen.id, recipeID: command.recipe.id,
      selectedRevisionID: command.revision.id, selectedAt: Date(),
      observedSelectionIDs: [command.selection.id]
    )
    try repository.select(choice)
    let collision = RecipeSelectionCommand(
      id: choice.id, kitchenID: choice.kitchenID, recipeID: choice.recipeID,
      selectedRevisionID: choice.selectedRevisionID,
      selectedAt: choice.selectedAt.addingTimeInterval(1),
      observedSelectionIDs: choice.observedSelectionIDs
    )
    XCTAssertThrowsError(try repository.select(collision)) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .recipeSelectionCommandCollision(commandID: choice.id)
      )
    }
    XCTAssertEqual(
      try ModelContext(container).fetchCount(FetchDescriptor<RecipeSelectionRecord>()),
      2
    )
  }

  func testCompatibilitySaveUsesProjectedRevisionAndSelectionHeads() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let first = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(recipe: first.recipe, revision: first.revision)
    let second = makeCommand(
      kitchenID: kitchen.id, recipeID: first.recipe.id, number: 2,
      parents: [first.revision.id],
      observed: [.init(rawValue: first.revision.id.rawValue)]
    )
    try repository.save(second)
    let choice = RecipeSelectionCommand(
      kitchenID: kitchen.id, recipeID: first.recipe.id,
      selectedRevisionID: first.revision.id, selectedAt: Date(),
      observedSelectionIDs: [second.selection.id]
    )
    try repository.select(choice)

    let thirdRevision = RecipeRevision(
      recipeID: first.recipe.id, revisionNumber: 3, title: "Revision 3"
    )
    let thirdRecipe = Recipe(
      id: first.recipe.id, kitchenID: kitchen.id, currentRevisionID: thirdRevision.id
    )
    try repository.save(recipe: thirdRecipe, revision: thirdRevision)
    try repository.save(recipe: thirdRecipe, revision: thirdRevision)

    let context = ModelContext(container)
    let save = try XCTUnwrap(try context.fetch(FetchDescriptor<RecipeSaveRecord>())
      .first { $0.id == thirdRevision.id.rawValue })
    XCTAssertEqual(
      try RecipeIdentifierSetCodec.decode(
        formatVersion: save.ancestryFormatVersion, data: save.parentRevisionIDsData
      ),
      [first.revision.id.rawValue]
    )
    let selection = try XCTUnwrap(try context.fetch(FetchDescriptor<RecipeSelectionRecord>())
      .first { $0.id == thirdRevision.id.rawValue })
    XCTAssertEqual(
      try RecipeIdentifierSetCodec.decode(
        formatVersion: selection.frontierFormatVersion,
        data: selection.observedSelectionIDsData
      ),
      [choice.id.rawValue]
    )
  }

  func testRepositoryMapsDeletionAndRestoration() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let command = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(command)
    let deletionID = UUID()
    let context = ModelContext(container)
    context.insert(RecipeDeletionRecord(
      id: deletionID, recipeID: command.recipe.id.rawValue,
      kitchenID: kitchen.id.rawValue, deletedAt: Date()
    ))
    try context.save()
    let deletedReader = SwiftDataRecipeRepository(modelContainer: container)
    guard case .deleted = try deletedReader.recipeAuthority(id: command.recipe.id) else {
      XCTFail("Expected deleted authority")
      return
    }
    XCTAssertNil(try deletedReader.recipe(id: command.recipe.id))

    let restorationContext = ModelContext(container)
    restorationContext.insert(RecipeDeletionResolutionRecord(
      id: UUID(), deletionID: deletionID, recipeID: command.recipe.id.rawValue,
      kitchenID: kitchen.id.rawValue, restoredAt: Date()
    ))
    try restorationContext.save()
    let restoredReader = SwiftDataRecipeRepository(modelContainer: container)
    guard case .available = try restoredReader.recipeAuthority(id: command.recipe.id) else {
      XCTFail("Expected restored authority")
      return
    }
  }

  func testRepositoryMapsPruneAndCorruption() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let command = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(command)
    let prunedRecipeID = Recipe.ID()
    let frontier = RecipeAuthorityFrontierCodec.encode(RecipeAuthorityFrontier(
      revisionHeads: [], selectionHeads: [], deletionIDs: [], restorationIDs: []
    ))
    let pruneContext = ModelContext(container)
    pruneContext.insert(RecipePruneRecord(
      id: UUID(), kitchenID: kitchen.id.rawValue, recipeID: prunedRecipeID.rawValue,
      prunedAt: Date(), antiResurrectionUntil: Date().addingTimeInterval(1),
      frontierFormatVersion: frontier.formatVersion, frontierData: frontier.data,
      frontierDigest: frontier.digest
    ))
    try pruneContext.save()
    let pruneReader = SwiftDataRecipeRepository(modelContainer: container)
    XCTAssertEqual(try pruneReader.recipeAuthority(id: prunedRecipeID), .pruned)
    XCTAssertNil(try pruneReader.recipe(id: prunedRecipeID))

    let corruptContext = ModelContext(container)
    let save = try XCTUnwrap(try corruptContext.fetch(FetchDescriptor<RecipeSaveRecord>())
      .first { $0.recipeID == command.recipe.id.rawValue })
    save.parentRevisionIDsData = Data([0])
    try corruptContext.save()
    XCTAssertThrowsError(
      try SwiftDataRecipeRepository(modelContainer: container).recipe(id: command.recipe.id)
    ) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .invalidStoredValue(field: "recipe.authority")
      )
    }
  }

  func testPartialScopedEvidenceRemainsVisibleAndPayloadNeedsNoCompatibilityRow() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let partialRecipeID = Recipe.ID()
    let context = ModelContext(container)
    context.insert(RecipeSelectionRecord(
      id: UUID(), kitchenID: kitchen.id.rawValue, recipeID: partialRecipeID.rawValue,
      selectedRevisionID: UUID(), selectedAt: Date(), frontierFormatVersion: 1,
      observedSelectionIDsData: Data()
    ))
    context.insert(RecipeDeletionResolutionRecord(
      id: UUID(), deletionID: UUID(), recipeID: UUID(),
      kitchenID: kitchen.id.rawValue, restoredAt: nil
    ))
    let frontier = RecipeAuthorityFrontierCodec.encode(RecipeAuthorityFrontier(
      revisionHeads: [], selectionHeads: [], deletionIDs: [], restorationIDs: []
    ))
    context.insert(RecipePruneRecord(
      id: UUID(), kitchenID: kitchen.id.rawValue, recipeID: UUID(),
      prunedAt: .distantPast, antiResurrectionUntil: .distantFuture,
      frontierFormatVersion: frontier.formatVersion, frontierData: frontier.data,
      frontierDigest: frontier.digest
    ))
    try context.save()

    XCTAssertEqual(
      try repository.recipeAuthority(id: partialRecipeID),
      .unavailable(.noSaveEvidence)
    )

    let command = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(command)
    let cleanup = ModelContext(container)
    for record in try cleanup.fetch(FetchDescriptor<RecipeRecord>())
    where record.id == command.recipe.id.rawValue {
      cleanup.delete(record)
    }
    try cleanup.save()

    XCTAssertEqual(try repository.recipes(in: kitchen.id).map(\.id), [command.recipe.id])
  }

  func testConflictingPhysicalChildRowsBecomePayloadRecovery() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let recipeID = Recipe.ID()
    let mediaID = RecipeMedia.ID()
    let revision = RecipeRevision(
      recipeID: recipeID, revisionNumber: 1, title: "Soup",
      media: [RecipeMedia(id: mediaID, role: .hero, assetName: "first")]
    )
    let recipe = Recipe(id: recipeID, kitchenID: kitchen.id, currentRevisionID: revision.id)
    let command = RecipeSaveCommand(
      recipe: recipe, revision: revision, savedAt: Date(), parentRevisionIDs: [],
      selection: RecipeSelectionCommand(
        kitchenID: kitchen.id, recipeID: recipeID,
        selectedRevisionID: revision.id, selectedAt: Date()
      )
    )
    try repository.save(command)
    let context = ModelContext(container)
    context.insert(RecipeMediaRecord(
      id: mediaID.rawValue, revisionID: revision.id.rawValue, sortIndex: 0,
      role: RecipeMedia.Role.hero.rawValue, assetName: "conflict", accessibilityLabel: nil
    ))
    try context.save()

    XCTAssertEqual(
      try repository.recipeAuthority(id: recipeID),
      .recovery(.payloadCollision(revision.id))
    )
  }

  func testMissingAuthoritativeRevisionMapsToLegacyMissingRevisionFailure() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let command = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(command)
    let context = ModelContext(container)
    for record in try context.fetch(FetchDescriptor<RecipeRevisionRecord>()) {
      context.delete(record)
    }
    try context.save()

    XCTAssertThrowsError(
      try SwiftDataRecipeRepository(modelContainer: container).recipe(id: command.recipe.id)
    ) { error in
      XCTAssertEqual(error as? KitchenMemoryPersistenceError, .missingCurrentRevision)
    }
  }

  func testSaveRejectsDuplicateManifestIdentity() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let mediaID = RecipeMedia.ID()
    let duplicateMedia = RecipeRevision(
      recipeID: Recipe.ID(), revisionNumber: 1, title: "Duplicate",
      media: [
        RecipeMedia(id: mediaID, role: .hero, assetName: "one"),
        RecipeMedia(id: mediaID, role: .gallery, assetName: "two"),
      ]
    )
    let duplicateRecipe = Recipe(
      id: duplicateMedia.recipeID, kitchenID: kitchen.id,
      currentRevisionID: duplicateMedia.id
    )
    XCTAssertThrowsError(try repository.save(RecipeSaveCommand(
      recipe: duplicateRecipe,
      revision: duplicateMedia,
      savedAt: Date(),
      parentRevisionIDs: [],
      selection: RecipeSelectionCommand(
        kitchenID: kitchen.id, recipeID: duplicateRecipe.id,
        selectedRevisionID: duplicateMedia.id, selectedAt: Date()
      )
    ))) { error in
      XCTAssertEqual(error as? KitchenMemoryPersistenceError, .invalidRecipeSaveCommand)
    }
  }

  func testSaveRejectsChangedImmutablePayloadAndSelfParent() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let original = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(original)
    let changedRevision = RecipeRevision(
      id: original.revision.id, recipeID: original.recipe.id,
      revisionNumber: original.revision.revisionNumber, title: "Changed"
    )
    let collision = RecipeSaveCommand(
      recipe: original.recipe, revision: changedRevision, savedAt: Date(),
      parentRevisionIDs: [],
      selection: RecipeSelectionCommand(
        kitchenID: kitchen.id, recipeID: original.recipe.id,
        selectedRevisionID: changedRevision.id, selectedAt: Date()
      )
    )
    XCTAssertThrowsError(try repository.save(collision)) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .recipeSaveCommandCollision(commandID: collision.id)
      )
    }

    let selfParent = RecipeSaveCommand(
      recipe: original.recipe, revision: original.revision, savedAt: Date(),
      parentRevisionIDs: [original.revision.id],
      selection: RecipeSelectionCommand(
        kitchenID: kitchen.id, recipeID: original.recipe.id,
        selectedRevisionID: original.revision.id, selectedAt: Date()
      )
    )
    XCTAssertThrowsError(try repository.save(selfParent)) { error in
      XCTAssertEqual(error as? KitchenMemoryPersistenceError, .invalidRecipeSaveCommand)
    }
  }

  func testProjectionGroupsCrossRecipeSaveIdentityCollisions() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let first = makeCommand(kitchenID: kitchen.id, number: 1)
    let second = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(first)
    try repository.save(second)

    let context = ModelContext(container)
    let accepted = try XCTUnwrap(try context.fetch(FetchDescriptor<RecipeSaveRecord>())
      .first { $0.id == first.id.rawValue })
    context.insert(RecipeSaveRecord(
      id: accepted.id, kitchenID: kitchen.id.rawValue, recipeID: second.recipe.id.rawValue,
      revisionID: second.revision.id.rawValue, savedAt: accepted.savedAt,
      ancestryFormatVersion: accepted.ancestryFormatVersion,
      parentRevisionIDsData: accepted.parentRevisionIDsData,
      payloadManifestFormatVersion: accepted.payloadManifestFormatVersion,
      payloadManifestData: accepted.payloadManifestData,
      revisionFormatVersion: accepted.revisionFormatVersion,
      revisionDigest: accepted.revisionDigest
    ))
    try context.save()

    XCTAssertEqual(
      try SwiftDataRecipeRepository(modelContainer: container).recipeAuthority(id: first.recipe.id),
      .recovery(.commandCollision(first.id.rawValue))
    )
  }

  func testProjectionGroupsCrossRecipeSelectionIdentityCollisions() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let first = makeCommand(kitchenID: kitchen.id, number: 1)
    let second = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(first)
    try repository.save(second)

    let context = ModelContext(container)
    let accepted = try XCTUnwrap(try context.fetch(FetchDescriptor<RecipeSelectionRecord>())
      .first { $0.id == first.selection.id.rawValue })
    context.insert(RecipeSelectionRecord(
      id: accepted.id, kitchenID: kitchen.id.rawValue, recipeID: second.recipe.id.rawValue,
      selectedRevisionID: second.revision.id.rawValue, selectedAt: accepted.selectedAt,
      frontierFormatVersion: accepted.frontierFormatVersion,
      observedSelectionIDsData: accepted.observedSelectionIDsData
    ))
    try context.save()

    XCTAssertEqual(
      try SwiftDataRecipeRepository(modelContainer: container).recipeAuthority(id: first.recipe.id),
      .recovery(.commandCollision(first.selection.id.rawValue))
    )
  }

  func testProjectionGroupsCrossRecipeRevisionIdentityCollisions() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let command = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(command)

    let context = ModelContext(container)
    context.insert(makeRevisionRecord(
      id: command.revision.id.rawValue,
      recipeID: Recipe.ID(),
      number: 1
    ))
    try context.save()

    XCTAssertEqual(
      try SwiftDataRecipeRepository(modelContainer: container).recipeAuthority(id: command.recipe.id),
      .recovery(.crossOwnership)
    )
  }

  func testProjectionLoadsCrossRecipeParentReferenceForOwnershipRecovery() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let first = makeCommand(kitchenID: kitchen.id, number: 1)
    let foreign = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(first)
    try repository.save(foreign)

    let context = ModelContext(container)
    let save = try XCTUnwrap(try context.fetch(FetchDescriptor<RecipeSaveRecord>())
      .first { $0.id == first.id.rawValue })
    save.parentRevisionIDsData = RecipeIdentifierSetCodec.encode([
      foreign.revision.id.rawValue,
    ]).data
    try context.save()

    XCTAssertEqual(
      try SwiftDataRecipeRepository(modelContainer: container).recipeAuthority(id: first.recipe.id),
      .recovery(.crossOwnership)
    )
  }

  func testProjectionLoadsCrossRecipeObservedSelectionForOwnershipRecovery() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let first = makeCommand(kitchenID: kitchen.id, number: 1)
    let foreign = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(first)
    try repository.save(foreign)

    let context = ModelContext(container)
    let selection = try XCTUnwrap(try context.fetch(FetchDescriptor<RecipeSelectionRecord>())
      .first { $0.id == first.selection.id.rawValue })
    selection.observedSelectionIDsData = RecipeIdentifierSetCodec.encode([
      foreign.selection.id.rawValue,
    ]).data
    try context.save()

    XCTAssertEqual(
      try SwiftDataRecipeRepository(modelContainer: container).recipeAuthority(id: first.recipe.id),
      .recovery(.crossOwnership)
    )
  }

  func testCompatibilitySaveReportsCorruptAcceptedAuthority() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let command = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(command)
    let context = ModelContext(container)
    let save = try XCTUnwrap(try context.fetch(FetchDescriptor<RecipeSaveRecord>()).first)
    save.parentRevisionIDsData = Data([0])
    try context.save()

    XCTAssertThrowsError(
      try SwiftDataRecipeRepository(modelContainer: container)
        .save(recipe: command.recipe, revision: command.revision)
    ) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .invalidStoredValue(field: "recipe.authority")
      )
    }
  }

  func testCompatibilitySaveReportsCorruptSelectionHeads() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let first = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(first)
    let context = ModelContext(container)
    let selection = try XCTUnwrap(
      try context.fetch(FetchDescriptor<RecipeSelectionRecord>()).first
    )
    selection.observedSelectionIDsData = Data([0])
    try context.save()
    let next = makeCommand(kitchenID: kitchen.id, recipeID: first.recipe.id, number: 2)

    XCTAssertThrowsError(
      try SwiftDataRecipeRepository(modelContainer: container)
        .save(recipe: next.recipe, revision: next.revision)
    ) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .invalidStoredValue(field: "recipe.authority")
      )
    }
  }

  func testCompatibilitySaveSortsAllMaximalSelectionHeads() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let first = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(first)
    let laterID = RecipeSelectionCommand.ID(
      rawValue: UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!
    )
    let earlierID = RecipeSelectionCommand.ID(
      rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    )
    for id in [laterID, earlierID] {
      try repository.select(RecipeSelectionCommand(
        id: id, kitchenID: kitchen.id, recipeID: first.recipe.id,
        selectedRevisionID: first.revision.id, selectedAt: Date(),
        observedSelectionIDs: [first.selection.id]
      ))
    }
    let next = makeCommand(kitchenID: kitchen.id, recipeID: first.recipe.id, number: 2)
    try repository.save(recipe: next.recipe, revision: next.revision)

    let context = ModelContext(container)
    let selection = try XCTUnwrap(try context.fetch(FetchDescriptor<RecipeSelectionRecord>())
      .first { $0.id == next.revision.id.rawValue })
    XCTAssertEqual(
      try RecipeIdentifierSetCodec.decode(
        formatVersion: selection.frontierFormatVersion,
        data: selection.observedSelectionIDsData
      ),
      [earlierID.rawValue, laterID.rawValue]
    )
  }

  func testLegacyRowsReportMissingCrossOwnedAndTieBrokenRevisionEvidence() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let context = ModelContext(container)

    let missingID = Recipe.ID()
    context.insert(RecipeRecord(
      id: missingID.rawValue, kitchenID: kitchen.id.rawValue,
      currentRevisionID: UUID()
    ))
    let crossOwnedID = Recipe.ID()
    let crossRevision = makeRevisionRecord(recipeID: Recipe.ID(), number: 1)
    context.insert(RecipeRecord(
      id: crossOwnedID.rawValue, kitchenID: kitchen.id.rawValue,
      currentRevisionID: crossRevision.id
    ))
    context.insert(crossRevision)
    let tiedID = Recipe.ID()
    let earlier = makeRevisionRecord(
      id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
      recipeID: tiedID,
      number: 1
    )
    let later = makeRevisionRecord(
      id: UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!,
      recipeID: tiedID,
      number: 1
    )
    context.insert(RecipeRecord(
      id: tiedID.rawValue, kitchenID: kitchen.id.rawValue,
      currentRevisionID: earlier.id
    ))
    context.insert(earlier)
    context.insert(later)
    try context.save()

    let reader = SwiftDataRecipeRepository(modelContainer: container)
    XCTAssertThrowsError(try reader.recipe(id: missingID)) { error in
      XCTAssertEqual(error as? KitchenMemoryPersistenceError, .missingCurrentRevision)
    }
    XCTAssertThrowsError(try reader.recipe(id: crossOwnedID)) { error in
      guard case .inconsistentStoredRecipeIdentity = error as? KitchenMemoryPersistenceError
      else { return XCTFail("Expected ownership failure") }
    }
    XCTAssertEqual(try reader.recipe(id: tiedID)?.revision.id.rawValue, later.id)
  }

  func testReplacementRemovesRetainedPruneEvidence() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let command = makeCommand(kitchenID: kitchen.id, number: 1)
    try repository.save(command)
    let frontier = RecipeAuthorityFrontierCodec.encode(RecipeAuthorityFrontier(
      revisionHeads: [], selectionHeads: [], deletionIDs: [], restorationIDs: []
    ))
    let context = ModelContext(container)
    context.insert(RecipePruneRecord(
      id: UUID(), kitchenID: kitchen.id.rawValue, recipeID: command.recipe.id.rawValue,
      prunedAt: Date(), antiResurrectionUntil: Date().addingTimeInterval(1),
      frontierFormatVersion: frontier.formatVersion, frontierData: frontier.data,
      frontierDigest: frontier.digest
    ))
    try context.save()

    try repository.replaceRecipes(in: kitchen.id, with: [])

    XCTAssertEqual(
      try ModelContext(container).fetchCount(FetchDescriptor<RecipePruneRecord>()),
      0
    )
  }

  private func makeCommand(
    kitchenID: Kitchen.ID,
    recipeID: Recipe.ID = Recipe.ID(),
    number: Int,
    parents: [RecipeRevision.ID] = [],
    observed: [RecipeSelectionCommand.ID] = []
  ) -> RecipeSaveCommand {
    let revision = RecipeRevision(
      recipeID: recipeID, revisionNumber: number, title: "Revision \(number)"
    )
    let recipe = Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: revision.id)
    return RecipeSaveCommand(
      recipe: recipe, revision: revision, savedAt: Date(), parentRevisionIDs: parents,
      selection: RecipeSelectionCommand(
        kitchenID: kitchenID, recipeID: recipeID, selectedRevisionID: revision.id,
        selectedAt: Date(), observedSelectionIDs: observed
      )
    )
  }

  private func makeRevisionRecord(
    id: UUID = UUID(),
    recipeID: Recipe.ID,
    number: Int
  ) -> RecipeRevisionRecord {
    let empty = Data("[]".utf8)
    return RecipeRevisionRecord(
      id: id, recipeID: recipeID.rawValue, revisionNumber: number, title: "Legacy",
      summary: nil, authorName: nil, contentLanguage: nil, sourceData: nil,
      yieldData: nil, prepSeconds: nil, cookSeconds: nil, totalSeconds: nil,
      cuisinesData: empty, categoriesData: empty, keywordsData: empty
    )
  }
}
