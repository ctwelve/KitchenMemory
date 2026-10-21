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
    let preparedBatch = try XCTUnwrap(repository.prepareHistoryMove([first.id, second.id, third.id],
      to: folder, in: scope))
    let batchData = try JSONEncoder().encode(preparedBatch)
    let batchObject = try XCTUnwrap(JSONSerialization.jsonObject(with: batchData) as? [String: Any])
    XCTAssertEqual(batchObject["version"] as? Int, 2)
    XCTAssertNotNil(batchObject["members"])
    XCTAssertNil(batchObject["recipeID"], "Older readers must fail closed on a batch")
    XCTAssertEqual(try JSONDecoder().decode(RecipeOrganizationHistoryChange.self, from: batchData), preparedBatch)
    let legacySingle = try XCTUnwrap(repository.prepareHistoryMove(first.id, to: otherFolder, in: scope))
    let legacyData = try JSONEncoder().encode(legacySingle)
    let legacyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: legacyData) as? [String: Any])
    XCTAssertNil(legacyObject["version"])
    XCTAssertNotNil(legacyObject["anchorID"])
    XCTAssertEqual(try JSONDecoder().decode(RecipeOrganizationHistoryChange.self, from: legacyData), legacySingle)
    var futureObject = legacyObject
    futureObject["version"] = 3
    XCTAssertThrowsError(try JSONDecoder().decode(RecipeOrganizationHistoryChange.self,
      from: JSONSerialization.data(withJSONObject: futureObject)))
    let history = RecipeOrganizationHistory(repository: repository)
    try await history.open(scope: scope, historyURL: directory.appendingPathComponent("History.sqlite"))

    do {
      _ = try await history.move([first.id, Recipe.ID()], to: folder)
      XCTFail("A batch containing an unavailable Recipe must be rejected")
    } catch RecipeOrganizationHistoryError.ineligible {}
    XCTAssertEqual(try repository.load(in: kitchen.id).folders.primaryFolder(for: first.id), folder)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canUndo)

    let moved = try await history.move([first.id, second.id, third.id], to: folder)
    assertOrganizationHistoryAccepted(moved)
    XCTAssertEqual(try repository.load(in: kitchen.id).folders.primaryFolder(for: first.id), folder)
    XCTAssertEqual(try repository.load(in: kitchen.id).folders.primaryFolder(for: second.id), folder)
    XCTAssertEqual(try repository.load(in: kitchen.id).folders.primaryFolder(for: third.id), folder)
    XCTAssertTrue(try XCTUnwrap(history.session).status.canUndo)
    let noOp = try await history.move([first.id, second.id, third.id], to: folder)
    XCTAssertEqual(noOp, .rejected)

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
    guard case .unresolved = unresolved else { return XCTFail("A lost bulk reply must require reconciliation") }
    XCTAssertEqual(try fixture.placement(), fixture.first)
    XCTAssertEqual(try fixture.repository.load(in: fixture.kitchenID).folders.primaryFolder(for: extra.id), fixture.first)
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
