// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import XCTest

@MainActor
final class CookingSessionsBoundaryTests: XCTestCase {
  func testStartIsRetrySafeAcrossBothSidesOfDurability() throws {
    for mode in BoundaryRepository.FailureMode.allCases {
      let fixture = BoundaryFixture(seed: 400 + mode.rawValue)
      fixture.repository.arm(mode)
      XCTAssertThrowsError(try fixture.logic.start(fixture.start)) {
        XCTAssertEqual($0 as? CookingSessionLogicError, .sessionWriteFailed)
      }
      assertAccepted(try fixture.logic.start(fixture.start))
      XCTAssertEqual(try fixture.repository.evidence(id: fixture.sessionID)?.roots.count, 1)
    }
  }

  func testAcceptedStartRetryDoesNotDependOnRecipeAvailability() throws {
    let fixture = BoundaryFixture(seed: 450)
    fixture.repository.arm(.after)
    assertWriteFailure { try fixture.logic.start(fixture.start) }
    fixture.recipes.readError = BoundaryError.injected

    assertAccepted(try fixture.logic.start(fixture.start))
    XCTAssertEqual(try fixture.repository.evidence(id: fixture.sessionID)?.roots.count, 1)
  }

  func testActivityAndFinishAreRetrySafeAcrossBothSidesOfDurability() throws {
    for mode in BoundaryRepository.FailureMode.allCases {
      let fixture = try BoundaryFixture.started(seed: 500 + mode.rawValue)
      let stop = fixture.fact(6)
      fixture.repository.arm(mode)
      assertWriteFailure { try fixture.logic.perform(.stop(stop)) }
      assertAccepted(try fixture.logic.perform(.stop(stop)))
      fixture.repository.arm(mode)
      let finish = fixture.finish(7)
      assertWriteFailure { try fixture.logic.perform(.finish(finish)) }
      assertAccepted(try fixture.logic.perform(.finish(finish)))
      let evidence = try fixture.repository.evidence(id: fixture.sessionID)
      XCTAssertEqual(evidence?.facts.count, 1)
      XCTAssertEqual(evidence?.closures.count, 1)
    }
  }

  func testFinishAndDeleteAreRetrySafeAcrossBothSidesOfDurability() throws {
    for mode in BoundaryRepository.FailureMode.allCases {
      let fixture = try BoundaryFixture.started(seed: 600 + mode.rawValue)
      let finish = fixture.finish(6, deletion: 7)
      fixture.repository.arm(mode)
      assertWriteFailure { try fixture.logic.perform(.finish(finish)) }
      assertAccepted(try fixture.logic.perform(.finish(finish)))
      let evidence = try fixture.repository.evidence(id: fixture.sessionID)
      XCTAssertEqual(evidence?.closures.count, 1)
      XCTAssertEqual(evidence?.deletions.count, 1)
    }
  }

  func testDeleteAndRestoreAreRetrySafeAcrossBothSidesOfDurability() throws {
    for mode in BoundaryRepository.FailureMode.allCases {
      let fixture = try BoundaryFixture.started(seed: 700 + mode.rawValue)
      let deletion = fixture.deletion(6)
      fixture.repository.arm(mode)
      assertWriteFailure { try fixture.logic.perform(.delete(deletion)) }
      assertAccepted(try fixture.logic.perform(.delete(deletion)))
      let restore = fixture.restore(7)
      fixture.repository.arm(mode)
      assertWriteFailure { try fixture.logic.perform(.restore(restore)) }
      assertAccepted(try fixture.logic.perform(.restore(restore)))
      let evidence = try fixture.repository.evidence(id: fixture.sessionID)
      XCTAssertEqual(evidence?.deletions.count, 1)
      XCTAssertEqual(evidence?.restorations.count, 1)
    }
  }

  func testClosureSelectionIsRetrySafeAcrossBothSidesOfDurability() throws {
    for mode in BoundaryRepository.FailureMode.allCases {
      let fixture = try BoundaryFixture.started(seed: 800 + mode.rawValue)
      let closures = try fixture.addCompetingClosures()
      let selection = ResolveCookingSessionClosureIntention(
        fact: fixture.fact(8),
        selectedClosureID: closures[0],
        observedClosureIDs: closures
      )
      fixture.repository.arm(mode)
      assertWriteFailure { try fixture.logic.perform(.resolveClosure(selection)) }
      assertAccepted(try fixture.logic.perform(.resolveClosure(selection)))
      XCTAssertEqual(try fixture.repository.evidence(id: fixture.sessionID)?.facts.count, 1)
    }
  }

