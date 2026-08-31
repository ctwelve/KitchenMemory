// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import SwiftData
import XCTest

@MainActor
final class KitchenServicesFailureTests: XCTestCase {
  func testBootstrapUsesOneDeterministicPersonalKitchenIdentity() throws {
    let repository = try makeRepository()
    let service = KitchenBootstrapService(repository: repository)

    let kitchen = try service.prepareInitialKitchen()

    XCTAssertEqual(kitchen.id, KitchenBootstrapService.personalKitchenID)
    XCTAssertEqual(try service.prepareInitialKitchen(), kitchen)
  }

  func testBootstrapReportsWhetherItCreatedOrFoundThePersonalKitchen() throws {
    let repository = try makeRepository()
    let service = KitchenBootstrapService(repository: repository)

    let firstPreparation = try service.prepareInitialKitchenWithStatus()
    let secondPreparation = try service.prepareInitialKitchenWithStatus()

    XCTAssertTrue(firstPreparation.wasCreated)
    XCTAssertFalse(secondPreparation.wasCreated)
    XCTAssertEqual(firstPreparation.kitchen, secondPreparation.kitchen)
  }

  func testOwnedBootstrapUsesRequestedNameForAnEmptyStore() throws {
    let repository = try makeRepository()
    let ownerID = KitchenOwner.ID(rawValue: "cloudkit:production:current-user")

    let prepared = try KitchenBootstrapService(repository: repository)
      .prepareInitialKitchenWithStatus(named: "My Kitchen", ownerID: ownerID)

    XCTAssertTrue(prepared.wasCreated)
    XCTAssertEqual(prepared.kitchen.name, "My Kitchen")
    XCTAssertEqual(prepared.kitchen.ownerID, ownerID)
  }

  func testBootstrapConvergesLegacyKitchensOnlyForTheCurrentOwner() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let context = ModelContext(container)
    let legacyKitchenID = Kitchen.ID()
    let recipeID = Recipe.ID()
    let revisionID = RecipeRevision.ID()
    context.insert(KitchenRecord(id: legacyKitchenID.rawValue, name: "Legacy Kitchen"))
    context.insert(KitchenRecord(
      id: KitchenBootstrapService.personalKitchenID.rawValue,
      name: "Home Kitchen"
    ))
    context.insert(RecipeRecord(
      id: recipeID.rawValue,
      kitchenID: legacyKitchenID.rawValue,
      currentRevisionID: revisionID.rawValue
    ))
    context.insert(RecipeRecord(
      id: recipeID.rawValue,
      kitchenID: KitchenBootstrapService.personalKitchenID.rawValue,
      currentRevisionID: revisionID.rawValue
    ))
    context.insert(makeRevisionRecord(id: revisionID, recipeID: recipeID))
    try context.save()
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let ownerID = KitchenOwner.ID(rawValue: "cloudkit:production:current-user")

    let prepared = try KitchenBootstrapService(repository: repository)
      .prepareInitialKitchenWithStatus(ownerID: ownerID)

    XCTAssertEqual(prepared.kitchen.id, KitchenBootstrapService.personalKitchenID)
    XCTAssertEqual(prepared.kitchen.ownerID, ownerID)
    XCTAssertEqual(try repository.kitchens(), [prepared.kitchen])
    XCTAssertEqual(try repository.recipes(in: prepared.kitchen.id).map(\.id), [recipeID])
  }

  func testBootstrapRefusesToConvergeKitchenOwnedBySomeoneElse() throws {
    let repository = try makeRepository()
    let firstOwner = KitchenOwner.ID(rawValue: "cloudkit:production:first-user")
    let otherOwner = KitchenOwner.ID(rawValue: "cloudkit:production:other-user")
    let foreignKitchen = Kitchen(ownerID: otherOwner, name: "Someone Else's Kitchen")
    try repository.save(foreignKitchen)

    XCTAssertThrowsError(
      try KitchenBootstrapService(repository: repository)
        .prepareInitialKitchenWithStatus(ownerID: firstOwner)
    ) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .kitchenOwnedByAnotherOwner(kitchenID: foreignKitchen.id)
      )
    }
    XCTAssertEqual(try repository.kitchens(), [foreignKitchen])
  }

  func testBootstrapPreservesALegacyKitchenUntilDevelopmentDataIsReset() throws {
    let repository = try makeRepository()
    let legacyKitchen = Kitchen(name: "Legacy Kitchen")
    try repository.save(legacyKitchen)

    XCTAssertEqual(
      try KitchenBootstrapService(repository: repository).prepareInitialKitchen(),
      legacyKitchen
    )
  }

  func testSampleFailureCannotPartiallyInstallIntoAKitchen() throws {
    let repository = try makeRepository()
    let kitchen = Kitchen(name: "Home")
    try repository.save(kitchen)
    let service = SampleRecipeInstallService(
      repository: repository,
      samples: FailingSampleProvider()
    )

    XCTAssertThrowsError(try service.install(in: kitchen.id))
    XCTAssertEqual(try repository.kitchens(), [kitchen])
    XCTAssertTrue(try repository.recipes(in: kitchen.id).isEmpty)
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

  private func makeRevisionRecord(
    id: RecipeRevision.ID,
    recipeID: Recipe.ID
  ) -> RecipeRevisionRecord {
    RecipeRevisionRecord(
      id: id.rawValue,
      recipeID: recipeID.rawValue,
      revisionNumber: 1,
      title: "Sample",
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
private struct FailingSampleProvider: SampleRecipeProviding {
  struct Failure: Error {}

  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] {
    throw Failure()
  }
}
