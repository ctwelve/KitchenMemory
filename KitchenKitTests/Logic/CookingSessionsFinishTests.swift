// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import XCTest

@MainActor
final class CookingSessionsFinishTests: XCTestCase {
  func testFinishSealsTheObservedProjectionAndRetryRemainsImmutable() throws {
    let stored = makeStoredRecipe()
    let sessions = InMemoryCookingSessionRepository()
    let logic = CookingSessions(
      kitchenID: stored.recipe.kitchenID,
      recipeRepository: SessionRecipeRepository(stored: [stored]),
      sessionRepository: sessions
    )
    let sessionID = CookingSession.ID(rawValue: id(4))
    _ = try logic.start(StartCookingSessionIntention(
      sessionID: sessionID,
      recipeID: stored.recipe.id,
      recipeRevisionID: stored.revision.id,
      startedAt: Date(timeIntervalSince1970: 100)
    ))
    _ = try logic.perform(.setOutcome(
      SessionFactIntention(
        id: SessionFact.ID(rawValue: id(5)),
        sessionID: sessionID,
        authoredAt: Date(timeIntervalSince1970: 110)
      ),
      .coarse(.great)
    ))
    let finish = FinishCookingSessionIntention(
      closureID: SessionClosure.ID(rawValue: id(6)),
      sessionID: sessionID,
      finishedAt: Date(timeIntervalSince1970: 120),
      hasMeaningfulDraft: false
    )

    let first = try logic.perform(.finish(finish))
    let retry = try logic.perform(.finish(finish))

    XCTAssertEqual(accepted(first)?.lifecycle, .finished)
    XCTAssertEqual(accepted(first)?.lifecycleBeforeFinish, .active)
    XCTAssertEqual(accepted(first)?.outcome, .coarse(.great))
    XCTAssertEqual(retry, first)
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
    UUID(uuidString: String(format: "00000000-0000-0000-0001-%012d", value))!
  }
}
