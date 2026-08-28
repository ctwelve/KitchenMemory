// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemoryLogic
import KitchenMemoryDomain
import KitchenMemoryPersistence
import XCTest

@MainActor
final class CookingSessionsAdvancedCommandsTests: XCTestCase {
  func testFinishAndDeleteCrossOneAtomicBoundary() throws {
    let fixture = try SessionLogicFixture(seed: 100)
    let finish = FinishCookingSessionIntention(
      closureID: .init(rawValue: fixture.id(6)),
      sessionID: fixture.sessionID,
      finishedAt: fixture.date(120),
      hasMeaningfulDraft: false,
      deletion: FinishSessionDeletion(
        id: .init(rawValue: fixture.id(7)),
        deletedAt: fixture.date(121)
      )
    )

    let first = try fixture.logic.perform(.finish(finish))
    let retry = try fixture.logic.perform(.finish(finish))

    XCTAssertEqual(accepted(first)?.lifecycle, .finished)
    XCTAssertEqual(accepted(first)?.disposition, .deleted(needsAttention: false))
    XCTAssertEqual(retry, first)
    let evidence = try XCTUnwrap(fixture.repository.evidence(id: fixture.sessionID))
    XCTAssertTrue(fixture.logic.evidenceBelongsToKitchen(SessionEvidence(
      sessionID: fixture.sessionID,
      closures: evidence.closures
    )))
  }

