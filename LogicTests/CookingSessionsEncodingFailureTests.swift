// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemoryLogic
import KitchenMemoryDomain
import KitchenMemoryPersistence
import XCTest

@MainActor
final class CookingSessionsEncodingFailureTests: XCTestCase {
  func testSnapshotEncodingFailureRejectsStartBeforeDurability() throws {
    let fixture = EncodingFixture(seed: 1)
    let logic = fixture.logic(throwing: .snapshot)

    assertEncodingFailure { try logic.start(fixture.start()) }
    XCTAssertNil(try fixture.repository.evidence(id: fixture.sessionID))
  }

  func testFactEncodingFailureCoversNewCommandAndRetryComparison() throws {
    let fixture = EncodingFixture(seed: 20)
    let normal = fixture.logic()
    _ = try normal.start(fixture.start())
    let stop = fixture.fact(6)
    assertEncodingFailure { try fixture.logic(throwing: .fact).perform(.stop(stop)) }
    _ = try normal.perform(.stop(stop))
    assertEncodingFailure { try fixture.logic(throwing: .fact).perform(.stop(stop)) }
  }

  func testClosureProjectionAndOutcomeEncodingFailuresStayTyped() throws {
    let projection = EncodingFixture(seed: 40)
    _ = try projection.logic().start(projection.start())
    assertEncodingFailure {
      try projection.logic(throwing: .projection).perform(.finish(projection.finish(6)))
    }

    let outcome = EncodingFixture(seed: 60)
    let normal = outcome.logic()
    _ = try normal.start(outcome.start())
    _ = try normal.perform(.setOutcome(outcome.fact(6), .coarse(.okay)))
    assertEncodingFailure {
      try outcome.logic(throwing: .outcome).perform(.finish(outcome.finish(7)))
    }
  }

  func testContinuationSnapshotEncodingFailureDoesNotCreateRoot() throws {
    let fixture = EncodingFixture(seed: 80)
    let normal = fixture.logic()
    _ = try normal.start(fixture.start())
    _ = try normal.perform(.finish(fixture.finish(6)))
    let continuedID = CookingSession.ID(rawValue: fixture.id(7))
    let intention = ContinueCookingSessionIntention(
      sessionID: continuedID,
      sourceSessionID: fixture.sessionID,
      startedAt: Date(timeIntervalSince1970: 140)
    )

    assertEncodingFailure {
      try fixture.logic(throwing: .snapshot).perform(.continueSession(intention))
    }
    XCTAssertNil(try fixture.repository.evidence(id: continuedID))
  }

  private func assertEncodingFailure(
    _ operation: () throws -> CookingSessionCommandResult,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(try operation(), file: file, line: line) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .encodingFailed, file: file, line: line)
    }
  }
}

@MainActor
private final class EncodingFixture {
  let repository = InMemoryCookingSessionRepository()
  let sessionID: CookingSession.ID
  private let kitchenID: Kitchen.ID
  private let recipeID: Recipe.ID
  private let revisionID: RecipeRevision.ID
  private let recipes: SessionRecipeRepository
  private let seed: Int

  init(seed: Int) {
    self.seed = seed
    kitchenID = .init(rawValue: Self.id(seed + 1))
    recipeID = .init(rawValue: Self.id(seed + 2))
    revisionID = .init(rawValue: Self.id(seed + 3))
    sessionID = .init(rawValue: Self.id(seed + 4))
    recipes = SessionRecipeRepository(stored: [
      StoredRecipe(
        recipe: Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: revisionID),
        revision: RecipeRevision(
          id: revisionID,
          recipeID: recipeID,
          revisionNumber: 1,
          title: "Soup"
        )
      ),
    ])
  }

  func logic(throwing failure: EncodingFailure? = nil) -> CookingSessions {
    let encoding: any CookingSessionEncoding = failure.map(ThrowingSessionEncoding.init)
      ?? CanonicalCookingSessionEncoding()
    return CookingSessions(
      kitchenID: kitchenID,
      recipeRepository: recipes,
      sessionRepository: repository,
      encoding: encoding
    )
  }

  func start() -> StartCookingSessionIntention {
    StartCookingSessionIntention(
      sessionID: sessionID,
      recipeID: recipeID,
      recipeRevisionID: revisionID,
      startedAt: Date(timeIntervalSince1970: 100)
    )
  }

  func fact(_ value: Int) -> SessionFactIntention {
    SessionFactIntention(
      id: .init(rawValue: id(value)),
      sessionID: sessionID,
      authoredAt: Date(timeIntervalSince1970: 110)
    )
  }

  func finish(_ value: Int) -> FinishCookingSessionIntention {
    FinishCookingSessionIntention(
      closureID: .init(rawValue: id(value)),
      sessionID: sessionID,
      finishedAt: Date(timeIntervalSince1970: 130),
      hasMeaningfulDraft: false
    )
  }

  func id(_ value: Int) -> UUID { Self.id(seed + value) }

  private static func id(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0006-%012d", value))!
  }
}

private enum EncodingFailure { case snapshot, fact, projection, outcome }
private enum EncodingProbeError: Error { case injected }

private struct ThrowingSessionEncoding: CookingSessionEncoding {
  let failure: EncodingFailure
  private let canonical = CanonicalCookingSessionEncoding()

  func snapshot(_ value: ExecutionSnapshot) throws -> EncodedSessionValue {
    if failure == .snapshot { throw EncodingProbeError.injected }
    return try canonical.snapshot(value)
  }

  func fact(_ value: SessionFactPayload) throws -> EncodedSessionValue {
    if failure == .fact { throw EncodingProbeError.injected }
    return try canonical.fact(value)
  }

  func projection(_ value: ClosedSessionProjection) throws -> EncodedSessionValue {
    if failure == .projection { throw EncodingProbeError.injected }
    return try canonical.projection(value)
  }

  func outcome(_ value: SessionOutcome) throws -> EncodedSessionValue {
    if failure == .outcome { throw EncodingProbeError.injected }
    return try canonical.outcome(value)
  }
}
