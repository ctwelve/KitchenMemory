// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData
import XCTest

@testable import KitchenKit

@MainActor
final class SamplePackRepositoryTests: XCTestCase {
  func testInstallReusesLocalizedOrdinaryOrganizationAndRetriesAtomically() throws {
    let fixture = try Fixture()
    let folderID = Folder.ID()
    let tagID = Tag.ID()
    try fixture.folders.append(
      fixture.folders.library(in: fixture.kitchen.id).prepare(
        .create(id: folderID, name: " RECETTES EXEMPLES ", parentID: nil)))
    try fixture.tags.append(fixture.tags.library(in: fixture.kitchen.id).prepare(.create(id: tagID, name: "#EXEMPLES")))
    let initial = try fixture.status()
    XCTAssertEqual(initial.installed, 0)
    XCTAssertFalse(initial.isEnabled)
    let install = fixture.command(true)
    try fixture.pack.accept(install)
    try fixture.pack.accept(install)
    let result = try fixture.status()
    XCTAssertTrue(result.isEnabled)
    XCTAssertEqual(result.installed, 2)
    XCTAssertEqual(result.removableIDs, Set(fixture.samples.map(\.id)))
    XCTAssertEqual(result.folderID, folderID)
    XCTAssertEqual(result.tagID, tagID)
    for sample in fixture.samples {
      XCTAssertEqual(try fixture.folders.library(in: fixture.kitchen.id).primaryFolder(for: sample.id), folderID)
      XCTAssertEqual(try fixture.tags.library(in: fixture.kitchen.id).tagIDs(for: sample.id), [tagID])
    }
    XCTAssertEqual(try ModelContext(fixture.container).fetchCount(FetchDescriptor<RecipeSaveRecord>()), 2)
    let changed = SamplePackCommand(
      id: install.id, kitchenID: fixture.kitchen.id, enabled: false,
      samples: fixture.samples, folderName: "Recettes exemples", tagName: "exemples")
    XCTAssertThrowsError(try fixture.pack.accept(changed))
    XCTAssertEqual(try fixture.status(), result)
  }

  func testRemovalPreservesEditsAndUnrelatedRecipesAndNeverOscillatesOnRestore() throws {
    let fixture = try Fixture()
    try fixture.pack.accept(fixture.command(true))
    let removed = fixture.samples[0]
    let edited = fixture.samples[1]
    _ = try RecipeEditor(repository: fixture.recipes).revise(
      recipeID: edited.id, from: RecipeDraft(title: "Personal edit"))
    let unrelated = try RecipeEditor(repository: fixture.recipes).create(
      in: fixture.kitchen.id, from: RecipeDraft(title: "Personal"))
    let before = try fixture.status()
    let folder = try XCTUnwrap(before.folderID)
    let tag = try XCTUnwrap(before.tagID)
    try fixture.folders.append(
      fixture.folders.library(in: fixture.kitchen.id).prepare(.assign(recipeID: unrelated.id, folderID: folder)))
    try fixture.tags.append(
      fixture.tags.library(in: fixture.kitchen.id).prepare(.assign(recipeID: unrelated.id, tagID: tag)))
    XCTAssertEqual(before.edited, 1)
    let off = fixture.command(false, removalIDs: before.removableIDs)
    try fixture.pack.accept(off)
    try fixture.pack.accept(off)
    XCTAssertNil(try fixture.recipes.recipe(id: removed.id))
    XCTAssertNotNil(try fixture.recipes.recipe(id: edited.id))
    XCTAssertNotNil(try fixture.recipes.recipe(id: unrelated.id))
    XCTAssertEqual(try fixture.folders.library(in: fixture.kitchen.id).folders.count, 1)
    XCTAssertEqual(try fixture.tags.library(in: fixture.kitchen.id).tags.count, 1)
    let deleted = try XCTUnwrap(fixture.recipes.deletedRecipes(in: fixture.kitchen.id).first)
    try fixture.recipes.restore(
      RecipeRestoreCommand(
        kitchenID: fixture.kitchen.id, recipeID: removed.id,
        observedDeletionIDs: deleted.observedDeletionIDs))
    let restored = try fixture.status()
    XCTAssertFalse(restored.isEnabled)
    XCTAssertEqual(restored.installed, 2)
    XCTAssertEqual(restored.edited, 1)
    XCTAssertEqual(restored.deleted, 0)
    for _ in 0..<3 { XCTAssertEqual(try fixture.status(), restored) }
    try fixture.pack.accept(off)
    XCTAssertNotNil(try fixture.recipes.recipe(id: removed.id))
  }

