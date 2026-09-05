// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import SwiftData
import XCTest

@MainActor
final class RecipeDispositionTests: XCTestCase {
  func testDeletePreservesConcurrentSaveAndRestoreResolvesOnlyObservedDeletions() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let kitchen = Kitchen(name: "Disposition Kitchen")
    try repository.save(kitchen)
    let editor = RecipeEditor(repository: repository)
    let original = try editor.create(in: kitchen.id, from: RecipeDraft(title: "Soup"))
    let save = try editor.prepareSave(
      in: kitchen.id, from: RecipeDraft(title: "New soup"), original: original,
      observedSelectionIDs: repository.selectionHeads(for: original.id)
    )
    let deletion = RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: original.id)
    try repository.delete(deletion)
    try repository.delete(deletion)
    try repository.save(save)
    XCTAssertNil(try repository.recipe(id: original.id))
    XCTAssertEqual(try repository.revisions(for: original.id).count, 2)
    let deleted = try XCTUnwrap(repository.deletedRecipes(in: kitchen.id).first)
    XCTAssertEqual(deleted.observedDeletionIDs, [deletion.id])
    let restore = RecipeRestoreCommand(
      kitchenID: kitchen.id, recipeID: original.id,
      observedDeletionIDs: deleted.observedDeletionIDs
    )
    let concurrentDelete = RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: original.id)
    try repository.delete(concurrentDelete)
    try repository.restore(restore)
    try repository.restore(restore)
    XCTAssertNil(try repository.recipe(id: original.id))
    let remaining = try XCTUnwrap(repository.deletedRecipes(in: kitchen.id).first)
    XCTAssertEqual(remaining.observedDeletionIDs, [concurrentDelete.id])
    try repository.restore(RecipeRestoreCommand(
      kitchenID: kitchen.id, recipeID: original.id,
      observedDeletionIDs: remaining.observedDeletionIDs
    ))
    XCTAssertEqual(try repository.recipe(id: original.id)?.revision.title, "New soup")
    XCTAssertTrue(try repository.deletedRecipes(in: kitchen.id).isEmpty)
  }
  func testRetriedCommandsRejectChangedIdentityWithoutPartialRestoration() throws {
    let fixture = try fixture()
    let repository = fixture.repository
    let kitchen = fixture.kitchen
    let original = fixture.recipe
    let deletion = RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: original.id)
    try repository.delete(deletion)
    XCTAssertThrowsError(try repository.delete(RecipeDeleteCommand(
      id: deletion.id, kitchenID: kitchen.id, recipeID: original.id,
      deletedAt: deletion.deletedAt.addingTimeInterval(1)
    )))
    let restore = RecipeRestoreCommand(
      kitchenID: kitchen.id, recipeID: original.id, observedDeletionIDs: [deletion.id]
    )
    let encoded = try JSONEncoder().encode(restore)
    try repository.restore(JSONDecoder().decode(RecipeRestoreCommand.self, from: encoded))
    XCTAssertThrowsError(try repository.restore(RecipeRestoreCommand(
      kitchenID: kitchen.id, recipeID: original.id,
      restorations: restore.restorations, restoredAt: restore.restoredAt.addingTimeInterval(1)
    )))
    try repository.delete(deletion)
    XCTAssertNotNil(try repository.recipe(id: original.id))
    let second = RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: original.id)
    try repository.delete(second)
    let reused = try XCTUnwrap(restore.restorations.first)
    XCTAssertThrowsError(try repository.restore(RecipeRestoreCommand(
      kitchenID: kitchen.id, recipeID: original.id,
      restorations: [RecipeRestoration(id: reused.id, deletionID: second.id)], restoredAt: restore.restoredAt
    )))
    let other = try RecipeEditor(repository: repository).create(in: kitchen.id, from: RecipeDraft(title: "Stew"))
    let otherDelete = RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: other.id)
    try repository.delete(otherDelete)
    XCTAssertThrowsError(try repository.restore(RecipeRestoreCommand(
      kitchenID: kitchen.id, recipeID: other.id,
      restorations: [RecipeRestoration(id: reused.id, deletionID: otherDelete.id)], restoredAt: restore.restoredAt
    )))
    XCTAssertThrowsError(try repository.restore(RecipeRestoreCommand(
      kitchenID: kitchen.id, recipeID: original.id,
      restorations: [reused, RecipeRestoration(id: reused.id, deletionID: second.id)], restoredAt: restore.restoredAt
    )))
    for ids in [[], [second.id, second.id], [second.id, UUID()]] {
      XCTAssertThrowsError(try repository.restore(RecipeRestoreCommand(
        kitchenID: kitchen.id, recipeID: original.id, observedDeletionIDs: ids
      )))
    }
    XCTAssertEqual(try repository.deletedRecipes(in: kitchen.id).first { $0.id == original.id }?.observedDeletionIDs,
                   [second.id])
  }

  func testSaveBeforeDeleteAndDependentCookingSessionRemainUsable() throws {
    let fixture = try fixture()
    let repository = fixture.repository
    let kitchen = fixture.kitchen
    let original = fixture.recipe
    let sessionRepository = InMemoryCookingSessionRepository()
    let sessions = CookingSessions(
      kitchenID: kitchen.id, recipeRepository: repository, sessionRepository: sessionRepository
    )
    let start = StartCookingSessionIntention(
      sessionID: CookingSession.ID(), recipeID: original.id,
      recipeRevisionID: original.revision.id, startedAt: Date()
    )
    _ = try sessions.start(start)
    let before = try sessionRepository.evidence(id: start.sessionID)
    _ = try RecipeEditor(repository: repository).revise(
      recipeID: original.id, from: RecipeDraft(title: "Revised soup")
    )
    let one = RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: original.id)
    let two = RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: original.id)
    try repository.delete(one)
    try repository.delete(two)
    XCTAssertEqual(try sessionRepository.evidence(id: start.sessionID), before)
    let item = try XCTUnwrap(repository.deletedRecipes(in: kitchen.id).first)
    XCTAssertEqual(item.recoverableRecipe?.current.title, "Revised soup")
    XCTAssertEqual(Set(item.observedDeletionIDs), [one.id, two.id])
    try repository.restore(RecipeRestoreCommand(
      kitchenID: kitchen.id, recipeID: original.id, observedDeletionIDs: item.observedDeletionIDs
    ))
    XCTAssertNotNil(try repository.recipe(id: original.id))
    XCTAssertEqual(try sessionRepository.evidence(id: start.sessionID), before)
  }

  func testMissingRecipeAndForeignKitchenCannotBeDisposed() throws {
    let fixture = try fixture()
    let repository = fixture.repository
    let kitchen = fixture.kitchen
    let original = fixture.recipe
    let foreign = Kitchen(name: "Other Kitchen")
    try repository.save(foreign)
    for command in [
      RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: Recipe.ID()),
      RecipeDeleteCommand(kitchenID: foreign.id, recipeID: original.id),
    ] { XCTAssertThrowsError(try repository.delete(command)) }
    let deletion = RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: original.id)
    try repository.delete(deletion)
    XCTAssertThrowsError(try repository.restore(RecipeRestoreCommand(
      kitchenID: foreign.id, recipeID: original.id, observedDeletionIDs: [deletion.id]
    )))
    XCTAssertTrue(try repository.deletedRecipes(in: foreign.id).isEmpty)
  }

  func testDeletedIncompleteAndConflictingEvidenceDoesNotBreakLiveLibrary() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Kitchen")
    try repository.save(kitchen)
    let original = try RecipeEditor(repository: repository).create(
      in: kitchen.id, from: RecipeDraft(title: "Soup")
    )
    let context = ModelContext(container)
    let pendingID = Recipe.ID()
    context.insert(RecipeDeletionRecord(
      id: UUID(), recipeID: pendingID.rawValue, kitchenID: kitchen.id.rawValue
    ))
    try context.save()
    let pending = try XCTUnwrap(repository.deletedRecipes(in: kitchen.id).first)
    XCTAssertEqual(pending.authority, .unavailable(.noSaveEvidence))
    XCTAssertNil(pending.recoverableRecipe)
    XCTAssertThrowsError(try repository.delete(RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: pendingID)))
    let deletion = RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: original.id)
    try repository.delete(deletion)
    context.insert(RecipeDeletionRecord(
      id: deletion.id, recipeID: original.id.rawValue, kitchenID: kitchen.id.rawValue,
      deletedAt: deletion.deletedAt.addingTimeInterval(1)
    ))
    try context.save()
    XCTAssertTrue(try repository.recipes(in: kitchen.id).isEmpty)
    let conflicted = try XCTUnwrap(repository.deletedRecipes(in: kitchen.id).first { $0.id == original.id })
    XCTAssertEqual(conflicted.authority, .recovery(.commandCollision(deletion.id)))
    XCTAssertNil(conflicted.recoverableRecipe)
    XCTAssertThrowsError(try repository.restore(RecipeRestoreCommand(
      kitchenID: kitchen.id, recipeID: original.id, observedDeletionIDs: [deletion.id]
    )))
  }

  private struct Fixture {
    let repository: SwiftDataRecipeRepository
    let kitchen: Kitchen
    let recipe: StoredRecipe
  }

  private func fixture() throws -> Fixture {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let kitchen = Kitchen(name: "Disposition Kitchen")
    try repository.save(kitchen)
    let recipe = try RecipeEditor(repository: repository).create(
      in: kitchen.id, from: RecipeDraft(title: "Soup")
    )
    return Fixture(repository: repository, kitchen: kitchen, recipe: recipe)
  }

}