  func testClosureSelectionDoesNotSilentlyAbsorbNewCompetition() throws {
    let fixture = try BoundaryFixture.started(seed: 850)
    let closures = try fixture.addCompetingClosures()
    let selection = ResolveCookingSessionClosureIntention(
      fact: fixture.fact(8),
      selectedClosureID: closures[0],
      observedClosureIDs: closures
    )
    fixture.repository.arm(.before)
    assertWriteFailure { try fixture.logic.perform(.resolveClosure(selection)) }
    _ = try fixture.addClosure(9)

    guard case .attention(.recovery) = try fixture.logic.perform(.resolveClosure(selection)) else {
      XCTFail("Expected new competing Closure evidence to require attention")
      return
    }
    XCTAssertTrue(try fixture.repository.evidence(id: fixture.sessionID)?.facts.isEmpty == true)
  }

  func testRestoreDoesNotSilentlyAbsorbNewDeletion() throws {
    let fixture = try BoundaryFixture.started(seed: 875)
    let first = fixture.deletion(6)
    _ = try fixture.logic.perform(.delete(first))
    let restore = fixture.restore(7)
    fixture.repository.arm(.before)
    assertWriteFailure { try fixture.logic.perform(.restore(restore)) }
    let second = fixture.deletion(8)
    _ = try fixture.logic.perform(.delete(second))

    let result = try fixture.logic.perform(.restore(restore))
    let observed = [first.deletionID, second.deletionID].sorted {
      $0.rawValue.uuidString < $1.rawValue.uuidString
    }
    XCTAssertEqual(result, .attention(.competingDeletions(observed)))
    XCTAssertTrue(try fixture.repository.evidence(id: fixture.sessionID)?.restorations.isEmpty == true)
  }

  func testContinuationIsRetrySafeAcrossBothSidesOfDurability() throws {
    for mode in BoundaryRepository.FailureMode.allCases {
      let fixture = try BoundaryFixture.started(seed: 900 + mode.rawValue)
      _ = try fixture.logic.perform(.finish(fixture.finish(6)))
      let continuedID = CookingSession.ID(rawValue: fixture.id(7))
      let intention = ContinueCookingSessionIntention(
        sessionID: continuedID,
        sourceSessionID: fixture.sessionID,
        startedAt: fixture.date(130)
      )
      fixture.repository.arm(mode)
      assertWriteFailure { try fixture.logic.perform(.continueSession(intention)) }
      assertAccepted(try fixture.logic.perform(.continueSession(intention)))
      XCTAssertEqual(try fixture.repository.evidence(id: continuedID)?.roots.count, 1)
    }
  }

  private func assertAccepted(
    _ result: CookingSessionCommandResult,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    guard case .accepted = result else {
      XCTFail("Expected accepted command", file: file, line: line)
      return
    }
  }

  private func assertWriteFailure(
    _ operation: () throws -> CookingSessionCommandResult,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(try operation(), file: file, line: line) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .sessionWriteFailed, file: file, line: line)
    }
  }
}

@MainActor
private final class BoundaryFixture {
  let repository = BoundaryRepository()
  let recipes: SessionRecipeRepository
  let logic: CookingSessions
  let sessionID: CookingSession.ID
  let start: StartCookingSessionIntention
  private let seed: Int

  init(seed: Int) {
    self.seed = seed
    let kitchenID = Kitchen.ID(rawValue: Self.id(seed + 1))
    let recipeID = Recipe.ID(rawValue: Self.id(seed + 2))
    let revisionID = RecipeRevision.ID(rawValue: Self.id(seed + 3))
    sessionID = CookingSession.ID(rawValue: Self.id(seed + 4))
    let stored = StoredRecipe(
      recipe: Recipe(id: recipeID, kitchenID: kitchenID, currentRevisionID: revisionID),
      revision: RecipeRevision(
        id: revisionID,
        recipeID: recipeID,
        revisionNumber: 1,
        title: "Soup"
      )
    )
    recipes = SessionRecipeRepository(stored: [stored])
    logic = CookingSessions(
      kitchenID: kitchenID,
      recipeRepository: recipes,
      sessionRepository: repository
    )
    start = StartCookingSessionIntention(
      sessionID: sessionID,
      recipeID: recipeID,
      recipeRevisionID: revisionID,
      startedAt: Date(timeIntervalSince1970: 100)
    )
  }

  static func started(seed: Int) throws -> BoundaryFixture {
    let fixture = BoundaryFixture(seed: seed)
    _ = try fixture.logic.start(fixture.start)
    return fixture
  }

