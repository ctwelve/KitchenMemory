// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import SwiftData
import XCTest

@MainActor
final class SamplePackLibraryTests: XCTestCase {
  func testResetDoesNotRestoreDisabledSamplesAfterManualDeletion() throws {
    let kitchen = Kitchen(name: "Samples")
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    try repository.save(kitchen)
    let library = RecipeLibrary(kitchenID: kitchen.id, repository: repository,
      samples: LibrarySampleProvider(), importer: RecipeImportService(),
      resetRepository: SwiftDataKitchenResetRepository(modelContainer: container),
      samplePackRepository: SwiftDataSamplePackRepository(modelContainer: container))
    try library.installSamples()
    // Edited samples survive disabling the pack and are then deleted manually.
    for recipe in try library.load().recipes {
      _ = try library.revise(recipeID: recipe.id, from: RecipeDraft(title: "Edited sample"))
    }
    try library.setSamplePack(library.prepareSamplePack(enabled: false))
    for recipe in try library.load().recipes {
      try library.delete(library.prepareDeletion(of: recipe.id))
    }
    XCTAssertEqual(try library.samplePackStatus()?.isEnabled, false)
    XCTAssertTrue(try library.load().recipes.isEmpty)
    try library.reset()
    XCTAssertTrue(try library.load().recipes.isEmpty,
      "Reset must not reinstall a disabled sample pack")
    XCTAssertEqual(try library.samplePackStatus()?.isEnabled, false)
  }

  func testExplicitSampleRequestsFreezeRemovalAndValidateTheirKitchen() throws {
    let kitchen = Kitchen(name: "Samples")
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    try repository.save(kitchen)
    let samples = LibrarySampleProvider()
    let pack = SwiftDataSamplePackRepository(modelContainer: container)
    let library = RecipeLibrary(kitchenID: kitchen.id, repository: repository,
      samples: samples, importer: RecipeImportService(), samplePackRepository: pack,
      sampleFolderName: "Examples", sampleTagName: "examples")
    XCTAssertEqual(try library.samplePackStatus()?.installed, 0)
    let install = try library.prepareSamplePack(enabled: true)
    XCTAssertTrue(install.removalIDs.isEmpty)
    try library.setSamplePack(install)
    try library.installSamples()
    XCTAssertEqual(try library.samplePackStatus()?.installed, 2)
    let removal = try library.prepareSamplePack(enabled: false)
    XCTAssertEqual(removal.removalIDs, Set(samples.recipes(in: kitchen.id).map(\.id)))
    try library.setSamplePack(removal)
    XCTAssertEqual(try library.samplePackStatus()?.deleted, 2)
    let foreign = RecipeLibrary(kitchenID: Kitchen.ID(), repository: repository,
      samples: samples, importer: RecipeImportService(), samplePackRepository: pack)
    XCTAssertThrowsError(try foreign.setSamplePack(install))
    let unsupported = RecipeLibrary(kitchenID: kitchen.id, repository: repository,
      samples: samples, importer: RecipeImportService())
    XCTAssertNil(try unsupported.samplePackStatus())
    XCTAssertThrowsError(try unsupported.prepareSamplePack(enabled: true))
    XCTAssertThrowsError(try unsupported.setSamplePack(install))
  }

}

@MainActor
private struct LibrarySampleProvider: SampleRecipeProviding {
  private let recipeIDs = [Recipe.ID(), Recipe.ID()]
  private let revisionIDs = [RecipeRevision.ID(), RecipeRevision.ID()]
  func recipes(in kitchenID: Kitchen.ID) -> [StoredRecipe] {
    zip(recipeIDs, revisionIDs).map { recipeID, revisionID in
      StoredRecipe(recipe: Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: revisionID),
        revision: RecipeRevision(id: revisionID, recipeID: recipeID, revisionNumber: 1, title: "Synthetic sample"))
    }
  }
}
