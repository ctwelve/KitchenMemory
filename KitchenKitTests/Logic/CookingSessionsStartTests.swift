// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import XCTest

@MainActor
// The public command stories intentionally share one complete recipe fixture.
// swiftlint:disable:next type_body_length
final class CookingSessionsStartTests: XCTestCase {
  // swiftlint:disable:next function_body_length
  func testExplicitStartCapturesAnImmutableResumableSnapshot() throws {
    let ingredientID = RecipeIngredient.ID(rawValue: id(4))
    let instructionID = InstructionStep.ID(rawValue: id(5))
    let stored = makeStoredRecipe(ingredientID: ingredientID, instructionID: instructionID)
    let recipes = SessionRecipeRepository(stored: [stored])
    let sessions = InMemoryCookingSessionRepository()
    let logic = CookingSessions(
      kitchenID: stored.recipe.kitchenID,
      recipeRepository: recipes,
      sessionRepository: sessions
    )
    let intention = StartCookingSessionIntention(
      sessionID: CookingSession.ID(rawValue: id(6)),
      recipeID: stored.recipe.id,
      recipeRevisionID: stored.revision.id,
      startedAt: Date(timeIntervalSince1970: 100),
      workingScale: RecipeScale(
        baseYield: RationalQuantity(numerator: 2),
        workingYield: RationalQuantity(numerator: 4)
      )
    )

    XCTAssertNil(try logic.session(id: intention.sessionID))

    let result = try logic.start(intention)
    XCTAssertEqual(try logic.start(intention), result)

    guard case let .accepted(started) = result else {
      XCTFail("Expected a locally durable Session")
      return
    }
    XCTAssertEqual(started.lifecycle, .active)
    XCTAssertEqual(started.snapshot.title, "Soup")
    XCTAssertEqual(started.snapshot.ingredientSections[0].ingredients[0].sourceIngredientID, ingredientID)
    XCTAssertEqual(
      started.snapshot.instructionSections[0].steps[0].sourceInstructionID,
      instructionID
    )
    XCTAssertNotEqual(
      started.snapshot.ingredientSections[0].ingredients[0].id.rawValue,
      ingredientID.rawValue
    )
    XCTAssertEqual(
      started.snapshot.initialWorkingScale?.exactScale,
      RationalQuantity(numerator: 2)
    )
    XCTAssertEqual(
      started.snapshot.initialWorkingScale?.quantities[0].quantity.lowerBound,
      RationalQuantity(numerator: 4)
    )
    XCTAssertEqual(recipes.stored, [stored], "Starting must not revise the Recipe")

    let relaunched = CookingSessions(
      kitchenID: stored.recipe.kitchenID,
      recipeRepository: recipes,
      sessionRepository: sessions
    )
    guard case let .session(resumed) = try XCTUnwrap(relaunched.session(id: intention.sessionID)) else {
      XCTFail("Expected the durable Session to be immediately resumable")
      return
    }
    XCTAssertEqual(resumed, started)
  }

  func testStopResumeAndALateStopRetryRemainIdempotent() throws {
    let stored = makeStoredRecipe(
      ingredientID: RecipeIngredient.ID(rawValue: id(14)),
      instructionID: InstructionStep.ID(rawValue: id(15))
    )
    let logic = CookingSessions(
      kitchenID: stored.recipe.kitchenID,
      recipeRepository: SessionRecipeRepository(stored: [stored]),
      sessionRepository: InMemoryCookingSessionRepository()
    )
    let sessionID = CookingSession.ID(rawValue: id(16))
    _ = try logic.start(StartCookingSessionIntention(
      sessionID: sessionID,
      recipeID: stored.recipe.id,
      recipeRevisionID: stored.revision.id,
      startedAt: Date(timeIntervalSince1970: 100)
    ))
    let stop = SessionFactIntention(
      id: SessionFact.ID(rawValue: id(17)),
      sessionID: sessionID,
      authoredAt: Date(timeIntervalSince1970: 110)
    )
    let resume = SessionFactIntention(
      id: SessionFact.ID(rawValue: id(18)),
      sessionID: sessionID,
      authoredAt: Date(timeIntervalSince1970: 120)
    )

    assertLifecycle(try logic.perform(.stop(stop)), equals: .stopped)
    assertLifecycle(try logic.perform(.resume(resume)), equals: .active)
    assertLifecycle(try logic.perform(.stop(stop)), equals: .active)
  }