  func testInstalledUpdatesRespectRenameReassignmentAndOrganizationDeletion() throws {
    let fixture = try Fixture()
    try fixture.pack.accept(fixture.command(true))
    let installed = try fixture.status()
    let folder = try XCTUnwrap(installed.folderID)
    let tag = try XCTUnwrap(installed.tagID)
    try fixture.folders.append(
      fixture.folders.library(in: fixture.kitchen.id).prepare(.rename(id: folder, name: "Mine")))
    try fixture.tags.append(fixture.tags.library(in: fixture.kitchen.id).prepare(.rename(id: tag, name: "mine")))
    try fixture.folders.append(
      fixture.folders.library(in: fixture.kitchen.id).prepare(.assign(recipeID: fixture.samples[0].id, folderID: nil)))
    try fixture.tags.append(
      fixture.tags.library(in: fixture.kitchen.id).prepare(.remove(recipeID: fixture.samples[0].id, tagID: tag)))
    try fixture.pack.accept(fixture.command(true))
    XCTAssertNil(try fixture.folders.library(in: fixture.kitchen.id).primaryFolder(for: fixture.samples[0].id))
    XCTAssertTrue(try fixture.tags.library(in: fixture.kitchen.id).tagIDs(for: fixture.samples[0].id).isEmpty)
    try fixture.folders.append(fixture.folders.library(in: fixture.kitchen.id).prepare(.delete(id: folder)))
    try fixture.tags.append(fixture.tags.library(in: fixture.kitchen.id).prepare(.delete(id: tag)))
    try fixture.pack.accept(fixture.command(true))
    XCTAssertTrue(try fixture.folders.library(in: fixture.kitchen.id).folders.isEmpty)
    XCTAssertTrue(try fixture.tags.library(in: fixture.kitchen.id).tags.isEmpty)
    try fixture.pack.accept(fixture.command(false, removalIDs: try fixture.status().removableIDs))
    XCTAssertEqual(try fixture.status().deleted, 2)
    try fixture.pack.accept(fixture.command(true))
    let reinstalled = try fixture.status()
    XCTAssertEqual(reinstalled.installed, 2)
    XCTAssertNotEqual(reinstalled.folderID, folder)
    XCTAssertNotEqual(reinstalled.tagID, tag)
    XCTAssertEqual(try fixture.recipes.deletedRecipes(in: fixture.kitchen.id).count, 0)
  }

  func testDeletionWhileEnabledIsNotReinstalledAndLaterEditsEscapeConfirmedRemoval() throws {
    let fixture = try Fixture()
    try fixture.pack.accept(fixture.command(true))
    let off = fixture.command(false, removalIDs: try fixture.status().removableIDs)
    try fixture.recipes.delete(RecipeDeleteCommand(kitchenID: fixture.kitchen.id, recipeID: fixture.samples[0].id))
    try fixture.pack.accept(fixture.command(true))
    XCTAssertEqual(try fixture.status().deleted, 1)
    XCTAssertEqual(try fixture.status().installed, 1)
    _ = try RecipeEditor(repository: fixture.recipes).revise(
      recipeID: fixture.samples[1].id, from: RecipeDraft(title: "Late edit"))
    try fixture.pack.accept(off)
    XCTAssertNotNil(try fixture.recipes.recipe(id: fixture.samples[1].id))
    XCTAssertEqual(try fixture.status().edited, 1)
    try fixture.recipes.delete(RecipeDeleteCommand(kitchenID: fixture.kitchen.id, recipeID: fixture.samples[1].id))
    XCTAssertEqual(try fixture.status().edited, 1)
    try fixture.pack.accept(fixture.command(true))
    XCTAssertNil(try fixture.recipes.recipe(id: fixture.samples[1].id))
  }

  func testInvalidInstallationRollsBackOrganizationAndContent() throws {
    let fixture = try Fixture()
    let invalid = SamplePackCommand(
      kitchenID: fixture.kitchen.id, enabled: true, samples: fixture.samples,
      folderName: "Valid", tagName: "###")
    XCTAssertThrowsError(try fixture.pack.accept(invalid))
    XCTAssertTrue(try fixture.recipes.recipes(in: fixture.kitchen.id).isEmpty)
    XCTAssertTrue(try fixture.folders.library(in: fixture.kitchen.id).folders.isEmpty)
    let duplicate = SamplePackCommand(
      kitchenID: fixture.kitchen.id, enabled: true, samples: [fixture.samples[0], fixture.samples[0]],
      folderName: "Samples", tagName: "samples")
    XCTAssertThrowsError(try fixture.pack.accept(duplicate))
    let foreign = SamplePackCommand(
      kitchenID: Kitchen.ID(), enabled: true, samples: fixture.samples,
      folderName: "Samples", tagName: "samples")
    XCTAssertThrowsError(try fixture.pack.accept(foreign))
    XCTAssertThrowsError(try fixture.pack.accept(fixture.command(false, removalIDs: [Recipe.ID()])))
    // This collision occurs after organization has been staged, proving the shared transaction rolls it back.
    let context = ModelContext(fixture.container)
    context.insert(
      RecipeRevisionRecord(
        id: fixture.samples[0].revision.id.rawValue,
        recipeID: UUID(), revisionNumber: 1, title: "Collision", summary: nil,
        authorName: nil, contentLanguage: nil, sourceData: nil, yieldData: nil, prepSeconds: nil,
        cookSeconds: nil, totalSeconds: nil, cuisinesData: Data("[]".utf8),
        categoriesData: Data("[]".utf8), keywordsData: Data("[]".utf8)))
    try context.save()
    XCTAssertThrowsError(try fixture.pack.accept(fixture.command(true)))
    XCTAssertTrue(try fixture.folders.library(in: fixture.kitchen.id).folders.isEmpty)
    XCTAssertTrue(try fixture.tags.library(in: fixture.kitchen.id).tags.isEmpty)
  }