  // swiftlint:disable:next function_body_length
  func testCompetingClosuresRequireAndAcceptCompleteSelection() throws {
    let fixture = try SessionLogicFixture(seed: 200)
    let first = try fixture.finish(id: 6, at: 120)
    let evidence = try XCTUnwrap(fixture.repository.evidence(id: fixture.sessionID))
    let closure = try XCTUnwrap(evidence.closures.first)
    let competing = SessionClosureEvidence(
      id: .init(rawValue: fixture.id(7)),
      sessionID: closure.sessionID,
      kitchenID: closure.kitchenID,
      finishedAt: fixture.date(121),
      causalHeadsFormatVersion: closure.causalHeadsFormatVersion,
      causalHeadsData: closure.causalHeadsData,
      snapshotFormatVersion: closure.snapshotFormatVersion,
      snapshotDigest: closure.snapshotDigest,
      projectionFormatVersion: closure.projectionFormatVersion,
      projectionDigest: closure.projectionDigest,
      outcomeFormatVersion: closure.outcomeFormatVersion,
      outcomeData: closure.outcomeData
    )
    let selection = ResolveCookingSessionClosureIntention(
      fact: fixture.fact(8, at: 130),
      selectedClosureID: first,
      observedClosureIDs: [first, competing.id]
    )
    XCTAssertThrowsError(try fixture.logic.perform(.resolveClosure(selection))) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .invalidIntention)
    }
    try fixture.repository.append(.finish(competing))
    guard case .recovery = try XCTUnwrap(fixture.logic.session(id: fixture.sessionID)) else {
      XCTFail("Expected competing Closure recovery")
      return
    }
    XCTAssertThrowsError(try fixture.logic.perform(.resolveClosure(
      ResolveCookingSessionClosureIntention(
        fact: fixture.fact(98, at: 129),
        selectedClosureID: first,
        observedClosureIDs: [first, .init(rawValue: fixture.id(99))]
      )
    ))) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .invalidIntention)
    }
    let result = try fixture.logic.perform(.resolveClosure(selection))
    let retry = try fixture.logic.perform(.resolveClosure(selection))
    XCTAssertThrowsError(try fixture.logic.perform(.resolveClosure(
      ResolveCookingSessionClosureIntention(
        fact: selection.fact,
        selectedClosureID: selection.selectedClosureID,
        observedClosureIDs: [first, .init(rawValue: fixture.id(99))]
      )
    ))) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .intentionIdentityCollision)
    }
    let third = SessionClosureEvidence(
      id: .init(rawValue: fixture.id(9)),
      sessionID: closure.sessionID,
      kitchenID: closure.kitchenID,
      finishedAt: fixture.date(140),
      causalHeadsFormatVersion: closure.causalHeadsFormatVersion,
      causalHeadsData: closure.causalHeadsData,
      snapshotFormatVersion: closure.snapshotFormatVersion,
      snapshotDigest: closure.snapshotDigest,
      projectionFormatVersion: closure.projectionFormatVersion,
      projectionDigest: closure.projectionDigest,
      outcomeFormatVersion: closure.outcomeFormatVersion,
      outcomeData: closure.outcomeData
    )
    try fixture.repository.append(.finish(third))
    let lateRetry = try fixture.logic.perform(.resolveClosure(selection))

    XCTAssertEqual(accepted(result)?.selectedClosureID, first)
    XCTAssertEqual(retry, result)
    guard case .attention(.recovery) = lateRetry else {
      XCTFail("Expected new competing evidence to remain visible")
      return
    }
    let root = try XCTUnwrap(fixture.repository.evidence(id: fixture.sessionID)?.roots.first)
    try fixture.repository.append(.start(CookingSessionRootEvidence(
      id: root.id,
      kitchenID: root.kitchenID,
      recipeID: root.recipeID,
      recipeRevisionID: root.recipeRevisionID,
      startedAt: fixture.date(999),
      snapshotFormatVersion: root.snapshotFormatVersion,
      snapshotData: root.snapshotData,
      snapshotDigest: root.snapshotDigest
    )))
    let recovery = try fixture.logic.perform(.resolveClosure(
      ResolveCookingSessionClosureIntention(
        fact: fixture.fact(10, at: 150),
        selectedClosureID: first,
        observedClosureIDs: [first, competing.id, third.id]
      )
    ))
    guard case .attention(.recovery) = recovery else {
      XCTFail("Expected unrelated Recovery to prevent Closure resolution")
      return
    }
  }

  func testContinuationCopiesFinishedStateIntoNewSelfContainedRoot() throws {
    let fixture = try SessionLogicFixture(seed: 300, withTargets: true)
    let started = try XCTUnwrap(accepted(fixture.started))
    let ingredient = started.snapshot.ingredientSections[0].ingredients[0].id
    let instruction = started.snapshot.instructionSections[0].steps[0].id
    _ = try fixture.logic.perform(.progress(
      fixture.fact(6, at: 110),
      SessionProgress(target: .ingredient(ingredient), state: .ingredient(.accounted))
    ))
    _ = try fixture.logic.perform(.submitEntry(
      fixture.fact(7, at: 111),
      text: "Keep this note",
      target: .ingredient(ingredient)
    ))
    _ = try fixture.logic.perform(.progress(
      fixture.fact(11, at: 112),
      SessionProgress(target: .instruction(instruction), state: .instruction(.completed))
    ))
    let sourceClosureID = try fixture.finish(id: 8, at: 120)
    let continuationID = CookingSession.ID(rawValue: fixture.id(9))
    let intention = ContinueCookingSessionIntention(
      sessionID: continuationID,
      sourceSessionID: fixture.sessionID,
      startedAt: fixture.date(130)
    )

    let first = try fixture.logic.perform(.continueSession(intention))
    let retry = try fixture.logic.perform(.continueSession(intention))

    let continued = try XCTUnwrap(accepted(first))
    XCTAssertEqual(continued.lifecycle, .active)
    XCTAssertEqual(continued.progress.count, 2)
    XCTAssertEqual(continued.entries.map(\.text), ["Keep this note"])
    XCTAssertEqual(retry, first)
    let root = try XCTUnwrap(fixture.repository.evidence(id: continuationID)?.roots.first)
    XCTAssertEqual(root.sourceSessionID, fixture.sessionID)
    XCTAssertEqual(root.sourceClosureID, sourceClosureID)
    XCTAssertNotNil(continued.snapshot.continuationBaseline)
    XCTAssertEqual(try fixture.logic.perform(.finish(
      FinishCookingSessionIntention(
        closureID: .init(rawValue: fixture.id(10)),
        sessionID: fixture.sessionID,
        finishedAt: fixture.date(140),
        hasMeaningfulDraft: false
      )
    )), .attention(.commandNotAllowed(lifecycle: .finished)))
    guard case let .session(source) = try XCTUnwrap(
      fixture.logic.session(id: fixture.sessionID)
    ) else {
      XCTFail("Expected immutable source Session")
      return
    }
    XCTAssertEqual(source.selectedClosureID, sourceClosureID)
    let sourceRoot = try XCTUnwrap(
      fixture.repository.evidence(id: fixture.sessionID)?.roots.first
    )
    try fixture.repository.append(.start(CookingSessionRootEvidence(
      id: sourceRoot.id,
      kitchenID: sourceRoot.kitchenID,
      recipeID: sourceRoot.recipeID,
      recipeRevisionID: sourceRoot.recipeRevisionID,
      startedAt: fixture.date(999),
      snapshotFormatVersion: sourceRoot.snapshotFormatVersion,
      snapshotData: sourceRoot.snapshotData,
      snapshotDigest: sourceRoot.snapshotDigest
    )))
    XCTAssertEqual(try fixture.logic.perform(.continueSession(intention)), first)
  }

  func testContinuationPreservesSourceRecoveryAttention() throws {
    let fixture = try SessionLogicFixture(seed: 350)
    _ = try fixture.finish(id: 6, at: 120)
    let sourceRoot = try XCTUnwrap(
      fixture.repository.evidence(id: fixture.sessionID)?.roots.first
    )
    try fixture.repository.append(.start(CookingSessionRootEvidence(
      id: sourceRoot.id,
      kitchenID: sourceRoot.kitchenID,
      recipeID: sourceRoot.recipeID,
      recipeRevisionID: sourceRoot.recipeRevisionID,
      startedAt: fixture.date(999),
      snapshotFormatVersion: sourceRoot.snapshotFormatVersion,
      snapshotData: sourceRoot.snapshotData,
      snapshotDigest: sourceRoot.snapshotDigest
    )))

    let result = try fixture.logic.perform(.continueSession(ContinueCookingSessionIntention(
      sessionID: .init(rawValue: fixture.id(7)),
      sourceSessionID: fixture.sessionID,
      startedAt: fixture.date(130)
    )))
    guard case .attention(.recovery) = result else {
      XCTFail("Expected source Recovery attention")
      return
    }
  }

  private func accepted(_ result: CookingSessionCommandResult) -> CookingSessionProjection? {
    guard case let .accepted(session) = result else { return nil }
    return session
  }
}

