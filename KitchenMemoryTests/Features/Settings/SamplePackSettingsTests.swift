// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
@testable import KitchenMemory
import XCTest
import SwiftData

@MainActor
final class SamplePackSettingsTests: XCTestCase {
  func testExplicitSampleSettingPreservesAnEditMadeAfterRemovalPreview() throws {
    let app = try AppRuntime.testing(.init(library: .empty))
    let model = app.libraryModel
    model.loadIfNeeded()
    XCTAssertFalse(try XCTUnwrap(model.samplePackStatus).isEnabled)
    model.acceptSampleRecipes()
    let installed = try XCTUnwrap(model.samplePackStatus)
    XCTAssertTrue(installed.isEnabled)
    XCTAssertGreaterThan(installed.total, 0)
    XCTAssertEqual(installed.installed, installed.total)
    let command = try XCTUnwrap(model.prepareSamplePackRemoval())
    let sample = try XCTUnwrap(model.recipes.first)
    XCTAssertTrue(model.reviseRecipe(id: sample.id, from: RecipeDraft(title: "Synthetic personal edit")))
    model.confirmSamplePackRemoval(command)
    let removed = try XCTUnwrap(model.samplePackStatus)
    XCTAssertFalse(removed.isEnabled)
    XCTAssertEqual(removed.edited, 1)
    XCTAssertEqual(removed.installed, 1)
    XCTAssertEqual(removed.deleted, installed.total - 1)
    model.reload()
    XCTAssertEqual(model.samplePackStatus, removed)
    model.acceptSampleRecipes()
    XCTAssertEqual(model.samplePackStatus?.installed, installed.total)
    XCTAssertEqual(model.samplePackStatus?.edited, 1)
  }

  func testFailedRequestSurvivesRefreshAndResetDiscardsIt() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Synthetic Kitchen")
    try repository.save(kitchen)
    let pack = RecoverableSampleRepository(base: SwiftDataSamplePackRepository(modelContainer: container))
    let model = RecipeLibraryModel(library: RecipeLibrary(kitchenID: kitchen.id, repository: repository,
      samples: BundledSampleRecipeProvider(preferredLanguages: ["en-US"]), importer: RecipeImportService(),
      resetRepository: SwiftDataKitchenResetRepository(modelContainer: container), samplePackRepository: pack),
      samplePreferences: VolatileKitchenPreferencesStore(sampleRecipeOnboardingResponse: .accepted),
      kitchenWasCreated: false)
    model.loadIfNeeded()
    XCTAssertFalse(model.setSamplePackEnabled(true))
    let pending = try XCTUnwrap(model.pendingSamplePack)
    model.reload()
    XCTAssertEqual(model.issue, .samples)
    XCTAssertEqual(model.pendingSamplePack?.id, pending.id)
    pack.fails = false
    model.retryCurrentIssue()
    XCTAssertNil(model.pendingSamplePack)
    XCTAssertNil(model.issue)
    XCTAssertTrue(try XCTUnwrap(model.samplePackStatus).isEnabled)
    XCTAssertEqual(pack.acceptedIDs, [pending.id, pending.id])
    pack.fails = true
    let off = try XCTUnwrap(model.prepareSamplePackRemoval())
    model.confirmSamplePackRemoval(off)
    XCTAssertNotNil(model.pendingSamplePack)
    XCTAssertTrue(model.resetKitchen())
    XCTAssertNil(model.pendingSamplePack)
    XCTAssertNil(model.issue)
    XCTAssertEqual(model.recipes.count, model.samplePackStatus?.total)
    XCTAssertFalse(try XCTUnwrap(model.samplePackStatus).isEnabled)
  }

  func testUnavailableSamplesRemainHonestAndExplicitRetryCanRecover() throws {
    let samples = RecoverableSamples()
    let app = try AppRuntime.testing(.init(library: .empty, sampleProvider: samples))
    let model = app.libraryModel
    model.loadIfNeeded()
    XCTAssertNil(model.samplePackStatus)
    XCTAssertFalse(model.setSamplePackEnabled(true))
    XCTAssertEqual(model.issue, .samples)
    XCTAssertNil(model.prepareSamplePackRemoval())
    samples.unavailable = false
    model.retryCurrentIssue()
    XCTAssertNotNil(model.samplePackStatus)
    XCTAssertTrue(try XCTUnwrap(model.samplePackStatus).isEnabled)
  }
}

@MainActor
private final class RecoverableSamples: SampleRecipeProviding {
  var unavailable = true
  enum Failure: Error { case unavailable }
  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] {
    if unavailable { throw Failure.unavailable }
    return try BundledSampleRecipeProvider(preferredLanguages: ["en-US"]).recipes(in: kitchenID)
  }
}

@MainActor
private final class RecoverableSampleRepository: SamplePackRepository {
  let base: SwiftDataSamplePackRepository
  var fails = true
  var acceptedIDs: [UUID] = []
  init(base: SwiftDataSamplePackRepository) { self.base = base }
  func status(in kitchenID: Kitchen.ID, samples: [StoredRecipe]) throws -> SamplePackStatus {
    try base.status(in: kitchenID, samples: samples)
  }
  func accept(_ command: SamplePackCommand) throws {
    acceptedIDs.append(command.id)
    if fails { throw RecoverableSamples.Failure.unavailable }
    try base.accept(command)
  }
}
