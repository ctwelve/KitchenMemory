// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import XCTest

@MainActor
final class RecipeGalleryEditingTests: XCTestCase {
  func testGalleryOrderAndRemovalPreserveHeroIdentityAndImmutableHistory() throws {
    let repository = SwiftDataRecipeRepository(
      modelContainer: try KitchenMemorySchema.makeContainer(inMemory: true)
    )
    let kitchen = Kitchen(name: "Gallery Kitchen")
    try repository.save(kitchen)
    let editor = RecipeEditor(repository: repository)
    let hero = RecipeMedia(role: .hero, imageData: Data([1]))
    let firstImage = RecipeMedia(role: .gallery, imageData: Data([2]), accessibilityLabel: "Before cooking")
    let secondImage = RecipeMedia(role: .gallery, imageData: Data([3]), accessibilityLabel: "After cooking")
    let first = try editor.create(in: kitchen.id, from: RecipeDraft(
      title: "Soup", media: [hero, firstImage, secondImage]
    ))
    let cooking = CookingSessions(kitchenID: kitchen.id, recipeRepository: repository,
                                  sessionRepository: InMemoryCookingSessionRepository())
    let start = StartCookingSessionIntention(
      sessionID: CookingSession.ID(), recipeID: first.id,
      recipeRevisionID: first.revision.id, startedAt: Date(timeIntervalSince1970: 100)
    )
    guard case .accepted(let started) = try cooking.start(start) else {
      XCTFail("Expected an accepted Session")
      return
    }
    XCTAssertEqual(started.snapshot.media.map(\.sourceMediaID), [hero.id, firstImage.id, secondImage.id])
    var session = RecipeEditSession(draft: RecipeDraft(revision: first.revision))
    session.moveGalleryImage(at: 1, by: -1)
    session.moveGalleryImage(at: 0, by: -1)
    session.moveGalleryImage(at: -1, by: 1)
    session = try JSONDecoder().decode(RecipeEditSession.self, from: JSONEncoder().encode(session))
    let second = try editor.revise(recipeID: first.id, from: session.validatedDraft())
    XCTAssertEqual(second.revision.media, [hero, secondImage, firstImage])
    XCTAssertEqual(try repository.revisions(for: first.id).last?.media, [hero, firstImage, secondImage])
    session.removeMedia(id: firstImage.id)
    let third = try editor.revise(recipeID: first.id, from: session.validatedDraft())
    XCTAssertEqual(third.revision.media, [hero, secondImage])
    XCTAssertEqual(try repository.revisions(for: first.id)[1].media, [hero, secondImage, firstImage])
  }
  func testAddingGalleryImagesKeepsHeroAndAuthoredDescriptions() throws {
    let hero = RecipeMedia(role: .hero, imageData: Data([1]))
    var session = RecipeEditSession(draft: RecipeDraft(title: "Soup", media: [hero]))
    session.addGalleryImages([Data([2]), Data([3])])
    let gallery = try XCTUnwrap(session.media).filter { $0.role == .gallery }
    XCTAssertEqual(gallery.map(\.imageData), [Data([2]), Data([3])])
    XCTAssertNotEqual(gallery[0].id, gallery[1].id)
    session.setMediaDescription("Before cooking", for: gallery[0].id)
    XCTAssertEqual(session.media?.first, hero)
    XCTAssertEqual(session.media?[1].accessibilityLabel, "Before cooking")
  }

}
