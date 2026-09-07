// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import SwiftData
import XCTest

@MainActor
final class RecordsMaintenanceRepositoryTests: XCTestCase {
  private let date = Date(timeIntervalSince1970: 1_700_000_000)

  func testRecipeSweepsResumePastIneligibleCandidates() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let kitchen = Kitchen(name: "Home")
    let recipes = SwiftDataRecipeRepository(modelContainer: container)
    try recipes.save(kitchen)
    let maintenance = RecordsMaintenanceRepository(modelContainer: container, kitchenID: kitchen.id, batchSize: 1)
    for _ in 0..<2 {
      for job in RecordsMaintenanceJob.allCases { XCTAssertTrue(try maintenance.run(job, at: date)) }
    }
    let created = try (0..<3).map { index in
      try RecipeEditor(repository: recipes).create(in: kitchen.id, from: RecipeDraft(title: "Soup \(index)"))
    }.sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
    let now = date.addingTimeInterval(40 * 86_400)
    for (index, recipe) in created.enumerated() {
      if index == 0 {
        let old = RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: recipe.id, deletedAt: date)
        try recipes.delete(old)
        try recipes.restore(RecipeRestoreCommand(kitchenID: kitchen.id, recipeID: recipe.id,
          observedDeletionIDs: [old.id], restoredAt: date.addingTimeInterval(86_400)))
      }
      try recipes.delete(RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: recipe.id,
                                            deletedAt: index == 0 ? now : date))
    }
    var schedule = RecordsMaintenanceSchedule()
    let first = try maintenance.run(.deletedRecipes, at: now, after: nil)
    XCTAssertEqual(first, created[0].id.rawValue.uuidString)
    XCTAssertEqual(try recipes.deletedRecipes(in: kitchen.id).count, 3)
    schedule.record(.deletedRecipes, at: now, completed: false, continuation: first)
    schedule = try JSONDecoder().decode(RecordsMaintenanceSchedule.self, from: JSONEncoder().encode(schedule))
    let reopened = RecordsMaintenanceRepository(modelContainer: container, kitchenID: kitchen.id, batchSize: 1)
    let second = try reopened.run(.deletedRecipes, at: now, after: schedule.continuation(for: .deletedRecipes))
    XCTAssertEqual(second, created[1].id.rawValue.uuidString)
    XCTAssertNil(try reopened.run(.deletedRecipes, at: now, after: second))
    XCTAssertEqual(try recipes.deletedRecipes(in: kitchen.id).map(\.id), [created[0].id])
    XCTAssertEqual(try recipes.recipeAuthority(id: created[1].id), .pruned)
    let later = date.addingTimeInterval(2_000 * 86_400)
    let tombstones = try reopened.run(.recipeTombstones, at: later, after: nil)
    XCTAssertNotNil(tombstones)
    XCTAssertNil(try reopened.run(.recipeTombstones, at: later, after: tombstones))
    XCTAssertNil(try recipes.recipeAuthority(id: created[1].id))
  }

  func testOrganizationProgressIsIndependentOfStoreSizeAndReusesItsCheckpoint() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let kitchen = Kitchen(name: "Home")
    try SwiftDataRecipeRepository(modelContainer: container).save(kitchen)
    let writer = ModelContext(container)
    for _ in 0..<4_097 {
      writer.insert(SessionFactRecord(id: UUID(), sessionID: UUID(), kitchenID: kitchen.id.rawValue,
        kind: "pending", targetSnapshotElementID: nil, authoredAt: date,
        causalHeadsFormatVersion: -1, causalHeadsData: Data(), payloadFormatVersion: -1,
        payloadData: Data(), payloadDigest: Data()))
    }
    for index in 0..<900 {
      let action = OrganizationAction<TagChange>(id: UUID(), authoredAt: date, observed: [],
        payload: .create(id: Tag.ID(), name: "\(index) " + String(repeating: "é", count: 240)))
      writer.insert(try OrganizationActionRecord(action: action, kitchenID: kitchen.id, namespace: "tags"))
    }
    try writer.save()
    XCTAssertGreaterThan(try writer.fetch(FetchDescriptor<OrganizationActionRecord>())
      .reduce(0, { $0 + $1.payloadData.count }), 512_000)
    let now = date.addingTimeInterval(40 * 86_400)
    let maintenance = RecordsMaintenanceRepository(modelContainer: container, kitchenID: kitchen.id, batchSize: 32)
    XCTAssertNotNil(try maintenance.run(.tags, at: now, after: nil))
    XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<OrganizationActionRecord>()), 868)
    XCTAssertNotNil(try maintenance.run(.tags, at: now, after: "remaining"))
    XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<OrganizationActionRecord>()), 836)
    XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<OrganizationCheckpointRecord>()), 1)
    let resumed = RecordsMaintenanceRepository(modelContainer: container, kitchenID: kitchen.id, batchSize: 1_000)
    XCTAssertTrue(try resumed.run(.tags, at: now))
    XCTAssertEqual(try SwiftDataTagRepository(modelContainer: container).library(in: kitchen.id).tags.count, 900)
    XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<SessionFactRecord>()), 4_097)
  }

  func testFolderAssignmentDependenciesAndMalformedEvidenceAreRetained() throws {
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
    try folders.append(
      folders.library(in: kitchen.id).prepare(.create(id: Folder.ID(), name: "Meals", parentID: nil), at: date))
    let limited = RecordsMaintenanceRepository(modelContainer: container, kitchenID: kitchen.id, batchSize: 1)
    XCTAssertFalse(try limited.run(.folders, at: date.addingTimeInterval(40 * 86_400)))
    XCTAssertTrue(try limited.run(.folders, at: date.addingTimeInterval(40 * 86_400)))
    XCTAssertTrue(try maintenance.run(.folderOrphans, at: date))
    XCTAssertTrue(try maintenance.run(.tagOrphans, at: date))
    let context = ModelContext(container)
    let record = try XCTUnwrap(context.fetch(FetchDescriptor<OrganizationActionRecord>()).first)
    record.payloadData = Data(repeating: 0, count: 512_001)
    try context.save()
    let job: RecordsMaintenanceJob = record.namespace == "tags" ? .tagOrphans : .folderOrphans
    XCTAssertThrowsError(try maintenance.run(job, at: date))
    XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<OrganizationActionRecord>()), 2)
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
    XCTAssertTrue(try maintenance.run(.tagOrphans, at: date.addingTimeInterval(365 * 86_400)))
    XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<OrganizationActionRecord>()), 1)
    XCTAssertTrue(try maintenance.run(.tagOrphans, at: date.addingTimeInterval(366 * 86_400)))
    XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<OrganizationActionRecord>()), 0)
    XCTAssertTrue(try maintenance.run(.tagCheckpoints, at: date.addingTimeInterval(400 * 86_400)))
    XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<OrganizationCheckpointRecord>()), 2)
    XCTAssertTrue(try maintenance.run(.tagCheckpoints, at: date.addingTimeInterval(2_000 * 86_400)))
    XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<OrganizationCheckpointRecord>()), 1)
    XCTAssertEqual(try tags.library(in: kitchen.id).tags, expected)
    try tags.append(create)
    XCTAssertEqual(try tags.library(in: kitchen.id).tags, expected)
  }
}
