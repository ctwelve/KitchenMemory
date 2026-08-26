// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemory
import KitchenMemoryDomain
import KitchenMemoryPersistence
import SwiftData
import XCTest

// Repository tests keep related round-trip scenarios together and use complete
// domain fixtures whose setup is intentionally visible beside each assertion.
// swiftlint:disable file_length type_body_length

@MainActor
final class SwiftDataRecipeRepositoryTests: XCTestCase {
  func testImportedSourceCaptureRoundTripsWithoutChangingTheV1Schema() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let recipeID = Recipe.ID()
    let capture = RecipeSourceCapture(
      kind: .schemaOrgJSONLD,
      sourceURL: URL(string: "https://example.com/soup")!,
      capturedAt: Date(timeIntervalSince1970: 1_800_000_000),
      mediaType: "application/ld+json",
      payload: Data("{\"@type\":\"Recipe\"}".utf8),
      blockIndex: 0,
      objectIndex: 1
    )
    let revision = RecipeRevision(
      recipeID: recipeID,
      revisionNumber: 1,
      title: "Soup",
      source: RecipeSource(
        kind: .webpage,
        canonicalURL: URL(string: "https://example.com/soup")
      ),
      sourceCapture: capture
    )
    let recipe = Recipe(
      id: recipeID,
      kitchenID: kitchen.id,
      currentRevisionID: revision.id
    )

    try repository.save(recipe: recipe, revision: revision)

