// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import XCTest

@MainActor
final class CookingSessionsDispositionTests: XCTestCase {
  func testDeleteAndRestorePreserveLifecycleAndRemainRetrySafe() throws {
    let stored = makeStoredRecipe()
    let logic = CookingSessions(
      kitchenID: stored.recipe.kitchenID,
      recipeRepository: SessionRecipeRepository(stored: [stored]),
      sessionRepository: InMemoryCookingSessionRepository()
    )
    let sessionID = CookingSession.ID(rawValue: id(4))
    _ = try logic.start(StartCookingSessionIntention(
      sessionID: sessionID,
      recipeID: stored.recipe.id,
      recipeRevisionID: stored.revision.id,
      startedAt: Date(timeIntervalSince1970: 100)
    ))
    let deletion = DeleteCookingSessionIntention(
      deletionID: SessionDeletion.ID(rawValue: id(5)),
      sessionID: sessionID,
      deletedAt: Date(timeIntervalSince1970: 110)
    )
    let restore = RestoreCookingSessionIntention(
      id: .init(rawValue: id(6)),
      sessionID: sessionID,
      restoredAt: Date(timeIntervalSince1970: 120),
      observedDeletionIDs: [deletion.deletionID]
    )

    let deleted = try logic.perform(.delete(deletion))
    XCTAssertEqual(try logic.unresolvedDeletionIDs(for: sessionID), [deletion.deletionID])
    let deleteRetry = try logic.perform(.delete(deletion))
    let restored = try logic.perform(.restore(restore))
    XCTAssertTrue(try logic.unresolvedDeletionIDs(for: sessionID).isEmpty)
    let restoreRetry = try logic.perform(.restore(restore))

    XCTAssertEqual(accepted(deleted)?.disposition, .deleted(needsAttention: false))
    XCTAssertEqual(accepted(deleted)?.lifecycle, .active)
    XCTAssertEqual(deleteRetry, deleted)
    XCTAssertEqual(accepted(restored)?.disposition, .ordinary)
    XCTAssertEqual(accepted(restored)?.lifecycle, .active)
    XCTAssertEqual(restoreRetry, restored)
    let evidence = try XCTUnwrap(logic.sessionRepository.evidence(id: sessionID))
    XCTAssertTrue(logic.evidenceBelongsToKitchen(SessionEvidence(
      sessionID: sessionID,
      deletions: evidence.deletions
    )))
    XCTAssertTrue(logic.evidenceBelongsToKitchen(SessionEvidence(
      sessionID: sessionID,
      restorations: evidence.restorations
    )))
  }

  func testCompetingDeletionFrontierIsCompletelyRestored() throws {
    let stored = makeStoredRecipe()
    let repository = InMemoryCookingSessionRepository()
    let logic = CookingSessions(
      kitchenID: stored.recipe.kitchenID,
      recipeRepository: SessionRecipeRepository(stored: [stored]),
      sessionRepository: repository
    )
    let sessionID = CookingSession.ID(rawValue: id(14))
    _ = try logic.start(StartCookingSessionIntention(
      sessionID: sessionID,
      recipeID: stored.recipe.id,
      recipeRevisionID: stored.revision.id,
      startedAt: Date(timeIntervalSince1970: 100)
    ))
    for value in [15, 16] {
      _ = try logic.perform(.delete(DeleteCookingSessionIntention(
        deletionID: .init(rawValue: id(value)),
        sessionID: sessionID,
        deletedAt: Date(timeIntervalSince1970: TimeInterval(100 + value))
      )))
    }
    XCTAssertEqual(
      try logic.unresolvedDeletionIDs(for: sessionID),
      [15, 16].map { .init(rawValue: id($0)) }
    )
    let restored = try logic.perform(.restore(RestoreCookingSessionIntention(
      id: .init(rawValue: id(17)),
      sessionID: sessionID,
      restoredAt: Date(timeIntervalSince1970: 130),
      observedDeletionIDs: [15, 16].map { .init(rawValue: id($0)) }
    )))
    _ = try logic.perform(.delete(DeleteCookingSessionIntention(
      deletionID: .init(rawValue: id(18)),
      sessionID: sessionID,
      deletedAt: Date(timeIntervalSince1970: 140)
    )))
    XCTAssertEqual(
      try logic.unresolvedDeletionIDs(for: sessionID),
      [.init(rawValue: id(18))]
    )
    let restoredAgain = try logic.perform(.restore(RestoreCookingSessionIntention(
      id: .init(rawValue: id(19)),
      sessionID: sessionID,
      restoredAt: Date(timeIntervalSince1970: 150),
      observedDeletionIDs: [.init(rawValue: id(18))]
    )))

    XCTAssertEqual(accepted(restored)?.disposition, .ordinary)
    XCTAssertEqual(accepted(restoredAgain)?.disposition, .ordinary)
    XCTAssertEqual(try repository.evidence(id: sessionID)?.restorations.count, 3)
  }

  private func makeStoredRecipe() -> StoredRecipe {
    let kitchenID = Kitchen.ID(rawValue: id(1))
    let recipeID = Recipe.ID(rawValue: id(2))
    let revisionID = RecipeRevision.ID(rawValue: id(3))
    let revision = RecipeRevision(
      id: revisionID,
      recipeID: recipeID,
      revisionNumber: 1,
      title: "Soup"
    )
    return StoredRecipe(
      recipe: Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: revisionID),
      revision: revision
    )
  }

  private func accepted(_ result: CookingSessionCommandResult) -> CookingSessionProjection? {
    guard case let .accepted(session) = result else { return nil }
    return session
  }

  private func id(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0002-%012d", value))!
  }
}