  func fact(_ value: Int) -> SessionFactIntention {
    SessionFactIntention(id: .init(rawValue: id(value)), sessionID: sessionID, authoredAt: date(110))
  }

  func finish(_ value: Int, deletion: Int? = nil) -> FinishCookingSessionIntention {
    FinishCookingSessionIntention(
      closureID: .init(rawValue: id(value)),
      sessionID: sessionID,
      finishedAt: date(120),
      hasMeaningfulDraft: false,
      deletion: deletion.map { FinishSessionDeletion(id: .init(rawValue: id($0)), deletedAt: date(121)) }
    )
  }

  func deletion(_ value: Int) -> DeleteCookingSessionIntention {
    DeleteCookingSessionIntention(deletionID: .init(rawValue: id(value)), sessionID: sessionID, deletedAt: date(120))
  }

  func restore(_ value: Int) -> RestoreCookingSessionIntention {
    RestoreCookingSessionIntention(
      id: .init(rawValue: id(value)),
      sessionID: sessionID,
      restoredAt: date(130),
      observedDeletionIDs: [.init(rawValue: id(6))]
    )
  }

  func addCompetingClosures() throws -> [SessionClosure.ID] {
    _ = try logic.perform(.finish(finish(6)))
    let first = try XCTUnwrap(repository.evidence(id: sessionID)?.closures.first)
    let second = try addClosure(7)
    return [first.id, second].sorted { $0.rawValue.uuidString < $1.rawValue.uuidString }
  }

  func addClosure(_ value: Int) throws -> SessionClosure.ID {
    let first = try XCTUnwrap(repository.evidence(id: sessionID)?.closures.first)
    let second = SessionClosureEvidence(
      id: .init(rawValue: id(value)),
      sessionID: first.sessionID,
      kitchenID: first.kitchenID,
      finishedAt: date(121),
      causalHeadsFormatVersion: first.causalHeadsFormatVersion,
      causalHeadsData: first.causalHeadsData,
      snapshotFormatVersion: first.snapshotFormatVersion,
      snapshotDigest: first.snapshotDigest,
      projectionFormatVersion: first.projectionFormatVersion,
      projectionDigest: first.projectionDigest,
      outcomeFormatVersion: first.outcomeFormatVersion,
      outcomeData: first.outcomeData
    )
    try repository.append(.finish(second))
    return second.id
  }

  func id(_ value: Int) -> UUID { Self.id(seed + value) }
  func date(_ value: TimeInterval) -> Date { Date(timeIntervalSince1970: value) }

  private static func id(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0004-%012d", value))!
  }
}

@MainActor
private final class BoundaryRepository: CookingSessionRepository {
  enum FailureMode: Int, CaseIterable { case before = 1, after = 2 }

  private let base = InMemoryCookingSessionRepository()
  private var armed: FailureMode?

  func arm(_ mode: FailureMode) { armed = mode }

  func append(_ transaction: CookingSessionTransaction) throws {
    let mode = armed
    armed = nil
    if mode == .before { throw BoundaryError.injected }
    try base.append(transaction)
    if mode == .after { throw BoundaryError.injected }
  }

  func evidence(id: CookingSession.ID) throws -> SessionEvidence? { try base.evidence(id: id) }
  func session(id: CookingSession.ID) throws -> SessionProjectionResult? { try base.session(id: id) }
  func sessions(in id: Kitchen.ID) throws -> [SessionProjectionResult] { try base.sessions(in: id) }
  func sessions(for id: Recipe.ID) throws -> [SessionProjectionResult] { try base.sessions(for: id) }
  func sessions(for id: Recipe.ID, in kitchenID: Kitchen.ID) throws -> [SessionProjectionResult] {
    try base.sessions(for: id, in: kitchenID)
  }
  func finishedSessions(in id: Kitchen.ID, limit: Int) throws -> [SessionProjectionResult] {
    try base.finishedSessions(in: id, limit: limit)
  }
  func deletions(in id: Kitchen.ID) throws -> [SessionDeletionEvidence] { try base.deletions(in: id) }
  func deletions(for id: CookingSession.ID) throws -> [SessionDeletionEvidence] { try base.deletions(for: id) }
  func deletions(id: SessionDeletion.ID) throws -> [SessionDeletionEvidence] { try base.deletions(id: id) }
  func restorations(for id: SessionDeletion.ID) throws -> [SessionDeletionResolutionEvidence] {
    try base.restorations(for: id)
  }
}

private enum BoundaryError: Error { case injected }
