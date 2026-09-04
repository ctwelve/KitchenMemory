// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import XCTest

@MainActor
final class RecipeLibraryTests: XCTestCase {
  func testPreparedSaveCanBeRetainedAndReplayedWithoutReauthoringItsContent() throws {
    let kitchen = Kitchen(name: "Home")
    let repository = InMemoryRecipeRepository()
    let library = makeLibrary(kitchen: kitchen, repository: repository)
    let command = try library.prepareSave(
      from: RecipeDraft(title: "Soup"), original: nil, observedSelectionIDs: []
    )
    let retained = try JSONDecoder().decode(
      RecipeSaveCommand.self, from: JSONEncoder().encode(command)
    )
    XCTAssertEqual(retained, command)
    XCTAssertEqual(RecipeAuthoringPhase.importCandidate.acceptingImport(), .editing)
    XCTAssertEqual(RecipeAuthoringPhase.editing.acceptingImport(), .editing)
    let frozenPhase = RecipeAuthoringPhase.saving(command)
    XCTAssertEqual(frozenPhase.acceptingImport(), frozenPhase)
    XCTAssertEqual(try JSONDecoder().decode(RecipeAuthoringPhase.self,
      from: JSONEncoder().encode(frozenPhase)), frozenPhase)
    try library.save(retained)
    XCTAssertEqual(try library.load().recipes.first?.revision.title, "Soup")
    XCTAssertTrue(try library.editingSelectionHeads(for: command.recipe.id).isEmpty)
    let original = StoredRecipe(recipe: command.recipe, revision: command.revision)
    let revised = try library.prepareSave(
      from: RecipeDraft(title: "Revised soup"), original: original,
      observedSelectionIDs: [command.selection.id]
    )
    XCTAssertEqual(revised.parentRevisionIDs, [command.revision.id])
    XCTAssertEqual(revised.selection.observedSelectionIDs, [command.selection.id])
    XCTAssertEqual(revised.revision.revisionNumber, 2)
    try library.save(revised)
    XCTAssertEqual(try repository.revisions(for: command.recipe.id).count, 2)
    let foreign = makeLibrary(kitchen: Kitchen(name: "Other"), repository: repository)
    XCTAssertThrowsError(try foreign.save(command))
    XCTAssertThrowsError(try library.prepareSave(
      from: RecipeDraft(), original: nil, observedSelectionIDs: []
    ))
  }

  func testLoadsKitchenContentAndDerivesSamplePresenceTogether() throws {
    let kitchen = Kitchen(name: "Home")
    let otherKitchen = Kitchen(name: "Cabin")
    let repository = InMemoryRecipeRepository()
    let samples = FixedSampleProvider()
    let sampleRecipes = samples.recipes(in: kitchen.id)
    let userRecipe = makeStoredRecipe(title: "Apple Crisp", kitchenID: kitchen.id)
    repository.storedRecipes = [
      userRecipe,
      sampleRecipes[0],
      makeStoredRecipe(title: "Chili", kitchenID: otherKitchen.id),
    ]
    let library = makeLibrary(kitchen: kitchen, repository: repository, samples: samples)

    let contents = try library.load()

    XCTAssertEqual(contents.recipes, [userRecipe, sampleRecipes[0]])
    XCTAssertEqual(contents.samplePresence, .partial)
  }