    XCTAssertEqual(try repository.recipe(id: recipeID)?.revision.sourceCapture, capture)
    XCTAssertEqual(try repository.recipe(id: recipeID)?.revision.source, revision.source)
  }
  func testContainerUsesTheCurrentVersionedSchemaAndMigrationPlan() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)

    XCTAssertEqual(container.schema.version, Schema.Version(2, 0, 0))
    XCTAssertNotNil(container.migrationPlan)
  }

  func testTunaNoodleHotdishRoundTripsThroughSwiftData() throws {
    let kitchen = Kitchen(name: "Test Kitchen")
    let manifest = try SampleRecipeCatalog.loadManifest()
    let family = try XCTUnwrap(manifest.recipes.first)
    let reference = try XCTUnwrap(family.variant(preferredLanguages: ["en"]))
    let document = try SampleRecipeCatalog.loadRecipe(reference)
    let sample = try document.materialize(in: kitchen.id)
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )

    try repository.save(kitchen)
    try repository.save(recipe: sample.recipe, revision: sample.revision)

    XCTAssertEqual(try repository.kitchen(id: kitchen.id), kitchen)
    let stored = try XCTUnwrap(repository.recipe(id: sample.recipe.id))
    XCTAssertEqual(stored.recipe, sample.recipe)
    XCTAssertEqual(stored.revision, sample.revision)
  }

  func testSavingTheSameRecipeUpdatesInsteadOfDuplicatingItsChildren() throws {
    let kitchen = Kitchen(name: "Test Kitchen")
    let manifest = try SampleRecipeCatalog.loadManifest()
    let family = try XCTUnwrap(manifest.recipes.first)
    let reference = try XCTUnwrap(family.variant(preferredLanguages: ["en"]))
    let document = try SampleRecipeCatalog.loadRecipe(reference)
    let sample = try document.materialize(in: kitchen.id)
    var editedRevision = sample.revision
    editedRevision.title = "Leftover Tuna Noodle Hotdish"
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )

    try repository.save(kitchen)
    try repository.save(recipe: sample.recipe, revision: sample.revision)
    XCTAssertEqual(
      try repository.recipe(id: sample.recipe.id),
      StoredRecipe(recipe: sample.recipe, revision: sample.revision)
    )
    try repository.save(recipe: sample.recipe, revision: editedRevision)

    let stored = try XCTUnwrap(repository.recipe(id: sample.recipe.id))
    XCTAssertEqual(stored.revision.title, "Leftover Tuna Noodle Hotdish")
    XCTAssertEqual(stored.revision.media, sample.revision.media)
    XCTAssertEqual(stored.revision.ingredientSections, sample.revision.ingredientSections)
    XCTAssertEqual(stored.revision.instructionSections, sample.revision.instructionSections)
    XCTAssertEqual(try repository.recipes(in: kitchen.id), [stored])
  }

  func testSavingANewRevisionMakesItCurrent() throws {
    let kitchen = Kitchen(name: "Test Kitchen")
    let recipeID = Recipe.ID()
    let firstRevision = RecipeRevision(
      recipeID: recipeID,
      revisionNumber: 1,
      title: "First Draft"
    )
    let secondRevision = RecipeRevision(
      recipeID: recipeID,
      revisionNumber: 2,
      title: "Family Draft"
    )
    var recipe = Recipe(
      id: recipeID,
      kitchenID: kitchen.id,
      currentRevisionID: firstRevision.id
    )
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )

    try repository.save(kitchen)
    try repository.save(recipe: recipe, revision: firstRevision)
    XCTAssertEqual(
      try repository.recipe(id: recipeID),
      StoredRecipe(recipe: recipe, revision: firstRevision)
    )
    recipe.currentRevisionID = secondRevision.id
    try repository.save(recipe: recipe, revision: secondRevision)

    let stored = try XCTUnwrap(repository.recipe(id: recipeID))
    XCTAssertEqual(stored.recipe.currentRevisionID, secondRevision.id)
    XCTAssertEqual(stored.revision, secondRevision)
    XCTAssertEqual(
      try repository.revisions(for: recipeID),
      [secondRevision, firstRevision]
    )
  }

  func testLoadsLegacyRevisionsWithoutMultiplyingReusedChildIdentifiers() throws {
    let kitchen = Kitchen(name: "Test Kitchen")
    let recipeID = Recipe.ID()
    let ingredient = RecipeIngredient(originalText: "4 tomatoes", presentationMode: .original)
    let step = InstructionStep(text: "Simmer.")
    let ingredientSection = IngredientSection(ingredients: [ingredient])
    let instructionSection = InstructionSection(steps: [step])
    let firstRevision = RecipeRevision(
      recipeID: recipeID,
      revisionNumber: 1,
      title: "Tomato Soup",
      ingredientSections: [ingredientSection],
      instructionSections: [instructionSection]
    )
    let secondRevision = RecipeRevision(
      recipeID: recipeID,
      revisionNumber: 2,
      title: "Tomato Soup",
      authorName: "Aunt Jo",
      ingredientSections: [ingredientSection],
      instructionSections: [instructionSection]
    )
    var recipe = Recipe(
      id: recipeID,
      kitchenID: kitchen.id,
      currentRevisionID: firstRevision.id
    )
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )

    try repository.save(kitchen)
    try repository.save(recipe: recipe, revision: firstRevision)
    recipe.currentRevisionID = secondRevision.id
    try repository.save(recipe: recipe, revision: secondRevision)

    let reloaded = try XCTUnwrap(repository.recipe(id: recipeID))
    XCTAssertEqual(reloaded.revision.ingredientSections.first?.ingredients, [ingredient])
    XCTAssertEqual(reloaded.revision.instructionSections.first?.steps, [step])
  }

  func testDiskStoreSurvivesANewContainer() throws {
    let storeURL = FileManager.default.temporaryDirectory
      .appending(path: "KitchenMemoryPersistenceTests")
      .appending(path: UUID().uuidString)
      .appending(path: "KitchenMemory.store")
    defer {
      try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent())
    }
    try FileManager.default.createDirectory(
      at: storeURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )

    let kitchen = Kitchen(name: "Persistent Kitchen")
    let recipeID = Recipe.ID()
    let revision = RecipeRevision(recipeID: recipeID, revisionNumber: 1, title: "Keepsake Soup")
    let recipe = Recipe(
      id: recipeID,
      kitchenID: kitchen.id,
      currentRevisionID: revision.id
    )

    let firstRepository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(storeURL: storeURL)
    )
    try firstRepository.save(kitchen)
    try firstRepository.save(recipe: recipe, revision: revision)

    let reopenedRepository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(storeURL: storeURL)
    )
    XCTAssertEqual(try reopenedRepository.kitchen(id: kitchen.id), kitchen)
    XCTAssertEqual(try reopenedRepository.recipe(id: recipeID)?.revision, revision)
  }

  func testRecipeListIsKitchenScopedAndSortedByTitle() throws {
    let kitchen = Kitchen(name: "Test Kitchen")
    let otherKitchen = Kitchen(name: "Other Kitchen")
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    try repository.save(kitchen)
    try repository.save(otherKitchen)

    for (title, owner) in [
      ("Zucchini Bread", kitchen),
      ("Apple Crisp", kitchen),
      ("Mushroom Soup", kitchen),
      ("Banana Bread", otherKitchen),
    ] {
      let recipeID = Recipe.ID()
      let revision = RecipeRevision(recipeID: recipeID, revisionNumber: 1, title: title)
      let recipe = Recipe(
        id: recipeID,
        kitchenID: owner.id,
        currentRevisionID: revision.id
      )
      try repository.save(recipe: recipe, revision: revision)
    }

    XCTAssertEqual(
      try repository.recipes(in: kitchen.id).map(\.revision.title),
      ["Apple Crisp", "Mushroom Soup", "Zucchini Bread"]
    )
  }

  // swiftlint:disable:next function_body_length
  func testReplacingKitchenRecipesDeletesHistoryWithoutAffectingOtherKitchens() throws {
    let kitchen = Kitchen(name: "Home")
    let otherKitchen = Kitchen(name: "Cabin")
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    try repository.save(kitchen)
    try repository.save(otherKitchen)

    let oldRecipeID = Recipe.ID()
    let firstRevision = RecipeRevision(
      recipeID: oldRecipeID,
      revisionNumber: 1,
      title: "First Draft"
    )
    let secondRevision = RecipeRevision(
      recipeID: oldRecipeID,
      revisionNumber: 2,
      title: "Family Draft"
    )
    try repository.save(
      recipe: Recipe(
        id: oldRecipeID,
        kitchenID: kitchen.id,
        currentRevisionID: firstRevision.id
      ),
      revision: firstRevision
    )
    let currentOldRecipe = Recipe(
      id: oldRecipeID,
      kitchenID: kitchen.id,
      currentRevisionID: secondRevision.id
    )
    try repository.save(recipe: currentOldRecipe, revision: secondRevision)
    XCTAssertEqual(
      try repository.recipe(id: oldRecipeID),
      StoredRecipe(recipe: currentOldRecipe, revision: secondRevision)
    )

    let otherRecipeID = Recipe.ID()
    let otherRevision = RecipeRevision(
      recipeID: otherRecipeID,
      revisionNumber: 1,
      title: "Cabin Chili"
    )
    let otherRecipe = Recipe(
      id: otherRecipeID,
      kitchenID: otherKitchen.id,
      currentRevisionID: otherRevision.id
    )
    try repository.save(recipe: otherRecipe, revision: otherRevision)

    let replacementID = Recipe.ID()
    let replacementRevision = RecipeRevision(
      recipeID: replacementID,
      revisionNumber: 1,
      title: "Sample Soup"
    )
    let replacement = StoredRecipe(
      recipe: Recipe(
        id: replacementID,
        kitchenID: kitchen.id,
        currentRevisionID: replacementRevision.id
      ),
      revision: replacementRevision
    )

    try repository.replaceRecipes(in: kitchen.id, with: [replacement])

    XCTAssertEqual(try repository.recipes(in: kitchen.id), [replacement])
    XCTAssertNil(try repository.recipe(id: oldRecipeID))
    XCTAssertEqual(try repository.revisions(for: oldRecipeID), [])
    XCTAssertEqual(try repository.recipe(id: otherRecipeID), StoredRecipe(
      recipe: otherRecipe,
      revision: otherRevision
    ))
  }

  func testKitchenListLoadsAllSavedKitchensInNameOrder() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let cabin = Kitchen(name: "Cabin")
    let home = Kitchen(name: "Home")

    try repository.save(home)
    try repository.save(cabin)

    XCTAssertEqual(try repository.kitchens(), [cabin, home])
  }

  // swiftlint:disable:next function_body_length
  func testOrderedRecipeContentRoundTripsInUseOrder() throws {
    let kitchen = Kitchen(name: "Test Kitchen")
    let recipeID = Recipe.ID()
    let revision = RecipeRevision(
      recipeID: recipeID,
      revisionNumber: 1,
      title: "Order Test",
      media: [
        RecipeMedia(role: .hero, assetName: "First"),
        RecipeMedia(role: .gallery, assetName: "Second"),
      ],
      equipment: [
        EquipmentItem(originalText: "First bowl", name: "bowl"),
        EquipmentItem(originalText: "Second whisk", name: "whisk"),
      ],
      ingredientSections: [
        IngredientSection(
          title: "First section",
          ingredients: [
            RecipeIngredient(originalText: "First ingredient", presentationMode: .original),
            RecipeIngredient(originalText: "Second ingredient", presentationMode: .original),
          ]
        ),
        IngredientSection(
          title: "Second section",
          ingredients: [
            RecipeIngredient(originalText: "Third ingredient", presentationMode: .original)
          ]
        ),
      ],
      instructionSections: [
        InstructionSection(
          title: "First stage",
          steps: [
            InstructionStep(text: "First step"),
            InstructionStep(text: "Second step"),
          ]
        ),
        InstructionSection(
          title: "Second stage",
          steps: [InstructionStep(text: "Third step")]
        ),
      ]
    )
    let recipe = Recipe(
      id: recipeID,
      kitchenID: kitchen.id,
      currentRevisionID: revision.id
    )
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )

    try repository.save(kitchen)
    try repository.save(recipe: recipe, revision: revision)

    let stored = try XCTUnwrap(repository.recipe(id: recipeID)).revision
    XCTAssertEqual(stored.media.map(\.assetName), ["First", "Second"])
    XCTAssertEqual(stored.equipment.map(\.originalText), ["First bowl", "Second whisk"])
    XCTAssertEqual(stored.ingredientSections.map(\.title), ["First section", "Second section"])
    XCTAssertEqual(
      stored.ingredientSections.flatMap(\.ingredients).map(\.originalText),
      ["First ingredient", "Second ingredient", "Third ingredient"]
    )
    XCTAssertEqual(stored.instructionSections.map(\.title), ["First stage", "Second stage"])
    XCTAssertEqual(
      stored.instructionSections.flatMap(\.steps).map(\.text),
      ["First step", "Second step", "Third step"]
    )
  }

  func testRejectsMismatchedRecipeAndRevision() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let revision = RecipeRevision(
      recipeID: Recipe.ID(),
      revisionNumber: 1,
      title: "Mismatch"
    )
    let recipe = Recipe(
      kitchenID: Kitchen.ID(),
      currentRevisionID: revision.id
    )

    XCTAssertThrowsError(try repository.save(recipe: recipe, revision: revision)) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .inconsistentRecipeIdentity
      )
    }
  }

  func testRejectsRecipeWhoseKitchenHasNotBeenSaved() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let recipeID = Recipe.ID()
    let revision = RecipeRevision(
      recipeID: recipeID,
      revisionNumber: 1,
      title: "Orphan"
    )
    let recipe = Recipe(
      id: recipeID,
      kitchenID: Kitchen.ID(),
      currentRevisionID: revision.id
    )

    XCTAssertThrowsError(try repository.save(recipe: recipe, revision: revision)) { error in
      XCTAssertEqual(error as? KitchenMemoryPersistenceError, .missingKitchen)
    }
  }
}

// swiftlint:enable file_length type_body_length
