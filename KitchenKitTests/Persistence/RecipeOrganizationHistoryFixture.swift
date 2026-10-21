// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenKit
import SwiftData
import UndoKit
import XCTest

@MainActor
struct HistoryFixture {
  let directory: URL
  let container: ModelContainer
  let recipes: SwiftDataRecipeRepository
  let repository: SwiftDataRecipeOrganizationRepository
  let kitchenID: Kitchen.ID
  let recipeID: Recipe.ID
  let first: Folder.ID
  let second: Folder.ID
  let scope: RecipeOrganizationHistoryScope
  var historyURL: URL { directory.appendingPathComponent("History.sqlite") }

  init() throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    container = try KitchenMemorySchema.makeContainer(storeURL: directory.appendingPathComponent("Kitchen.store"))
    recipes = SwiftDataRecipeRepository(modelContainer: container)
    repository = SwiftDataRecipeOrganizationRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Home")
    kitchenID = kitchen.id
    try recipes.save(kitchen)
    first = Folder.ID(); second = Folder.ID()
    try repository.accept(repository.load(in: kitchen.id).prepare(
      folder: .create(id: first, name: "Meals", parentID: nil)))
    try repository.accept(repository.load(in: kitchen.id).prepare(
      folder: .create(id: second, name: "Other", parentID: nil)))
    let save = try RecipeEditor(repository: recipes).prepareSave(in: kitchen.id, from: RecipeDraft(title: "Soup"),
                                                               original: nil, observedSelectionIDs: [])
    try recipes.save(save)
    recipeID = save.recipe.id
    scope = RecipeOrganizationHistoryScope(ownerID: KitchenOwner.ID(rawValue: "test-owner"), storeID: "local-test",
      kitchenID: kitchen.id, logicalSceneID: UUID())
  }

  func placement() throws -> Folder.ID? { try repository.load(in: kitchenID).folders.primaryFolder(for: recipeID) }
  func moveOutsideHistory(to folderID: Folder.ID?) throws {
    try repository.accept(repository.load(in: kitchenID).move([recipeID], to: folderID))
  }
  func removeFiles() { try? FileManager.default.removeItem(at: directory) }
}

/// The public repository is the fault boundary. Every accepted effect still uses
/// the real SwiftData transaction; failures model a proved refusal or lost reply.
@MainActor
final class ControlledHistoryRepository: RecipeOrganizationHistoryRepository {
  let base: SwiftDataRecipeOrganizationRepository
  var rejectNextAcceptance = false
  var failNextAcceptance = false
  var failNextEligibilityRead = false
  var rejectNextScope = false
  var loseNextReply = false
  var withholdReceipts = false
  var deliveries: [RecipeOrganizationHistoryDelivery] = []
  init(_ base: SwiftDataRecipeOrganizationRepository) { self.base = base }
  func load(in kitchenID: Kitchen.ID) throws -> RecipeOrganization { try base.load(in: kitchenID) }
  func accept(_ command: RecipeOrganizationCommand, firstSave: RecipeSaveCommand?) throws {
    try base.accept(command, firstSave: firstSave)
  }
  func prepareHistoryMove(_ recipeID: Recipe.ID, to folderID: Folder.ID?, in scope: RecipeOrganizationHistoryScope)
    throws -> RecipeOrganizationHistoryChange? { try base.prepareHistoryMove(recipeID, to: folderID, in: scope) }
  func prepareHistoryDelivery(_ change: RecipeOrganizationHistoryChange, memberID: UUID, token: UndoKit.HistoryToken,
                              in scope: RecipeOrganizationHistoryScope) throws -> RecipeOrganizationHistoryDelivery {
    try base.prepareHistoryDelivery(change, memberID: memberID, token: token, in: scope)
  }
  func acceptHistory(_ delivery: RecipeOrganizationHistoryDelivery) throws -> RecipeOrganizationHistoryReceipt {
    deliveries.append(delivery)
    if failNextAcceptance { failNextAcceptance = false; throw LostReply() }
    if rejectNextScope { rejectNextScope = false; throw RecipeOrganizationHistoryError.invalidScope }
    if rejectNextAcceptance {
      rejectNextAcceptance = false
      throw RecipeOrganizationHistoryError.ineligible
    }
    let receipt = try base.acceptHistory(delivery)
    if loseNextReply { loseNextReply = false; throw LostReply() }
    return receipt
  }
  func recoverHistory(_ delivery: RecipeOrganizationHistoryDelivery) throws -> RecipeOrganizationHistoryReceipt {
    deliveries.append(delivery)
    return try base.recoverHistory(delivery)
  }
  func historyReceipt(for token: UndoKit.HistoryToken, in scope: RecipeOrganizationHistoryScope)
    throws -> RecipeOrganizationHistoryReceipt? {
    withholdReceipts ? nil : try base.historyReceipt(for: token, in: scope)
  }
  func historyIsEligible(in scope: RecipeOrganizationHistoryScope, generation: UUID) throws -> Bool {
    if failNextEligibilityRead { failNextEligibilityRead = false; throw LostReply() }
    return try base.historyIsEligible(in: scope, generation: generation)
  }
  private struct LostReply: Error {}
}

struct FutureHistoryReceipt: OrganizationPayload {
  let version: Int
  let receipt: RecipeOrganizationHistoryReceipt
  var compactableRegister: String? { nil }
}

func assertOrganizationHistoryAccepted(
  _ result: HistorySubmissionResult, file: StaticString = #filePath, line: UInt = #line
) {
  guard case .accepted = result else {
    XCTFail("Expected accepted organization history, got \(result)", file: file, line: line)
    return
  }
}