  func testDocumentInterpretationAndCandidateIdentityStayBehindLibraryInterface() throws {
    let library = makeLibrary(kitchen: Kitchen(name: "Home"), repository: InMemoryRecipeRepository())
    let data = Data(#"{"@type":"Recipe","name":"Toast"}"#.utf8)
    let options = try library.importDocument(data, sourceURL: URL(fileURLWithPath: "/tmp/toast.json"),
                                             format: .jsonLD)
    let candidate = try XCTUnwrap(options.first)
    XCTAssertEqual(candidate.draft.title, "Toast")
    let restored = try JSONDecoder().decode(RecipeImportOption.self, from: JSONEncoder().encode(candidate))
    XCTAssertEqual(try candidate.retentionIdentifier(), try restored.retentionIdentifier())
    let different = RecipeImportOption(id: candidate.id, draft: RecipeDraft(title: "Different"), concerns: [])
    XCTAssertNotEqual(try candidate.retentionIdentifier(), try different.retentionIdentifier())
    XCTAssertTrue(try library.load().recipes.isEmpty)
  }

  func testCreatesAndRevisesThroughOneLibraryInterface() throws {
    let kitchen = Kitchen(name: "Home")
    let repository = InMemoryRecipeRepository()
    let library = makeLibrary(kitchen: kitchen, repository: repository)

    let created = try library.create(from: RecipeDraft(title: "  Tomato Soup  "))
    let revised = try library.revise(
      recipeID: created.id,
      from: RecipeDraft(title: "Roasted Tomato Soup")
    )

    XCTAssertEqual(created.revision.title, "Tomato Soup")
    XCTAssertEqual(revised.revision.revisionNumber, 2)
    XCTAssertEqual(try library.load().recipes, [revised])
    XCTAssertEqual(
      try repository.revisions(for: created.id).map(\.title),
      ["Roasted Tomato Soup", "Tomato Soup"]
    )
  }

  func testInstallAndResetOwnTheirLibraryWideConsequences() throws {
    let kitchen = Kitchen(name: "Home")
    let repository = InMemoryRecipeRepository()
    let samples = FixedSampleProvider()
    let userRecipe = makeStoredRecipe(title: "Keep Me", kitchenID: kitchen.id)
    repository.storedRecipes = [userRecipe]
    let library = makeLibrary(kitchen: kitchen, repository: repository, samples: samples)

    try library.installSamples()
    try library.installSamples()
    let installed = try library.load()
    try library.reset()
    let reset = try library.load()

    XCTAssertEqual(installed.recipes.count, 3)
    XCTAssertTrue(installed.recipes.contains(userRecipe))
    XCTAssertEqual(installed.samplePresence, .complete)
    XCTAssertEqual(reset.recipes, samples.recipes(in: kitchen.id))
    XCTAssertEqual(reset.samplePresence, .complete)
  }

  func testImportsThroughTheSameLibraryInterface() async throws {
    let kitchen = Kitchen(name: "Home")
    let expected = RecipeImportOption(
      id: .init(blockIndex: 1, objectIndex: 2),
      draft: RecipeDraft(title: "Imported Soup"),
      concerns: []
    )
    let library = makeLibrary(
      kitchen: kitchen,
      repository: InMemoryRecipeRepository(),
      importer: StubRecipeImporter(options: [expected])
    )

    let options = try await library.importRecipe(
      from: XCTUnwrap(URL(string: "https://example.com/soup"))
    )

    XCTAssertEqual(options, [expected])
  }

  func testUnavailableSamplesDoNotMakeDurableRecipesUnreadable() throws {
    let kitchen = Kitchen(name: "Home")
    let repository = InMemoryRecipeRepository()
    let stored = makeStoredRecipe(title: "Apple Crisp", kitchenID: kitchen.id)
    repository.storedRecipes = [stored]
    let library = makeLibrary(
      kitchen: kitchen,
      repository: repository,
      samples: FailingSampleProvider()
    )

    let contents = try library.load()

    XCTAssertEqual(contents.recipes, [stored])
    XCTAssertEqual(contents.samplePresence, .unavailable)
  }

  private func makeLibrary(
    kitchen: Kitchen,
    repository: InMemoryRecipeRepository,
    samples: any SampleRecipeProviding = FixedSampleProvider(),
    importer: any RecipeImportServing = StubRecipeImporter()
  ) -> RecipeLibrary {
    RecipeLibrary(
      kitchenID: kitchen.id,
      repository: repository,
      samples: samples,
      importer: importer
    )
  }

  private func makeStoredRecipe(title: String, kitchenID: Kitchen.ID) -> StoredRecipe {
    let recipeID = Recipe.ID()
    let revision = RecipeRevision(recipeID: recipeID, revisionNumber: 1, title: title)
    return StoredRecipe(
      recipe: Recipe(
        id: recipeID,
        kitchenID: kitchenID,
        currentRevisionID: revision.id
      ),
      revision: revision
    )
  }
}

private struct StubRecipeImporter: RecipeImportServing {
  var options: [RecipeImportOption] = []