@MainActor
final class SessionLogicFixture {
  let seed: Int
  let sessionID: CookingSession.ID
  let repository = InMemoryCookingSessionRepository()
  let logic: CookingSessions
  let started: CookingSessionCommandResult

  // The rich source fixture keeps every continuation field in one construction.
  // swiftlint:disable:next function_body_length
  init(seed: Int, withTargets: Bool = false) throws {
    self.seed = seed
    let kitchenID = Kitchen.ID(rawValue: Self.id(seed + 1))
    let recipeID = Recipe.ID(rawValue: Self.id(seed + 2))
    let revisionID = RecipeRevision.ID(rawValue: Self.id(seed + 3))
    sessionID = CookingSession.ID(rawValue: Self.id(seed + 4))
    let revision = RecipeRevision(
      id: revisionID,
      recipeID: recipeID,
      revisionNumber: 1,
      title: "Soup",
      media: withTargets ? [
        RecipeMedia(
          id: .init(rawValue: Self.id(seed + 12)),
          role: .hero,
          assetName: "soup",
          accessibilityLabel: "Soup"
        ),
      ] : [],
      ingredientSections: withTargets ? [
        IngredientSection(ingredients: [
          RecipeIngredient(
            id: .init(rawValue: Self.id(seed + 5)),
            originalText: "stock",
            quantity: QuantityExpression(
              kind: .exact,
              lowerBound: RationalQuantity(numerator: 2)
            ),
            ingredientText: "stock",
            parseState: .reviewed
          ),
        ]),
      ] : [],
      instructionSections: withTargets ? [
        InstructionSection(steps: [
          InstructionStep(id: .init(rawValue: Self.id(seed + 13)), text: "Simmer."),
        ]),
      ] : []
    )
    let stored = StoredRecipe(
      recipe: Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: revisionID),
      revision: revision
    )
    logic = CookingSessions(
      kitchenID: kitchenID,
      recipeRepository: SessionRecipeRepository(stored: [stored]),
      sessionRepository: repository
    )
    started = try logic.start(StartCookingSessionIntention(
      sessionID: sessionID,
      recipeID: recipeID,
      recipeRevisionID: revisionID,
      startedAt: Date(timeIntervalSince1970: 100)
    ))
  }

  func fact(_ value: Int, at time: TimeInterval) -> SessionFactIntention {
    SessionFactIntention(
      id: .init(rawValue: id(value)),
      sessionID: sessionID,
      authoredAt: date(time)
    )
  }

  func finish(id value: Int, at time: TimeInterval) throws -> SessionClosure.ID {
    let identifier = SessionClosure.ID(rawValue: id(value))
    _ = try logic.perform(.finish(FinishCookingSessionIntention(
      closureID: identifier,
      sessionID: sessionID,
      finishedAt: date(time),
      hasMeaningfulDraft: false
    )))
    return identifier
  }

  func id(_ value: Int) -> UUID { Self.id(seed + value) }
  func date(_ value: TimeInterval) -> Date { Date(timeIntervalSince1970: value) }

  private static func id(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0003-%012d", value))!
  }
}
