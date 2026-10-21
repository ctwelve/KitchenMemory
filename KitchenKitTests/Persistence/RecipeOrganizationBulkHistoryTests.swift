// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenKit
import SwiftData
import UndoKit
import XCTest

@MainActor
final class RecipeOrganizationBulkHistoryTests: XCTestCase {
  func testBulkMoveIsOneUndoableGroupForEveryChangedRecipe() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let container = try KitchenMemorySchema.makeContainer(storeURL: directory.appendingPathComponent("Kitchen.store"))
    let recipes = SwiftDataRecipeRepository(modelContainer: container)
    let repository = SwiftDataRecipeOrganizationRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try recipes.save(kitchen)
    let folder = Folder.ID()
    let otherFolder = Folder.ID()
    for (id, name) in [(folder, "Meals"), (otherFolder, "Other")] {
      try repository.accept(repository.load(in: kitchen.id).prepare(
        folder: .create(id: id, name: name, parentID: nil)))
    }
    let first = try RecipeEditor(repository: recipes).create(in: kitchen.id, from: RecipeDraft(title: "Soup"))
    let second = try RecipeEditor(repository: recipes).create(in: kitchen.id, from: RecipeDraft(title: "Bread"))
    let third = try RecipeEditor(repository: recipes).create(in: kitchen.id, from: RecipeDraft(title: "Rice"))
    try repository.accept(repository.load(in: kitchen.id).move([first.id], to: folder))
    try repository.accept(repository.load(in: kitchen.id).move([third.id], to: otherFolder))
    let scope = RecipeOrganizationHistoryScope(ownerID: KitchenOwner.ID(rawValue: "test-owner"), storeID: "local-test",
      kitchenID: kitchen.id, logicalSceneID: UUID())
    try assertEncodingCompatibility(repository: repository, scope: scope,
      recipeIDs: [first.id, second.id, third.id],
      destination: folder, legacyDestination: otherFolder)
    let history = RecipeOrganizationHistory(repository: repository)
    try await history.open(scope: scope, historyURL: directory.appendingPathComponent("History.sqlite"))

