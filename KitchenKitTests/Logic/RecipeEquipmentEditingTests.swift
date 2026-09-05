// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import XCTest

@MainActor
final class RecipeEquipmentEditingTests: XCTestCase {
  func testEquipmentRoundTripsThroughEditingPersistenceAndImmutableHistory() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let kitchen = Kitchen(name: "Equipment Kitchen")
    try repository.save(kitchen)
    let editor = RecipeEditor(repository: repository)
    let equipment = [
      EquipmentItem(originalText: "2 large bowls", quantity: .init(
        kind: .exact, lowerBound: .init(numerator: 2)), name: "large bowls"),
      EquipmentItem(originalText: "something heavy to press it", name: "", isOptional: true),
    ]
    let first = try editor.create(in: kitchen.id, from: RecipeDraft(title: "Tofu", equipment: equipment))
    XCTAssertEqual(first.revision.equipment, equipment)
    var session = RecipeEditSession(draft: RecipeDraft(revision: first.revision))
    session.moveEquipment(at: 0, by: 1)
    session.moveEquipment(at: -1, by: 1)
    session.moveEquipment(at: 1, by: 1)
    session = try JSONDecoder().decode(RecipeEditSession.self, from: JSONEncoder().encode(session))
    let second = try editor.revise(recipeID: first.id, from: session.validatedDraft())
    XCTAssertEqual(second.revision.equipment.map(\.originalText), equipment.reversed().map(\.originalText))
    XCTAssertTrue(second.revision.equipment[0].isOptional)
    XCTAssertNil(second.revision.equipment[0].quantity)
    XCTAssertNotEqual(second.revision.equipment[0].id, equipment[1].id)
    XCTAssertEqual(try repository.recipe(id: first.id)?.revision.equipment, second.revision.equipment)
    XCTAssertEqual(try repository.revisions(for: first.id).last?.equipment, equipment)

    let cooking = CookingSessions(kitchenID: kitchen.id, recipeRepository: repository,
                                 sessionRepository: InMemoryCookingSessionRepository())
    let start = StartCookingSessionIntention(
      sessionID: CookingSession.ID(), recipeID: second.id,
      recipeRevisionID: second.revision.id, startedAt: Date()
    )
    guard case .accepted(let started) = try cooking.start(start) else {
      XCTFail("Expected an accepted Session")
      return
    }
    XCTAssertEqual(started.snapshot.equipment, second.revision.equipment)

    let legacy = try editor.revise(recipeID: first.id, from: RecipeDraft(title: "Legacy caller"))
    XCTAssertEqual(legacy.revision.equipment.map(\.originalText), second.revision.equipment.map(\.originalText))
    let empty = try editor.revise(recipeID: first.id, from: RecipeDraft(title: "No tools", equipment: []))
    XCTAssertTrue(empty.revision.equipment.isEmpty)
    XCTAssertEqual(started.snapshot.equipment, second.revision.equipment)
  }

  func testCleanupDropsOnlyEmptyRowsWithoutInventingQuantityOrWording() throws {
    var legacy = RecipeEditSession()
    legacy.moveEquipment(at: 0, by: 1)
    XCTAssertNil(legacy.equipment)
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let kitchen = Kitchen(name: "Equipment Kitchen")
    try repository.save(kitchen)
    let stored = try RecipeEditor(repository: repository).create(in: kitchen.id, from: RecipeDraft(
      title: "Toast", equipment: [
        EquipmentItem(originalText: " \n ", name: ""),
        EquipmentItem(originalText: "a pan, any size", name: ""),
        EquipmentItem(originalText: "", name: "  spatula  "),
        EquipmentItem(originalText: "", quantity: .init(kind: .text, text: "a few"), name: ""),
      ]
    ))
    XCTAssertEqual(stored.revision.equipment.map(\.originalText), ["a pan, any size", "", ""])
    XCTAssertEqual(stored.revision.equipment.map(\.name), ["", "spatula", ""])
    XCTAssertNil(stored.revision.equipment[0].quantity)
    XCTAssertEqual(stored.revision.equipment[2].quantity?.text, "a few")
  }
}