  func testConcurrentMatchingNamesChooseTheSameOrdinaryIdentitiesInEitherArrivalOrder() throws {
    let folderIDs = [Folder.ID(), Folder.ID()].sorted { $0.rawValue.uuidString < $1.rawValue.uuidString }
    let tagIDs = [Tag.ID(), Tag.ID()].sorted { $0.rawValue.uuidString < $1.rawValue.uuidString }
    for arrival in [[0, 1], [1, 0]] {
      let fixture = try Fixture()
      let emptyFolders = try fixture.folders.library(in: fixture.kitchen.id)
      let emptyTags = try fixture.tags.library(in: fixture.kitchen.id)
      let folderCommands = try folderIDs.map {
        try emptyFolders.prepare(.create(id: $0, name: "Recettes exemples", parentID: nil))
      }
      let tagCommands = try tagIDs.map { try emptyTags.prepare(.create(id: $0, name: "exemples")) }
      for index in arrival {
        try fixture.folders.append(folderCommands[index])
        try fixture.tags.append(tagCommands[index])
      }
      try fixture.pack.accept(fixture.command(true))
      XCTAssertEqual(try fixture.status().folderID, folderIDs[0])
      XCTAssertEqual(try fixture.status().tagID, tagIDs[0])
      XCTAssertEqual(try fixture.folders.library(in: fixture.kitchen.id).folders.count, 2)
      XCTAssertEqual(try fixture.tags.library(in: fixture.kitchen.id).tags.count, 2)
    }
  }

  func testIncompleteRemoteEvidenceIsCountedWithoutInstallingOverIt() throws {
    let fixture = try Fixture()
    let context = ModelContext(fixture.container)
    context.insert(RecipeDeletionRecord(id: UUID(), recipeID: fixture.samples[0].id.rawValue,
      kitchenID: fixture.kitchen.id.rawValue))
    try context.save()
    XCTAssertEqual(try fixture.status().unavailable, 1)
    try fixture.pack.accept(fixture.command(true))
    let result = try fixture.status()
    XCTAssertTrue(result.isEnabled)
    XCTAssertEqual(result.installed, 1)
    XCTAssertEqual(result.unavailable, 1)
    XCTAssertEqual(result.removableIDs, [fixture.samples[1].id])
    XCTAssertNil(try fixture.recipes.recipe(id: fixture.samples[0].id))
  }

  @MainActor
  private struct Fixture {
    let container: ModelContainer
    let kitchen = Kitchen(name: "Synthetic Kitchen")
    let samples: [StoredRecipe]
    let recipes: SwiftDataRecipeRepository
    let pack: SwiftDataSamplePackRepository
    let folders: SwiftDataFolderRepository
    let tags: SwiftDataTagRepository

    init() throws {
      container = try KitchenMemorySchema.makeContainer(inMemory: true)
      recipes = SwiftDataRecipeRepository(modelContainer: container)
      pack = SwiftDataSamplePackRepository(modelContainer: container)
      folders = SwiftDataFolderRepository(modelContainer: container)
      tags = SwiftDataTagRepository(modelContainer: container)
      let owner = kitchen.id
      samples = (0..<2).map { index in
        let id = Recipe.ID()
        let revisionID = RecipeRevision.ID()
        return StoredRecipe(
          recipe: Recipe(id: id, kitchenID: owner, currentRevisionID: revisionID),
          revision: RecipeRevision(id: revisionID, recipeID: id, revisionNumber: 1, title: "Synthetic sample \(index)"))
      }
      try recipes.save(kitchen)
    }

    func status() throws -> SamplePackStatus { try pack.status(in: kitchen.id, samples: samples) }
    func command(_ enabled: Bool, removalIDs: Set<Recipe.ID> = []) -> SamplePackCommand {
      SamplePackCommand(
        kitchenID: kitchen.id, enabled: enabled, samples: samples, removalIDs: removalIDs,
        folderName: "Recettes exemples", tagName: "exemples")
    }
  }
}
