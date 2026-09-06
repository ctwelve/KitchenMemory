// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenKit
import SwiftData
import XCTest

@MainActor
final class SwiftDataFolderRepositoryTests: XCTestCase {
  func testRelaunchAndCompactionPreserveFolderAndSuppressExactRetry() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "Folders.store")
    let kitchen = Kitchen(name: "Home")
    let folderID = Folder.ID()
    let command: FolderCommand
    do {
      let container = try KitchenMemorySchema.makeContainer(storeURL: url)
      try SwiftDataRecipeRepository(modelContainer: container).save(kitchen)
      let repository = SwiftDataFolderRepository(modelContainer: container)
      command = try repository.library(in: kitchen.id).prepare(
        .create(id: folderID, name: "Meals", parentID: nil), at: Date(timeIntervalSince1970: 0)
      )
      try repository.append(command)
      try repository.append(command)
      XCTAssertNotNil(try repository.compact(in: kitchen.id, at: Date(timeIntervalSince1970: 40 * 86_400)))
    }
    let reopened = SwiftDataFolderRepository(modelContainer: try KitchenMemorySchema.makeContainer(storeURL: url))
    XCTAssertEqual(try reopened.library(in: kitchen.id).folders.map(\.id), [folderID])
    try reopened.append(command)
    XCTAssertNil(try reopened.compact(in: kitchen.id, at: Date(timeIntervalSince1970: 50 * 86_400)))
    XCTAssertEqual(try reopened.library(in: kitchen.id).folders.map(\.name), ["Meals"])
  }
  func testConvergenceAndResetIncludeRawActionsAndCheckpoints() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let recipes = SwiftDataRecipeRepository(modelContainer: container)
    let folders = SwiftDataFolderRepository(modelContainer: container)
    let legacy = Kitchen(name: "Legacy")
    try recipes.save(legacy)
    let first = try folders.library(in: legacy.id).prepare(
      .create(id: Folder.ID(), name: "Old", parentID: nil), at: Date(timeIntervalSince1970: 0)
    )
    try folders.append(first)
    try folders.compact(in: legacy.id, at: Date(timeIntervalSince1970: 40 * 86_400))
    let second = try folders.library(in: legacy.id).prepare(.create(id: Folder.ID(), name: "New", parentID: nil))
    try folders.append(second)
    let personal = Kitchen(name: "Personal")
    try recipes.convergeKitchens(into: personal, ownedBy: KitchenOwner.ID(rawValue: "folder-test-owner"))
    XCTAssertEqual(Set(try folders.library(in: personal.id).folders.map(\.name)), ["Old", "New"])
    XCTAssertTrue(try folders.library(in: legacy.id).folders.isEmpty)
    try SwiftDataKitchenResetRepository(modelContainer: container).reset(kitchenID: personal.id, to: [])
    XCTAssertTrue(try folders.library(in: personal.id).folders.isEmpty)
  }

  func testAssignmentRequiresExistingRecipeInTheSameKitchenAndDoesNotChangeItsRevision() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let recipes = SwiftDataRecipeRepository(modelContainer: container)
    let folders = SwiftDataFolderRepository(modelContainer: container)
    let home = Kitchen(name: "Home")
    let away = Kitchen(name: "Away")
    try recipes.save(home)
    try recipes.save(away)
    let recipeID = Recipe.ID()
    let revision = RecipeRevision(recipeID: recipeID, revisionNumber: 1, title: "Soup")
    try recipes.save(recipe: Recipe(id: recipeID, kitchenID: home.id, currentRevisionID: revision.id),
                     revision: revision)
    let valid = try folders.library(in: home.id).prepare(.assign(recipeID: recipeID, folderID: nil))
    try folders.append(valid)
    XCTAssertEqual(try recipes.recipe(id: recipeID)?.revision, revision)
    let foreign = try folders.library(in: away.id).prepare(.assign(recipeID: recipeID, folderID: nil))
    XCTAssertThrowsError(try folders.append(foreign))
    let missing = try folders.library(in: home.id).prepare(.assign(recipeID: Recipe.ID(), folderID: nil))
    XCTAssertThrowsError(try folders.append(missing))
    let absentKitchen = try FolderLibrary(kitchenID: Kitchen.ID(), commands: [])
    XCTAssertThrowsError(try folders.append(absentKitchen.prepare(.create(id: Folder.ID(), name: "No Kitchen",
                                                                         parentID: nil))))
  }

  func testDamagedCheckpointRemainsRecoveryInsteadOfAnEmptyLibrary() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let kitchen = Kitchen(name: "Home")
    try SwiftDataRecipeRepository(modelContainer: container).save(kitchen)
    let folders = SwiftDataFolderRepository(modelContainer: container)
    try folders.append(folders.library(in: kitchen.id).prepare(
      .create(id: Folder.ID(), name: "Meals", parentID: nil), at: Date(timeIntervalSince1970: 0)
    ))
    try folders.compact(in: kitchen.id, at: Date(timeIntervalSince1970: 40 * 86_400))
    let context = ModelContext(container)
    let checkpoint = try XCTUnwrap(context.fetch(FetchDescriptor<OrganizationCheckpointRecord>()).first)
    checkpoint.formatVersion = 999
    try context.save()
    XCTAssertThrowsError(try folders.library(in: kitchen.id))
    checkpoint.formatVersion = 1
    checkpoint.checkpointDigest = Data([0])
    try context.save()
    XCTAssertThrowsError(try folders.library(in: kitchen.id))
  }

  func testAcceptedAssignmentRetrySurvivesRecipePruningWithRawOrCheckpointedEvidence() throws {
    for compacted in [false, true] {
      let container = try KitchenMemorySchema.makeContainer(inMemory: true)
      let kitchen = Kitchen(name: "Home")
      let recipes = SwiftDataRecipeRepository(modelContainer: container)
      try recipes.save(kitchen)
      let recipe = try RecipeEditor(repository: recipes).create(in: kitchen.id, from: RecipeDraft(title: "Soup"))
      let folders = SwiftDataFolderRepository(modelContainer: container)
      let assignment = try folders.library(in: kitchen.id).prepare(.assign(recipeID: recipe.id, folderID: nil),
                                                                   at: Date(timeIntervalSince1970: 0))
      try folders.append(assignment)
      if compacted { try folders.compact(in: kitchen.id, at: Date(timeIntervalSince1970: 40 * 86_400)) }
      try recipes.delete(RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: recipe.id,
                                             deletedAt: Date(timeIntervalSince1970: 0)))
      _ = try recipes.maintainDeletedRecipes(in: kitchen.id, at: Date(timeIntervalSince1970: 30 * 86_400))
      XCTAssertEqual(try recipes.recipeAuthority(id: recipe.id), .pruned)
      XCTAssertNoThrow(try folders.append(assignment))
      let newAssignment = try folders.library(in: kitchen.id).prepare(.assign(recipeID: recipe.id, folderID: nil))
      XCTAssertThrowsError(try folders.append(newAssignment))
    }
  }

  func testActionIdentityCannotBeReusedAcrossKitchens() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let recipes = SwiftDataRecipeRepository(modelContainer: container)
    let folders = SwiftDataFolderRepository(modelContainer: container)
    let home = Kitchen(name: "Home")
    let away = Kitchen(name: "Away")
    try recipes.save(home)
    try recipes.save(away)
    let command = try folders.library(in: home.id).prepare(.create(id: Folder.ID(), name: "Home", parentID: nil))
    try folders.append(command)
    let impostor = try folders.library(in: away.id).prepare(.create(id: Folder.ID(), name: "Away", parentID: nil),
                                                            id: command.id)
    XCTAssertThrowsError(try folders.append(impostor)) { error in
      XCTAssertEqual(error as? FolderError, .wrongKitchen)
    }
    XCTAssertEqual(try folders.library(in: home.id).folders.map(\.name), ["Home"])
    XCTAssertTrue(try folders.library(in: away.id).folders.isEmpty)
  }

}