  func importRecipe(from url: URL) async throws -> [RecipeImportOption] {
    options
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

@MainActor
private struct FailingSampleProvider: SampleRecipeProviding {
  struct Failure: Error {}

  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] {
    throw Failure()
  }
}

@MainActor
private final class InMemoryRecipeRepository: RecipeRepository {
  var storedRecipes: [StoredRecipe] = []
  private var storedKitchens: [Kitchen] = []
  private var revisionsByRecipeID: [Recipe.ID: [RecipeRevision]] = [:]

  func save(_ kitchen: Kitchen) throws {
    storedKitchens.removeAll { $0.id == kitchen.id }
    storedKitchens.append(kitchen)
  }

  func create(_ kitchen: Kitchen, with recipes: [StoredRecipe]) throws {
    try save(kitchen)
    try replaceRecipes(in: kitchen.id, with: recipes)
  }

  func save(recipe: Recipe, revision: RecipeRevision) throws {
    storedRecipes.removeAll { $0.id == recipe.id }
    storedRecipes.append(StoredRecipe(recipe: recipe, revision: revision))
    var revisions = revisionsByRecipeID[recipe.id, default: []]
    revisions.removeAll { $0.id == revision.id }
    revisions.append(revision)
    revisions.sort { $0.revisionNumber > $1.revisionNumber }
    revisionsByRecipeID[recipe.id] = revisions
  }

  func kitchens() throws -> [Kitchen] {
    storedKitchens
  }

  func kitchen(id: Kitchen.ID) throws -> Kitchen? {
    storedKitchens.first { $0.id == id }
  }

  func convergeKitchens(into kitchen: Kitchen, ownedBy ownerID: KitchenOwner.ID) throws {
    storedKitchens = [kitchen]
    storedRecipes = storedRecipes.map { stored in
      StoredRecipe(
        recipe: Recipe(
          id: stored.id,
          kitchenID: kitchen.id,
          currentRevisionID: stored.revision.id
        ),
        revision: stored.revision
      )
    }
  }

  func recipe(id: Recipe.ID) throws -> StoredRecipe? {
    storedRecipes.first { $0.id == id }
  }

  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] {
    storedRecipes.filter { $0.recipe.kitchenID == kitchenID }
  }

  func addRecipes(_ recipes: [StoredRecipe], to kitchenID: Kitchen.ID) throws {
    let existingIDs = Set(storedRecipes.map(\.id))
    storedRecipes.append(contentsOf: recipes.filter { !existingIDs.contains($0.id) })
    for stored in recipes where !existingIDs.contains(stored.id) {
      revisionsByRecipeID[stored.id] = [stored.revision]
    }
  }

  func revisions(for recipeID: Recipe.ID) throws -> [RecipeRevision] {
    revisionsByRecipeID[recipeID, default: []]
  }

  func replaceRecipes(in kitchenID: Kitchen.ID, with recipes: [StoredRecipe]) throws {
    let removedIDs = Set(storedRecipes.filter { $0.recipe.kitchenID == kitchenID }.map(\.id))
    storedRecipes.removeAll { $0.recipe.kitchenID == kitchenID }
    for removedID in removedIDs {
      revisionsByRecipeID[removedID] = nil
    }
    storedRecipes.append(contentsOf: recipes)
    for stored in recipes {
      revisionsByRecipeID[stored.id] = [stored.revision]
    }
  }
}