    try await assertInvalidBatchRejected(history: history, repository: repository,
      validRecipeID: first.id, kitchenID: kitchen.id, destination: folder)
    XCTAssertEqual(try repository.load(in: kitchen.id).folders.primaryFolder(for: first.id), folder)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canUndo)

    let moved = try await history.move([first.id, second.id, third.id], to: folder)
    assertOrganizationHistoryAccepted(moved)
    try assertPlacements(repository: repository, kitchenID: kitchen.id, recipeIDs: [first.id, second.id, third.id],
      expected: folder)
    XCTAssertTrue(try XCTUnwrap(history.session).status.canUndo)
    try await assertNoOpRejected(history: history, recipeIDs: [first.id, second.id, third.id], destination: folder)

    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertEqual(try repository.load(in: kitchen.id).folders.primaryFolder(for: first.id), folder,
      "The no-op member keeps its original placement")
    XCTAssertNil(try repository.load(in: kitchen.id).folders.primaryFolder(for: second.id))
    XCTAssertEqual(try repository.load(in: kitchen.id).folders.primaryFolder(for: third.id), otherFolder)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canUndo)
    XCTAssertTrue(try XCTUnwrap(history.session).status.canRedo)
    await history.close()

    let restored = RecipeOrganizationHistory(repository: repository)
    try await restored.open(scope: scope, historyURL: directory.appendingPathComponent("History.sqlite"))
    XCTAssertTrue(try XCTUnwrap(restored.session).status.canRedo)
    assertOrganizationHistoryAccepted(await restored.redo())
    XCTAssertEqual(try repository.load(in: kitchen.id).folders.primaryFolder(for: second.id), folder)
    await restored.close()
  }

  private func assertEncodingCompatibility(
    repository: SwiftDataRecipeOrganizationRepository, scope: RecipeOrganizationHistoryScope,
    recipeIDs: [Recipe.ID], destination: Folder.ID, legacyDestination: Folder.ID
  ) throws {
    let batch = try XCTUnwrap(repository.prepareHistoryMove(Set(recipeIDs), to: destination, in: scope))
    let batchData = try JSONEncoder().encode(batch)
    let batchObject = try XCTUnwrap(JSONSerialization.jsonObject(with: batchData) as? [String: Any])
    XCTAssertEqual(batchObject["version"] as? Int, 2)
    XCTAssertNotNil(batchObject["members"])
    XCTAssertNil(batchObject["recipeID"], "Older readers must fail closed on a batch")
    XCTAssertEqual(try JSONDecoder().decode(RecipeOrganizationHistoryChange.self, from: batchData), batch)
    let single = try XCTUnwrap(repository.prepareHistoryMove(recipeIDs[0], to: legacyDestination, in: scope))
    let singleData = try JSONEncoder().encode(single)
    let singleObject = try XCTUnwrap(JSONSerialization.jsonObject(with: singleData) as? [String: Any])
    XCTAssertNil(singleObject["version"])
    XCTAssertNotNil(singleObject["anchorID"])
    XCTAssertEqual(try JSONDecoder().decode(RecipeOrganizationHistoryChange.self, from: singleData), single)
    var futureObject = singleObject
    futureObject["version"] = 3
    XCTAssertThrowsError(try JSONDecoder().decode(RecipeOrganizationHistoryChange.self,
      from: JSONSerialization.data(withJSONObject: futureObject)))
  }

  private func assertPlacements(
    repository: SwiftDataRecipeOrganizationRepository, kitchenID: Kitchen.ID,
    recipeIDs: [Recipe.ID], expected: Folder.ID
  ) throws {
    for recipeID in recipeIDs {
      XCTAssertEqual(try repository.load(in: kitchenID).folders.primaryFolder(for: recipeID), expected)
    }
  }

  private func assertNoOpRejected(
    history: RecipeOrganizationHistory, recipeIDs: [Recipe.ID], destination: Folder.ID
  ) async throws {
    let result = try await history.move(Set(recipeIDs), to: destination)
    XCTAssertEqual(result, .rejected)
  }

  private func assertInvalidBatchRejected(
    history: RecipeOrganizationHistory, repository: SwiftDataRecipeOrganizationRepository,
    validRecipeID: Recipe.ID, kitchenID: Kitchen.ID, destination: Folder.ID
  ) async throws {
    do {
      _ = try await history.move([validRecipeID, Recipe.ID()], to: destination)
      XCTFail("A batch containing an unavailable Recipe must be rejected")
    } catch RecipeOrganizationHistoryError.ineligible {}
    XCTAssertEqual(try repository.load(in: kitchenID).folders.primaryFolder(for: validRecipeID), destination)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canUndo)
  }

  func testStaleMemberRejectsTheEntirePreparedBatch() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let container = try KitchenMemorySchema.makeContainer(storeURL: directory.appendingPathComponent("Kitchen.store"))
    let recipes = SwiftDataRecipeRepository(modelContainer: container)
    let repository = SwiftDataRecipeOrganizationRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    try recipes.save(kitchen)
    let target = Folder.ID(), elsewhere = Folder.ID()
    for (id, name) in [(target, "Meals"), (elsewhere, "Other")] {
      try repository.accept(repository.load(in: kitchen.id).prepare(folder: .create(id: id, name: name, parentID: nil)))
    }
    let ids = try ["Soup", "Bread", "Rice"].map {
      try RecipeEditor(repository: recipes).create(in: kitchen.id, from: RecipeDraft(title: $0)).id
    }
    let scope = RecipeOrganizationHistoryScope(ownerID: KitchenOwner.ID(rawValue: "test-owner"), storeID: "local-test",
      kitchenID: kitchen.id, logicalSceneID: UUID())

    for (index, staleID) in ids.enumerated() {
      let change = try XCTUnwrap(repository.prepareHistoryMove(Set(ids), to: target, in: scope))
      let token = HistoryToken(scope: scope.identity, generation: UUID(), sequence: Int64(index + 1), command: UUID())
      let delivery = try repository.prepareHistoryDelivery(change, memberID: UUID(), token: token, in: scope)
      try repository.accept(repository.load(in: kitchen.id).move([staleID], to: elsewhere))

      XCTAssertThrowsError(try repository.acceptHistory(delivery))
      XCTAssertEqual(try repository.load(in: kitchen.id).folders.primaryFolder(for: staleID), elsewhere)
      for untouchedID in ids where untouchedID != staleID {
        XCTAssertNil(try repository.load(in: kitchen.id).folders.primaryFolder(for: untouchedID),
          "A stale member must prevent every other Recipe in the batch from moving")
      }
      try repository.accept(repository.load(in: kitchen.id).move([staleID], to: nil))
    }
  }

  func testBulkLostReplyReopensWithExactMultiMemberReceiptAndUndo() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let extra = try RecipeEditor(repository: fixture.recipes).create(in: fixture.kitchenID,
      from: RecipeDraft(title: "Bread"))
    let boundary = ControlledHistoryRepository(fixture.repository)
    let history = RecipeOrganizationHistory(repository: boundary)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    boundary.loseNextReply = true
    boundary.withholdReceipts = true
    let unresolved = try await history.move([fixture.recipeID, extra.id], to: fixture.first)
    guard case .unresolved = unresolved else {
      XCTFail("A lost bulk reply must require reconciliation")
      return
    }
    XCTAssertEqual(try fixture.placement(), fixture.first)
    XCTAssertEqual(try fixture.repository.load(in: fixture.kitchenID).folders
      .primaryFolder(for: extra.id), fixture.first)
    let delivery = try XCTUnwrap(boundary.deliveries.last)
    XCTAssertEqual(delivery.change.changedMembers.map(\.recipeID), [fixture.recipeID, extra.id]
      .sorted { $0.rawValue.uuidString < $1.rawValue.uuidString })
    XCTAssertEqual(delivery.command.folders.count, 2)
    let deliveryCount = boundary.deliveries.count
    await history.close()

    boundary.withholdReceipts = false
    let reopened = RecipeOrganizationHistory(repository: boundary)
    try await reopened.open(scope: fixture.scope, historyURL: fixture.historyURL)
    XCTAssertEqual(boundary.deliveries.count, deliveryCount, "Reopen reconciles the frozen command without replay")
    XCTAssertTrue(try XCTUnwrap(reopened.session).status.canUndo)
    XCTAssertNoThrow(try fixture.repository.acceptHistory(delivery), "An exact retry returns the existing receipt")
    assertOrganizationHistoryAccepted(await reopened.undo())
    XCTAssertNil(try fixture.placement())
    XCTAssertNil(try fixture.repository.load(in: fixture.kitchenID).folders.primaryFolder(for: extra.id))
    await reopened.close()
  }
}