  // swiftlint:disable:next function_body_length
  func testActiveSessionAcceptsResultingProgressAndCompleteWorkingScale() throws {
    let stored = makeStoredRecipe(
      ingredientID: RecipeIngredient.ID(rawValue: id(24)),
      instructionID: InstructionStep.ID(rawValue: id(25))
    )
    let logic = CookingSessions(
      kitchenID: stored.recipe.kitchenID,
      recipeRepository: SessionRecipeRepository(stored: [stored]),
      sessionRepository: InMemoryCookingSessionRepository()
    )
    let sessionID = CookingSession.ID(rawValue: id(26))
    guard case let .accepted(started) = try logic.start(StartCookingSessionIntention(
      sessionID: sessionID,
      recipeID: stored.recipe.id,
      recipeRevisionID: stored.revision.id,
      startedAt: Date(timeIntervalSince1970: 100)
    )) else {
      XCTFail("Expected Start to succeed")
      return
    }
    let ingredient = started.snapshot.ingredientSections[0].ingredients[0].id
    let instruction = started.snapshot.instructionSections[0].steps[0].id

    let ingredientResult = try logic.perform(.progress(
      SessionFactIntention(
        id: SessionFact.ID(rawValue: id(27)),
        sessionID: sessionID,
        authoredAt: Date(timeIntervalSince1970: 110)
      ),
      SessionProgress(target: .ingredient(ingredient), state: .ingredient(.accounted))
    ))
    let instructionResult = try logic.perform(.progress(
      SessionFactIntention(
        id: SessionFact.ID(rawValue: id(28)),
        sessionID: sessionID,
        authoredAt: Date(timeIntervalSince1970: 120)
      ),
      SessionProgress(target: .instruction(instruction), state: .instruction(.skipped))
    ))
    let scale = SessionWorkingScale(
      workingYield: RecipeYield(originalText: "3 bowls"),
      exactScale: RationalQuantity(numerator: 3, denominator: 2),
      quantities: [
        SessionIngredientQuantity(
          ingredientID: ingredient,
          quantity: QuantityExpression(
            kind: .exact,
            lowerBound: RationalQuantity(numerator: 3)
          )
        ),
      ]
    )
    XCTAssertThrowsError(try logic.perform(.replaceWorkingScale(
      SessionFactIntention(
        id: SessionFact.ID(rawValue: id(30)),
        sessionID: sessionID,
        authoredAt: Date(timeIntervalSince1970: 125)
      ),
      SessionWorkingScale(workingYield: RecipeYield(originalText: "3 bowls"))
    ))) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .invalidIntention)
    }
    let scaleResult = try logic.perform(.replaceWorkingScale(
      SessionFactIntention(
        id: SessionFact.ID(rawValue: id(29)),
        sessionID: sessionID,
        authoredAt: Date(timeIntervalSince1970: 130)
      ),
      scale
    ))

    XCTAssertEqual(accepted(ingredientResult)?.progress.count, 1)
    XCTAssertEqual(accepted(instructionResult)?.progress.count, 2)
    XCTAssertEqual(accepted(scaleResult)?.workingScale, scale)
  }

  // swiftlint:disable:next function_body_length
  func testSessionEntryCanBeSubmittedRevisedRetargetedAndWithdrawn() throws {
    let stored = makeStoredRecipe(
      ingredientID: RecipeIngredient.ID(rawValue: id(34)),
      instructionID: InstructionStep.ID(rawValue: id(35))
    )
    let logic = CookingSessions(
      kitchenID: stored.recipe.kitchenID,
      recipeRepository: SessionRecipeRepository(stored: [stored]),
      sessionRepository: InMemoryCookingSessionRepository()
    )
    let sessionID = CookingSession.ID(rawValue: id(36))
    guard case let .accepted(started) = try logic.start(StartCookingSessionIntention(
      sessionID: sessionID,
      recipeID: stored.recipe.id,
      recipeRevisionID: stored.revision.id,
      startedAt: Date(timeIntervalSince1970: 100)
    )) else {
      XCTFail("Expected Start to succeed")
      return
    }
    let target = SessionProgressTarget.instruction(
      started.snapshot.instructionSections[0].steps[0].id
    )
    let submit = SessionFactIntention(
      id: SessionFact.ID(rawValue: id(37)),
      sessionID: sessionID,
      authoredAt: Date(timeIntervalSince1970: 110)
    )
    let entryID = SessionEntry.ID(rawValue: submit.id.rawValue)

    let submitted = try logic.perform(.submitEntry(submit, text: "  Less salt.  ", target: nil))
    let revised = try logic.perform(.reviseEntry(
      SessionFactIntention(
        id: SessionFact.ID(rawValue: id(38)),
        sessionID: sessionID,
        authoredAt: Date(timeIntervalSince1970: 120)
      ),
      entryID: entryID,
      text: "  Much less salt.  ",
      target: target
    ))
    let retargeted = try logic.perform(.retargetEntry(
      SessionFactIntention(
        id: SessionFact.ID(rawValue: id(39)),
        sessionID: sessionID,
        authoredAt: Date(timeIntervalSince1970: 130)
      ),
      entryID: entryID,
      target: nil
    ))
    let withdrawn = try logic.perform(.withdrawEntry(
      SessionFactIntention(
        id: SessionFact.ID(rawValue: id(40)),
        sessionID: sessionID,
        authoredAt: Date(timeIntervalSince1970: 140)
      ),
      entryID: entryID
    ))

    XCTAssertEqual(accepted(submitted)?.entries[0].text, "  Less salt.  ")
    XCTAssertEqual(accepted(revised)?.entries[0].target, target)
    XCTAssertEqual(accepted(revised)?.entries[0].text, "  Much less salt.  ")
    XCTAssertNil(accepted(retargeted)?.entries[0].target)
    XCTAssertEqual(accepted(retargeted)?.entries[0].text, "  Much less salt.  ")
    XCTAssertEqual(accepted(withdrawn)?.entries.isEmpty, true)
  }

  func testSessionOutcomeCanBeSetChangedAndCleared() throws {
    let stored = makeStoredRecipe(
      ingredientID: RecipeIngredient.ID(rawValue: id(44)),
      instructionID: InstructionStep.ID(rawValue: id(45))
    )
    let logic = CookingSessions(
      kitchenID: stored.recipe.kitchenID,
      recipeRepository: SessionRecipeRepository(stored: [stored]),
      sessionRepository: InMemoryCookingSessionRepository()
    )
    let sessionID = CookingSession.ID(rawValue: id(46))
    _ = try logic.start(StartCookingSessionIntention(
      sessionID: sessionID,
      recipeID: stored.recipe.id,
      recipeRevisionID: stored.revision.id,
      startedAt: Date(timeIntervalSince1970: 100)
    ))

    let first = try logic.perform(.setOutcome(fact(47, sessionID: sessionID), .coarse(.great)))
    let changed = try logic.perform(.setOutcome(
      fact(48, sessionID: sessionID),
      .coarse(.unsuccessful)
    ))
    let cleared = try logic.perform(.clearOutcome(fact(49, sessionID: sessionID)))

    XCTAssertEqual(accepted(first)?.outcome, .coarse(.great))
    XCTAssertEqual(accepted(changed)?.outcome, .coarse(.unsuccessful))
    XCTAssertNil(accepted(cleared)?.outcome)
  }

  private func makeStoredRecipe(
    ingredientID: RecipeIngredient.ID,
    instructionID: InstructionStep.ID
  ) -> StoredRecipe {
    let kitchenID = Kitchen.ID(rawValue: id(1))
    let recipeID = Recipe.ID(rawValue: id(2))
    let revisionID = RecipeRevision.ID(rawValue: id(3))
    let revision = RecipeRevision(
      id: revisionID,
      recipeID: recipeID,
      revisionNumber: 1,
      title: "Soup",
      recipeYield: RecipeYield(
        quantity: QuantityExpression(
          kind: .exact,
          lowerBound: RationalQuantity(numerator: 2)
        ),
        unitText: "bowls",
        originalText: "2 bowls"
      ),
      media: [RecipeMedia(role: .hero, assetName: "soup", accessibilityLabel: "Soup")],
      equipment: [EquipmentItem(originalText: "1 pot", name: "pot")],
      ingredientSections: [
        IngredientSection(
          title: "Soup",
          ingredients: [
            RecipeIngredient(
              id: ingredientID,
              originalText: "2 cups stock",
              quantity: QuantityExpression(
                kind: .exact,
                lowerBound: RationalQuantity(numerator: 2)
              ),
              unitText: "cups",
              ingredientText: "stock",
              parseState: .reviewed
            ),
          ]
        ),
      ],
      instructionSections: [
        InstructionSection(steps: [InstructionStep(id: instructionID, text: "Simmer.")]),
      ]
    )
    return StoredRecipe(
      recipe: Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: revisionID),
      revision: revision
    )
  }

  private func id(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
  }

  private func assertLifecycle(
    _ result: CookingSessionCommandResult,
    equals expected: SessionLifecycle,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    guard case let .accepted(session) = result else {
      XCTFail("Expected an accepted Session command", file: file, line: line)
      return
    }
    XCTAssertEqual(session.lifecycle, expected, file: file, line: line)
  }

  private func accepted(_ result: CookingSessionCommandResult) -> CookingSessionProjection? {
    guard case let .accepted(session) = result else { return nil }
    return session
  }

  private func fact(_ value: Int, sessionID: CookingSession.ID) -> SessionFactIntention {
    SessionFactIntention(
      id: SessionFact.ID(rawValue: id(value)),
      sessionID: sessionID,
      authoredAt: Date(timeIntervalSince1970: TimeInterval(100 + value))
    )
  }
}

