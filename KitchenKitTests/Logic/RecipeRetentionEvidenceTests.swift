// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import SwiftData
import XCTest

@MainActor
final class RecipeRetentionEvidenceTests: XCTestCase {
  func testUnknownOrRecentDeletionDatesKeepPayloadRecoverable() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Kitchen")
    try repository.save(kitchen)
    let recipe = try RecipeEditor(repository: repository).create(in: kitchen.id, from: RecipeDraft(title: "Soup"))
    let replica = ModelContext(container)
    replica.insert(RecipeDeletionRecord(id: UUID(), recipeID: recipe.id.rawValue, kitchenID: kitchen.id.rawValue))
    try replica.save()
    XCTAssertTrue(try repository.maintainDeletedRecipes(in: kitchen.id, at: Date.distantFuture).prunedRecipeIDs.isEmpty)
    XCTAssertEqual(try repository.revisions(for: recipe.id).count, 1)
    XCTAssertTrue(try repository.recoveryRecipes(in: kitchen.id).isEmpty)
  }

  func testSharedSectionDependencyCannotBeRemovedWithDeletedRecipe() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Kitchen")
    try repository.save(kitchen)
    let editor = RecipeEditor(repository: repository)
    let ingredients = [IngredientSection(ingredients: [RecipeIngredient(originalText: "salt")])]
    let source = try editor.create(in: kitchen.id, from: RecipeDraft(title: "Soup", ingredientSections: ingredients))
    let live = try editor.create(in: kitchen.id, from: RecipeDraft(title: "Stew", ingredientSections: ingredients))
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    try repository.delete(RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: source.id,
                                              deletedAt: now.addingTimeInterval(-31 * 86_400)))
    XCTAssertTrue(try repository.maintainDeletedRecipes(in: kitchen.id, at: now).prunedRecipeIDs.isEmpty)
    XCTAssertEqual(try repository.recipe(id: live.id)?.revision.ingredientSections, live.revision.ingredientSections)
  }
  func testManifestBeforeSharedSectionPayloadStillRetainsItsDependency() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Kitchen")
    try repository.save(kitchen)
    let editor = RecipeEditor(repository: repository)
    let sections = [IngredientSection(ingredients: [RecipeIngredient(originalText: "salt")])]
    let source = try editor.create(in: kitchen.id, from: RecipeDraft(title: "Soup", ingredientSections: sections))
    let retained = try editor.create(in: kitchen.id, from: RecipeDraft(title: "Stew", ingredientSections: sections))
    let replica = ModelContext(container)
    let retainedRevision = retained.revision.id.rawValue
    for row in try replica.fetch(FetchDescriptor<IngredientSectionRecord>(
      predicate: #Predicate { $0.revisionID == retainedRevision }
    )) { replica.delete(row) }
    try replica.save()
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    try repository.delete(RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: source.id,
                                              deletedAt: now.addingTimeInterval(-31 * 86_400)))
    XCTAssertTrue(try repository.maintainDeletedRecipes(in: kitchen.id, at: now).prunedRecipeIDs.isEmpty)
    XCTAssertEqual(try repository.revisions(for: source.id).first?.ingredientSections,
                   source.revision.ingredientSections)
  }

  func testLateChildOnlyDeliveryKeepsTombstoneAndOffersRecovery() throws {
    let deliveries: [(ModelContext, StoredRecipe) -> Void] = [
      { $0.insert(RecipeImagePayloadRecord(revisionID: $1.revision.id.rawValue,
                                           mediaID: UUID(), imageData: Data([1, 2]))) },
      { $0.insert(RecipeMediaRecord(id: UUID(), revisionID: $1.revision.id.rawValue, sortIndex: 0, role: "hero",
                                    assetName: "image", accessibilityLabel: nil)) },
      { $0.insert(EquipmentRecord(id: UUID(), revisionID: $1.revision.id.rawValue, sortIndex: 0, originalText: "pot",
                                  quantityData: nil, name: "pot", isOptional: false)) },
      { $0.insert(IngredientSectionRecord(id: UUID(), revisionID: $1.revision.id.rawValue, sortIndex: 0, title: nil)) },
      { $0.insert(InstructionSectionRecord(id: UUID(), revisionID: $1.revision.id.rawValue,
                                           sortIndex: 0, title: nil)) },
      { $0.insert(RecipeDeletionRecord(id: UUID(), recipeID: $1.id.rawValue,
                                       kitchenID: $1.recipe.kitchenID.rawValue, deletedAt: Date())) },
      { $0.insert(RecipeDeletionResolutionRecord(id: UUID(), deletionID: UUID(), recipeID: $1.id.rawValue,
        kitchenID: $1.recipe.kitchenID.rawValue, restoredAt: Date())) },
    ]
    for delivery in deliveries { try assertLatePayloadRequiresRecovery(delivery) }
  }

  private func assertLatePayloadRequiresRecovery(_ delivery: (ModelContext, StoredRecipe) -> Void) throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Kitchen")
    try repository.save(kitchen)
    let recipe = try RecipeEditor(repository: repository).create(in: kitchen.id, from: RecipeDraft(title: "Soup"))
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    try repository.delete(RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: recipe.id,
                                              deletedAt: now.addingTimeInterval(-31 * 86_400)))
    _ = try repository.maintainDeletedRecipes(in: kitchen.id, at: now)
    let replica = ModelContext(container)
    delivery(replica, recipe)
    try replica.save()
    XCTAssertEqual(try repository.recipeAuthority(id: recipe.id), .recovery(.lateEvidenceAfterPrune))
    XCTAssertEqual(try repository.recoveryRecipes(in: kitchen.id).map(\.id), [recipe.id])
    XCTAssertTrue(try repository.deletedRecipes(in: kitchen.id).isEmpty)
    XCTAssertTrue(try repository.maintainDeletedRecipes(in: kitchen.id, at: now.addingTimeInterval(10 * 366 * 86_400))
      .expiredTombstoneRecipeIDs.isEmpty)
  }

  func testBatchExpirationAndRestorationHistoryRemainDeterministic() throws {
    let repository = SwiftDataRecipeRepository(modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true))
    let kitchen = Kitchen(name: "Kitchen")
    try repository.save(kitchen)
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    var ids: [Recipe.ID] = []
    for title in ["Soup", "Stew"] {
      let recipe = try RecipeEditor(repository: repository).create(in: kitchen.id, from: RecipeDraft(title: title,
        equipment: [EquipmentItem(originalText: "pot", name: "pot")],
        instructionSections: [InstructionSection(steps: [InstructionStep(text: "Stir")])]))
      ids.append(recipe.id)
      let deletion = RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: recipe.id,
                                         deletedAt: now.addingTimeInterval(-40 * 86_400))
      try repository.delete(deletion)
      try repository.restore(RecipeRestoreCommand(kitchenID: kitchen.id, recipeID: recipe.id,
                                                  observedDeletionIDs: [deletion.id]))
      try repository.delete(RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: recipe.id,
                                                deletedAt: now.addingTimeInterval(-31 * 86_400)))
    }
    XCTAssertEqual(Set(try repository.maintainDeletedRecipes(in: kitchen.id, at: now).prunedRecipeIDs), Set(ids))
    let expired = try repository.maintainDeletedRecipes(in: kitchen.id, at: now.addingTimeInterval(1_830 * 86_400))
    XCTAssertEqual(Set(expired.expiredTombstoneRecipeIDs), Set(ids))
  }

  func testUnownedSharedInstructionSectionBlocksPruningUntilItsOwnershipIsKnown() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Kitchen")
    try repository.save(kitchen)
    let section = InstructionSection(steps: [InstructionStep(text: "Stir")])
    let recipe = try RecipeEditor(repository: repository).create(in: kitchen.id,
      from: RecipeDraft(title: "Soup", instructionSections: [section]))
    let replica = ModelContext(container)
    replica.insert(InstructionSectionRecord(id: section.id.rawValue, revisionID: UUID(), sortIndex: 0, title: nil))
    try replica.save()
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    try repository.delete(RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: recipe.id,
                                              deletedAt: now.addingTimeInterval(-31 * 86_400)))
    XCTAssertTrue(try repository.maintainDeletedRecipes(in: kitchen.id, at: now).prunedRecipeIDs.isEmpty)
    XCTAssertEqual(try repository.revisions(for: recipe.id).first?.instructionSections, [section])
  }

  func testUnownedSharedIngredientSectionBlocksPruningUntilItsOwnershipIsKnown() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Kitchen")
    try repository.save(kitchen)
    let section = IngredientSection(ingredients: [RecipeIngredient(originalText: "salt")])
    let recipe = try RecipeEditor(repository: repository).create(in: kitchen.id,
      from: RecipeDraft(title: "Soup", ingredientSections: [section]))
    let replica = ModelContext(container)
    replica.insert(IngredientSectionRecord(id: section.id.rawValue, revisionID: UUID(), sortIndex: 0, title: nil))
    try replica.save()
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    try repository.delete(RecipeDeleteCommand(kitchenID: kitchen.id, recipeID: recipe.id,
                                              deletedAt: now.addingTimeInterval(-31 * 86_400)))
    XCTAssertTrue(try repository.maintainDeletedRecipes(in: kitchen.id, at: now).prunedRecipeIDs.isEmpty)
    XCTAssertEqual(try repository.revisions(for: recipe.id).first?.ingredientSections, [section])
  }

}
