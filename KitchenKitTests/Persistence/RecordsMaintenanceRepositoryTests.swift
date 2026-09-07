// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import SwiftData
import XCTest

@MainActor
final class RecordsMaintenanceRepositoryTests: XCTestCase {
  private let date = Date(timeIntervalSince1970: 1_700_000_000)

  func testEmptyOpportunitiesAreRepeatableAndAdmissionNeverTruncatesEvidence() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let kitchen = Kitchen(name: "Home")
    let recipes = SwiftDataRecipeRepository(modelContainer: container)
    try recipes.save(kitchen)
    let maintenance = RecordsMaintenanceRepository(modelContainer: container, kitchenID: kitchen.id)
    for _ in 0..<2 {
      for job in RecordsMaintenanceJob.allCases { XCTAssertTrue(try maintenance.run(job, at: date)) }
    }
    let recipe = try RecipeEditor(repository: recipes).create(in: kitchen.id, from: RecipeDraft(title: "Soup"))
    try recipes.delete(RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: recipe.id, deletedAt: date))
    let constrained = RecordsMaintenanceRepository(modelContainer: container, kitchenID: kitchen.id, rowBudget: 1)
    XCTAssertFalse(try constrained.run(.deletedRecipes, at: date.addingTimeInterval(40 * 86_400)))
    XCTAssertEqual(try recipes.deletedRecipes(in: kitchen.id).map(\.id), [recipe.id])
    XCTAssertTrue(try maintenance.run(.deletedRecipes, at: date.addingTimeInterval(40 * 86_400)))
    XCTAssertEqual(try recipes.recipeAuthority(id: recipe.id), .pruned)
    XCTAssertTrue(try maintenance.run(.compactEvidence, at: date.addingTimeInterval(2_000 * 86_400)))
    XCTAssertNil(try recipes.recipeAuthority(id: recipe.id))
  }

  func testFolderAssignmentDependenciesAndOversizedEncodedHistoryAreRetained() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let kitchen = Kitchen(name: "Home")
    let recipes = SwiftDataRecipeRepository(modelContainer: container)
    try recipes.save(kitchen)
    let recipe = try RecipeEditor(repository: recipes).create(in: kitchen.id, from: RecipeDraft(title: "Soup"))
    let folders = SwiftDataFolderRepository(modelContainer: container)
    let tags = SwiftDataTagRepository(modelContainer: container)
    try folders.append(folders.library(in: kitchen.id).prepare(.assign(recipeID: recipe.id, folderID: nil), at: date))
    let tag = Tag.ID()
    try tags.append(tags.library(in: kitchen.id).prepare(.create(id: tag, name: "Meals"), at: date))
    try tags.append(tags.library(in: kitchen.id).prepare(.assign(recipeID: recipe.id, tagID: tag), at: date))
    let maintenance = RecordsMaintenanceRepository(modelContainer: container, kitchenID: kitchen.id)
    XCTAssertTrue(try maintenance.run(.orphans, at: date))
    let context = ModelContext(container)
    let record = try XCTUnwrap(context.fetch(FetchDescriptor<OrganizationActionRecord>()).first)
    record.payloadData = Data(repeating: 0, count: 512_001)
    try context.save()
    XCTAssertFalse(try maintenance.run(.orphans, at: date))
    XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<OrganizationActionRecord>()), 3)
  }

  func testCheckpointMaintenancePreservesReconstructionAndSuppressesOldRawCopies() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let kitchen = Kitchen(name: "Home")
    try SwiftDataRecipeRepository(modelContainer: container).save(kitchen)
    let tags = SwiftDataTagRepository(modelContainer: container)
    let id = Tag.ID()
    let create = try tags.library(in: kitchen.id).prepare(.create(id: id, name: "Meals"), at: date)
    try tags.append(create)
    let maintenance = RecordsMaintenanceRepository(modelContainer: container, kitchenID: kitchen.id)
    XCTAssertTrue(try maintenance.run(.tags, at: date.addingTimeInterval(29 * 86_400)))
    XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<OrganizationActionRecord>()), 1)
    XCTAssertTrue(try maintenance.run(.tags, at: date.addingTimeInterval(30 * 86_400)))
    let rename = try tags.library(in: kitchen.id).prepare(.rename(id: id, name: "Dinners"),
      at: date.addingTimeInterval(31 * 86_400))
    try tags.append(rename)
    XCTAssertTrue(try maintenance.run(.tags, at: date.addingTimeInterval(61 * 86_400)))
    let expected = try tags.library(in: kitchen.id).tags
    let writer = ModelContext(container)
    writer.insert(try OrganizationActionRecord(action: create.action, kitchenID: kitchen.id, namespace: "tags"))
    try writer.save()
    XCTAssertTrue(try maintenance.run(.orphans, at: date.addingTimeInterval(365 * 86_400)))
    XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<OrganizationActionRecord>()), 1)
    XCTAssertTrue(try maintenance.run(.orphans, at: date.addingTimeInterval(366 * 86_400)))
    XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<OrganizationActionRecord>()), 0)
    XCTAssertTrue(try maintenance.run(.compactEvidence, at: date.addingTimeInterval(400 * 86_400)))
    XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<OrganizationCheckpointRecord>()), 2)
    XCTAssertTrue(try maintenance.run(.compactEvidence, at: date.addingTimeInterval(2_000 * 86_400)))
    XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<OrganizationCheckpointRecord>()), 1)
    XCTAssertEqual(try tags.library(in: kitchen.id).tags, expected)
    try tags.append(create)
    XCTAssertEqual(try tags.library(in: kitchen.id).tags, expected)
  }
}