@MainActor
final class SessionRecipeRepository: RecipeRepository {
  var stored: [StoredRecipe]
  var readError: Error?

  init(stored: [StoredRecipe], readError: Error? = nil) {
    self.stored = stored
    self.readError = readError
  }

  func save(_ kitchen: Kitchen) throws {}
  func create(_ kitchen: Kitchen, with recipes: [StoredRecipe]) throws { stored = recipes }
  func save(recipe: Recipe, revision: RecipeRevision) throws {
    stored.append(StoredRecipe(recipe: recipe, revision: revision))
  }
  func kitchens() throws -> [Kitchen] { [] }
  func kitchen(id: Kitchen.ID) throws -> Kitchen? { nil }
  func recipe(id: Recipe.ID) throws -> StoredRecipe? {
    if let readError { throw readError }
    return stored.first { $0.id == id }
  }
  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] {
    stored.filter { $0.recipe.kitchenID == kitchenID }
  }
  func addRecipes(_ recipes: [StoredRecipe], to kitchenID: Kitchen.ID) throws {
    stored += recipes
  }
  func revisions(for recipeID: Recipe.ID) throws -> [RecipeRevision] {
    if let readError { throw readError }
    return stored.filter { $0.id == recipeID }.map(\.revision)
  }
  func replaceRecipes(in kitchenID: Kitchen.ID, with recipes: [StoredRecipe]) throws {
    stored = recipes
  }
}
