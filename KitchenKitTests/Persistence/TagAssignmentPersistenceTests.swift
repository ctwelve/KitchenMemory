// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenKit
import SwiftData
import XCTest

@MainActor
final class TagAssignmentPersistenceTests: XCTestCase {
  func testAssignmentRetrySurvivesPruningButNewAssignmentsRequireSameKitchenRecipe() throws {
    for compacted in [false, true] {
      let container = try KitchenMemorySchema.makeContainer(inMemory: true)
      let kitchen = Kitchen(name: "Home")
      let away = Kitchen(name: "Away")
      let recipes = SwiftDataRecipeRepository(modelContainer: container)
      try recipes.save(kitchen)
      try recipes.save(away)
      let recipe = try RecipeEditor(repository: recipes).create(in: kitchen.id, from: RecipeDraft(title: "Soup"))
      let revision = try recipes.recipe(id: recipe.id)?.revision
      let tags = SwiftDataTagRepository(modelContainer: container)
      let tagID = Tag.ID()
      let date = Date(timeIntervalSince1970: 0)
      try tags.append(tags.library(in: kitchen.id).prepare(.create(id: tagID, name: "Soup"), at: date))
      let assignment = try tags.library(in: kitchen.id).prepare(.assign(recipeID: recipe.id, tagID: tagID), at: date)
      try tags.append(assignment)
      XCTAssertEqual(try recipes.recipe(id: recipe.id)?.revision, revision)
      let foreignID = Tag.ID()
      try tags.append(tags.library(in: away.id).prepare(.create(id: foreignID, name: "Away"), at: date))
      XCTAssertThrowsError(try tags.append(tags.library(in: away.id).prepare(
        .assign(recipeID: recipe.id, tagID: foreignID)
      ))) { error in XCTAssertEqual(error as? TagError, .wrongKitchen) }
      if compacted { try tags.compact(in: kitchen.id, at: date.addingTimeInterval(40 * 86_400)) }
      try recipes.delete(RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: recipe.id, deletedAt: date))
      _ = try recipes.maintainDeletedRecipes(in: kitchen.id, at: date.addingTimeInterval(30 * 86_400))
      XCTAssertEqual(try recipes.recipeAuthority(id: recipe.id), .pruned)
      XCTAssertNoThrow(try tags.append(assignment))
      XCTAssertThrowsError(try tags.append(tags.library(in: kitchen.id).prepare(
        .assign(recipeID: recipe.id, tagID: tagID)
      ))) { error in XCTAssertEqual(error as? TagError, .missingRecipe(recipe.id)) }
      try tags.append(tags.library(in: kitchen.id).prepare(.remove(recipeID: recipe.id, tagID: tagID)))
      XCTAssertTrue(try tags.library(in: kitchen.id).tagIDs(for: recipe.id).isEmpty)
    }
  }

  func testManyToManyRelaunchAndTagDeletionPreserveRecipePayload() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "Tags.store")
    let kitchen = Kitchen(name: "Home")
    let first = Tag.ID()
    let second = Tag.ID()
    let recipeID: Recipe.ID
    do {
      let container = try KitchenMemorySchema.makeContainer(storeURL: url)
      let recipes = SwiftDataRecipeRepository(modelContainer: container)
      try recipes.save(kitchen)
      recipeID = try RecipeEditor(repository: recipes).create(in: kitchen.id, from: RecipeDraft(title: "Soup")).id
      let tags = SwiftDataTagRepository(modelContainer: container)
      for (id, name) in [(first, "First"), (second, "Second")] {
        try tags.append(tags.library(in: kitchen.id).prepare(.create(id: id, name: name)))
        try tags.append(tags.library(in: kitchen.id).prepare(.assign(recipeID: recipeID, tagID: id)))
      }
    }
    let container = try KitchenMemorySchema.makeContainer(storeURL: url)
    let tags = SwiftDataTagRepository(modelContainer: container)
    let recipes = SwiftDataRecipeRepository(modelContainer: container)
    let original = try recipes.recipe(id: recipeID)
    XCTAssertEqual(try tags.library(in: kitchen.id).tagIDs(for: recipeID), [first, second])
    try tags.append(tags.library(in: kitchen.id).prepare(.delete(id: first)))
    XCTAssertEqual(try tags.library(in: kitchen.id).tagIDs(for: recipeID), [second])
    XCTAssertEqual(try recipes.recipe(id: recipeID), original)
  }
}
