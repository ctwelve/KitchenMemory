// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import SwiftData
import XCTest

@MainActor
final class RecipeMediaEditingTests: XCTestCase {
  func testHeroSurvivesDraftRelaunchAndRevisionReplacementWithoutChangingHistory() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let kitchen = Kitchen(name: "Media Kitchen")
    try repository.save(kitchen)
    let editor = RecipeEditor(repository: repository)
    let hero = RecipeMedia(role: .hero, imageData: Data([1, 2, 3]), accessibilityLabel: "A bowl of soup")
    var session = RecipeEditSession(draft: RecipeDraft(title: "Soup", media: [hero]))
    session = try JSONDecoder().decode(RecipeEditSession.self, from: JSONEncoder().encode(session))
    let first = try editor.create(in: kitchen.id, from: session.validatedDraft())
    XCTAssertEqual(try repository.recipe(id: first.id)?.revision.media, [hero])
    session.removeHeroImage()
    let second = try editor.revise(recipeID: first.id, from: session.validatedDraft())
    XCTAssertTrue(second.revision.media.isEmpty)
    XCTAssertEqual(try repository.revisions(for: first.id).last?.media, [hero])
  }
  func testMissingOrDamagedImageDoesNotHideRecipeAndLatePayloadRestoresImage() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Media Kitchen")
    try repository.save(kitchen)
    let hero = RecipeMedia(role: .hero, imageData: Data([4, 5, 6]))
    let stored = try RecipeEditor(repository: repository).create(
      in: kitchen.id, from: RecipeDraft(title: "Soup", media: [hero])
    )
    let context = ModelContext(container)
    let payload = try XCTUnwrap(context.fetch(FetchDescriptor<RecipeImagePayloadRecord>()).first)
    context.delete(payload)
    try context.save()
    let missing = try XCTUnwrap(repository.recipe(id: stored.id))
    XCTAssertEqual(missing.revision.title, "Soup")
    XCTAssertNil(missing.revision.media.first?.imageData)
    XCTAssertEqual(missing.revision.media.first?.id, hero.id)
    context.insert(RecipeImagePayloadRecord(
      revisionID: stored.revision.id.rawValue, mediaID: hero.id.rawValue, imageData: Data([9])
    ))
    try context.save()
    XCTAssertNil(try repository.recipe(id: stored.id)?.revision.media.first?.imageData)
    // A textual revision saved while the image is unavailable keeps the reference.
    _ = try RecipeEditor(repository: repository).revise(
      recipeID: stored.id, from: RecipeDraft(revision: missing.revision)
    )
    context.insert(RecipeImagePayloadRecord(
      revisionID: stored.revision.id.rawValue, mediaID: hero.id.rawValue, imageData: Data([4, 5, 6])
    ))
    try context.save()
    XCTAssertEqual(try repository.recipe(id: stored.id)?.revision.media, [hero])
  }

  func testExactSaveRetryRepairsMissingImageWithoutCreatingAnotherRevision() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = Kitchen(name: "Media Kitchen")
    try repository.save(kitchen)
    let hero = RecipeMedia(role: .hero, imageData: Data([7, 8]))
    let command = try RecipeEditor(repository: repository).prepareSave(
      in: kitchen.id, from: RecipeDraft(title: "Soup", media: [hero]),
      original: nil, observedSelectionIDs: []
    )
    try repository.save(command)
    let context = ModelContext(container)
    for payload in try context.fetch(FetchDescriptor<RecipeImagePayloadRecord>()) { context.delete(payload) }
    try context.save()
    try repository.save(command)
    XCTAssertEqual(try repository.revisions(for: command.recipe.id), [command.revision])
  }

  func testReplacingHeroPreservesGalleryAndSourceInEveryRetainedRevision() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let kitchen = Kitchen(name: "Media Kitchen")
    try repository.save(kitchen)
    let editor = RecipeEditor(repository: repository)
    let source = RecipeSource(kind: .book, title: "Synthetic cooking guide")
    let gallery = RecipeMedia(role: .gallery, imageData: Data([3]))
    var session = RecipeEditSession(draft: RecipeDraft(title: "Soup", source: source, media: [gallery]))
    session.replaceHeroImage(with: Data([1]))
    let first = try editor.create(in: kitchen.id, from: session.validatedDraft())
    let originalHero = try XCTUnwrap(first.revision.media.first { $0.role == .hero })
    session.replaceHeroImage(with: Data([2]))
    let replacement = try XCTUnwrap(session.media?.first { $0.role == .hero })
    session.setMediaDescription("Another bowl", for: replacement.id)
    let second = try editor.revise(recipeID: first.id, from: session.validatedDraft())
    XCTAssertNotEqual(replacement.id, originalHero.id)
    XCTAssertEqual(second.revision.media.first { $0.role == .hero }?.imageData, Data([2]))
    XCTAssertEqual(second.revision.media.first { $0.role == .hero }?.accessibilityLabel, "Another bowl")
    XCTAssertEqual(second.revision.media.filter { $0.role == .gallery }, [gallery])
    XCTAssertEqual(second.revision.source, source)
    XCTAssertEqual(try repository.revisions(for: first.id).last, first.revision)
  }

}
