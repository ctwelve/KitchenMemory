// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import SwiftData
import XCTest

@MainActor
final class RecipeRetentionTests: XCTestCase {
  func testPruningHonorsRecoveryWindowAndRetainsAnInvisibleTombstone() throws {
    let repository = SwiftDataRecipeRepository(modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true))
    let kitchen = Kitchen(name: "Kitchen")
    try repository.save(kitchen)
    let recipe = try RecipeEditor(repository: repository).create(in: kitchen.id, from: RecipeDraft(title: "Soup"))
    let deletedAt = Date(timeIntervalSince1970: 1_700_000_000)
    try repository.delete(RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: recipe.id, deletedAt: deletedAt))
    let early = try repository.maintainDeletedRecipes(in: kitchen.id, at: deletedAt.addingTimeInterval(29 * 86_400))
    XCTAssertTrue(early.prunedRecipeIDs.isEmpty)
    XCTAssertEqual(try repository.deletedRecipes(in: kitchen.id).count, 1)
    let now = deletedAt.addingTimeInterval(30 * 86_400)
    let result = try repository.maintainDeletedRecipes(in: kitchen.id, at: now)
    XCTAssertEqual(result.prunedRecipeIDs, [recipe.id])
    XCTAssertEqual(try repository.recipeAuthority(id: recipe.id), .pruned)
    XCTAssertTrue(try repository.revisions(for: recipe.id).isEmpty)
    XCTAssertTrue(try repository.deletedRecipes(in: kitchen.id).isEmpty)
    XCTAssertTrue(try repository.maintainDeletedRecipes(in: kitchen.id, at: now).prunedRecipeIDs.isEmpty)
  }
  func testSelfContainedSessionDoesNotPinRecipeButMediaReferencesDo() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Kitchen")
    try repository.save(kitchen)
    let editor = RecipeEditor(repository: repository)
    let plain = try editor.create(in: kitchen.id, from: RecipeDraft(title: "Soup"))
    let illustrated = try editor.create(in: kitchen.id, from: RecipeDraft(title: "Stew", media: [
      RecipeMedia(role: .hero, assetName: "retained-image"),
    ]))
    let sessionRepository = SwiftDataCookingSessionRepository(modelContainer: container)
    let sessions = CookingSessions(kitchenID: kitchen.id, recipeRepository: repository,
                                   sessionRepository: sessionRepository)
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    var sessionIDs: [CookingSession.ID] = []
    for recipe in [plain, illustrated] {
      let start = StartCookingSessionIntention(sessionID: CookingSession.ID(), recipeID: recipe.id,
                                               recipeRevisionID: recipe.revision.id, startedAt: date)
      _ = try sessions.start(start)
      sessionIDs.append(start.sessionID)
      try repository.delete(RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: recipe.id, deletedAt: date))
    }
    let before = try sessionIDs.map { try sessionRepository.evidence(id: $0) }
    let result = try repository.maintainDeletedRecipes(in: kitchen.id, at: date.addingTimeInterval(31 * 86_400))
    XCTAssertEqual(result.prunedRecipeIDs, [plain.id])
    XCTAssertEqual(try repository.deletedRecipes(in: kitchen.id).map(\.id), [illustrated.id])
    XCTAssertEqual(try sessionIDs.map { try sessionRepository.evidence(id: $0) }, before)
  }

  func testLateEvidenceIsRecoveryAndCannotResurrectPrunedIdentity() throws {
    let repository = SwiftDataRecipeRepository(modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true))
    let kitchen = Kitchen(name: "Kitchen")
    try repository.save(kitchen)
    let editor = RecipeEditor(repository: repository)
    let command = try editor.prepareSave(in: kitchen.id, from: RecipeDraft(title: "Soup"), original: nil,
                                         observedSelectionIDs: [])
    try repository.save(command)
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    try repository.delete(RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: command.recipe.id, deletedAt: date))
    _ = try repository.maintainDeletedRecipes(in: kitchen.id, at: date.addingTimeInterval(31 * 86_400))
    try repository.save(command)
    XCTAssertEqual(try repository.recipeAuthority(id: command.recipe.id), .recovery(.lateEvidenceAfterPrune))
    XCTAssertTrue(try repository.recipes(in: kitchen.id).isEmpty)
    let recovery = try XCTUnwrap(repository.recoveryRecipes(in: kitchen.id).first)
    XCTAssertEqual(recovery.id, command.recipe.id)
    XCTAssertEqual(recovery.revisions.map(\.title), ["Soup"])
    let muchLater = date.addingTimeInterval(10 * 366 * 86_400)
    XCTAssertTrue(try repository.maintainDeletedRecipes(in: kitchen.id, at: muchLater)
      .expiredTombstoneRecipeIDs.isEmpty)
  }

  func testTombstoneCannotExpireBeforeItsPromisedFiveYearHorizon() throws {
    let repository = SwiftDataRecipeRepository(modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true))
    let kitchen = Kitchen(name: "Kitchen")
    try repository.save(kitchen)
    let recipe = try RecipeEditor(repository: repository).create(in: kitchen.id, from: RecipeDraft(title: "Soup"))
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    try repository.delete(RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: recipe.id, deletedAt: date))
    let prunedAt = date.addingTimeInterval(31 * 86_400)
    _ = try repository.maintainDeletedRecipes(in: kitchen.id, at: prunedAt)
    let before = try repository.maintainDeletedRecipes(in: kitchen.id,
                                                       at: prunedAt.addingTimeInterval(4 * 366 * 86_400))
    XCTAssertTrue(before.expiredTombstoneRecipeIDs.isEmpty)
    XCTAssertEqual(try repository.recipeAuthority(id: recipe.id), .pruned)
    let expired = try repository.maintainDeletedRecipes(in: kitchen.id,
                                                        at: prunedAt.addingTimeInterval(6 * 366 * 86_400))
    XCTAssertEqual(expired.expiredTombstoneRecipeIDs, [recipe.id])
    XCTAssertNil(try repository.recipeAuthority(id: recipe.id))
  }

  func testRecoveryStartsANewDraftWithoutReusingRecipeOrChildIdentities() throws {
    let repository = SwiftDataRecipeRepository(modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true))
    let kitchen = Kitchen(name: "Kitchen")
    try repository.save(kitchen)
    let editor = RecipeEditor(repository: repository)
    let command = try editor.prepareSave(in: kitchen.id, from: RecipeDraft(title: "Soup", ingredientSections: [
      IngredientSection(ingredients: [RecipeIngredient(originalText: "salt as needed")]),
    ]), original: nil, observedSelectionIDs: [])
    try repository.save(command)
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    try repository.delete(RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: command.recipe.id, deletedAt: date))
    _ = try repository.maintainDeletedRecipes(in: kitchen.id, at: date.addingTimeInterval(31 * 86_400))
    try repository.save(command)
    let library = RecipeLibrary(kitchenID: kitchen.id, repository: repository,
                                samples: RetentionSamples(), importer: RecipeImportService())
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = FileRecipeEditingStore(url: directory.appendingPathComponent("drafts.json"))
    let drafts = RecipeDrafts(library: library, store: store)
    let recovered = try drafts.beginRecovery(recipeID: command.recipe.id, revisionID: command.revision.id)
    XCTAssertNil(recovered.original)
    let restored = RecipeDrafts(library: library, store: store)
    XCTAssertEqual(restored.drafts.first?.id, recovered.id)
    let draft = try library.prepareRecoveryDraft(recipeID: command.recipe.id, revisionID: command.revision.id)
    let save = try library.prepareSave(from: draft, original: nil, observedSelectionIDs: [])
    XCTAssertNotEqual(save.recipe.id, command.recipe.id)
    XCTAssertTrue(save.parentRevisionIDs.isEmpty)
    XCTAssertNotEqual(save.revision.ingredientSections.first?.id, command.revision.ingredientSections.first?.id)
    try library.save(save)
    XCTAssertEqual(try repository.recipes(in: kitchen.id).map(\.id), [save.recipe.id])
    XCTAssertEqual(try repository.recipeAuthority(id: command.recipe.id), .recovery(.lateEvidenceAfterPrune))
  }

  func testLateRootAloneRequiresRecoveryAndDoesNotAgeOutItsTombstone() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Kitchen")
    try repository.save(kitchen)
    let recipe = try RecipeEditor(repository: repository).create(in: kitchen.id, from: RecipeDraft(title: "Soup"))
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    try repository.delete(RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: recipe.id, deletedAt: date))
    _ = try repository.maintainDeletedRecipes(in: kitchen.id, at: date.addingTimeInterval(31 * 86_400))
    let replica = ModelContext(container)
    replica.insert(RecipeRecord(id: recipe.id.rawValue, kitchenID: kitchen.id.rawValue,
                                currentRevisionID: recipe.revision.id.rawValue))
    try replica.save()
    XCTAssertEqual(try repository.recipeAuthority(id: recipe.id), .recovery(.lateEvidenceAfterPrune))
    XCTAssertTrue(try repository.recoveryRecipes(in: kitchen.id).first?.revisions.isEmpty == true)
    XCTAssertTrue(try repository.maintainDeletedRecipes(in: kitchen.id, at: date.addingTimeInterval(10 * 366 * 86_400))
      .expiredTombstoneRecipeIDs.isEmpty)
  }

}

private struct RetentionSamples: SampleRecipeProviding {
  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] { [] }
}
