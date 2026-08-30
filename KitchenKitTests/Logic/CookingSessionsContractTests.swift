// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenKit
import XCTest

// Contract matrices keep typed outcomes beside the operation that produces them.
// swiftlint:disable file_length

@MainActor
// swiftlint:disable:next type_body_length
final class CookingSessionsContractTests: XCTestCase {
  func testStartReturnsTypedRecipeAndSnapshotFailuresWithoutCreatingHistory() throws {
    let stored = recipe(seed: 1)
    let repository = InMemoryCookingSessionRepository()
    let missing = CookingSessions(
      kitchenID: stored.recipe.kitchenID,
      recipeRepository: SessionRecipeRepository(stored: []),
      sessionRepository: repository
    )
    XCTAssertThrowsError(try missing.start(start(stored, session: 10))) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .recipeNotFound)
    }
    let otherKitchen = CookingSessions(
      kitchenID: .init(rawValue: id(99)),
      recipeRepository: SessionRecipeRepository(stored: [stored]),
      sessionRepository: repository
    )
    XCTAssertThrowsError(try otherKitchen.start(start(stored, session: 11))) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .recipeOutsideKitchen)
    }
    var wrongRevision = start(stored, session: 12)
    wrongRevision = StartCookingSessionIntention(
      sessionID: wrongRevision.sessionID,
      recipeID: wrongRevision.recipeID,
      recipeRevisionID: .init(rawValue: id(98)),
      startedAt: wrongRevision.startedAt
    )
    let logic = sessions(stored, repository: repository)
    XCTAssertThrowsError(try logic.start(wrongRevision)) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .recipeRevisionNotFound)
    }
    let blank = recipe(seed: 20, title: "   ")
    XCTAssertThrowsError(try sessions(blank, repository: repository).start(start(blank, session: 13))) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .insufficientSnapshot)
    }
    XCTAssertNil(try repository.evidence(id: CookingSession.ID(rawValue: id(13))))
  }

  func testReadFailuresAndReusedIdentitiesReturnTypedFailures() throws {
    let stored = recipe(seed: 40)
    let recipeFailure = CookingSessions(
      kitchenID: stored.recipe.kitchenID,
      recipeRepository: SessionRecipeRepository(stored: [stored], readError: ProbeError.read),
      sessionRepository: InMemoryCookingSessionRepository()
    )
    XCTAssertThrowsError(try recipeFailure.start(start(stored, session: 50))) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .recipeReadFailed)
    }
    let failing = ReadFailureCookingSessionRepository()
    let logic = CookingSessions(
      kitchenID: stored.recipe.kitchenID,
      recipeRepository: SessionRecipeRepository(stored: [stored]),
      sessionRepository: failing
    )
    XCTAssertThrowsError(try logic.session(id: .init(rawValue: id(51)))) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .sessionReadFailed)
    }
    XCTAssertThrowsError(try logic.sessions()) { assertSessionReadFailure($0) }
    XCTAssertThrowsError(try logic.sessions(for: stored.recipe.id)) { assertSessionReadFailure($0) }
    XCTAssertThrowsError(try logic.finishedSessions(limit: 1)) { assertSessionReadFailure($0) }
    XCTAssertThrowsError(try logic.perform(.stop(SessionFactIntention(
      id: .init(rawValue: id(501)),
      sessionID: .init(rawValue: id(502)),
      authoredAt: Date(timeIntervalSince1970: 100)
    )))) { assertSessionReadFailure($0) }

    let repository = InMemoryCookingSessionRepository()
    let working = sessions(stored, repository: repository)
    let original = start(stored, session: 52)
    _ = try working.start(original)
    let changed = StartCookingSessionIntention(
      sessionID: original.sessionID,
      recipeID: original.recipeID,
      recipeRevisionID: original.recipeRevisionID,
      startedAt: Date(timeIntervalSince1970: 999)
    )
    XCTAssertThrowsError(try working.start(changed)) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .intentionIdentityCollision)
    }
    XCTAssertThrowsError(try working.perform(.stop(fact(
      53,
      sessionID: .init(rawValue: id(999))
    )))) { assertSessionReadFailure($0) }

    for mode in ClassifiedReadRepository.Mode.allCases {
      let classified = ClassifiedReadRepository(mode: mode)
      let command = sessions(stored, repository: classified)
      XCTAssertThrowsError(try command.start(start(stored, session: 54 + mode.rawValue))) {
        assertSessionReadFailure($0)
      }
    }
  }

  func testLifecycleDraftAndInvalidIntentionsAreRejectedBeforeAppend() throws {
    let stored = recipe(seed: 60, withIngredient: true)
    let repository = InMemoryCookingSessionRepository()
    let logic = sessions(stored, repository: repository)
    let sessionID = CookingSession.ID(rawValue: id(70))
    let started = try accepted(logic.start(start(stored, session: 70)))
    let ingredient = started.snapshot.ingredientSections[0].ingredients[0].id
    let progress = SessionProgress(target: .ingredient(ingredient), state: .ingredient(.open))
    XCTAssertThrowsError(try logic.perform(.progress(
      fact(77, sessionID: sessionID),
      SessionProgress(target: .ingredient(ingredient), state: .instruction(.completed))
    ))) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .invalidIntention)
    }
    _ = try logic.perform(.stop(fact(71, sessionID: sessionID)))
    XCTAssertEqual(
      try logic.perform(.progress(fact(72, sessionID: sessionID), progress)),
      .attention(.commandNotAllowed(lifecycle: .stopped))
    )
    XCTAssertEqual(
      try logic.perform(.finish(FinishCookingSessionIntention(
        closureID: .init(rawValue: id(73)),
        sessionID: sessionID,
        finishedAt: Date(timeIntervalSince1970: 130),
        hasMeaningfulDraft: true
      ))),
      .attention(.meaningfulDraft)
    )
    _ = try logic.perform(.resume(fact(75, sessionID: sessionID)))
    _ = try logic.perform(.replaceWorkingScale(
      fact(76, sessionID: sessionID),
      SessionWorkingScale(workingYield: RecipeYield(originalText: "custom"))
    ))
    XCTAssertThrowsError(try logic.perform(.replaceWorkingScale(
      fact(78, sessionID: sessionID),
      SessionWorkingScale(exactScale: RationalQuantity(numerator: 0))
    ))) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .invalidIntention)
    }
    XCTAssertThrowsError(try logic.perform(.submitEntry(
      fact(74, sessionID: sessionID),
      text: "",
      target: nil
    ))) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .invalidIntention)
    }
  }

  func testClassifiedQueriesRemainKitchenAndRecipeScoped() throws {
    let stored = recipe(seed: 80)
    let foreign = recipe(seed: 180)
    let repository = InMemoryCookingSessionRepository()
    let recipes = SessionRecipeRepository(stored: [stored, foreign])
    let logic = CookingSessions(
      kitchenID: stored.recipe.kitchenID,
      recipeRepository: recipes,
      sessionRepository: repository
    )
    let foreignLogic = CookingSessions(
      kitchenID: foreign.recipe.kitchenID,
      recipeRepository: recipes,
      sessionRepository: repository
    )
    let first = start(stored, session: 90)
    let second = start(stored, session: 91)
    _ = try logic.start(first)
    _ = try logic.start(second)
    let foreignStart = start(foreign, session: 192)
    _ = try foreignLogic.start(foreignStart)
    _ = try logic.perform(.finish(FinishCookingSessionIntention(
      closureID: .init(rawValue: id(92)),
      sessionID: first.sessionID,
      finishedAt: Date(timeIntervalSince1970: 200),
      hasMeaningfulDraft: false
    )))

    XCTAssertEqual(try logic.sessions().count, 2)
    XCTAssertEqual(try logic.sessions(for: stored.recipe.id).count, 2)
    XCTAssertNil(try logic.session(id: foreignStart.sessionID))
    XCTAssertTrue(try logic.sessions(for: foreign.recipe.id).isEmpty)
    XCTAssertThrowsError(try logic.perform(.stop(fact(
      193,
      sessionID: foreignStart.sessionID
    )))) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .sessionOutsideKitchen)
    }
    XCTAssertEqual(try foreignLogic.sessions().count, 1)
    XCTAssertEqual(try logic.finishedSessions(limit: 1).count, 1)
    XCTAssertTrue(try logic.finishedSessions(limit: 0).isEmpty)

    let contaminated = start(stored, session: 194)
    _ = try logic.start(contaminated)
    try repository.append(.activity(try rawFact(
      id: 195,
      sessionID: contaminated.sessionID,
      kitchenID: foreign.recipe.kitchenID,
      heads: [contaminated.sessionID.rawValue],
      payload: .empty,
      kind: .stop
    )))
    guard case .recovery = try XCTUnwrap(logic.session(id: contaminated.sessionID)) else {
      XCTFail("Expected mixed-Kitchen evidence to remain visible as Recovery")
      return
    }
    XCTAssertEqual(try logic.sessions(for: stored.recipe.id).count, 3)
    guard case .attention(.recovery) = try logic.perform(.stop(fact(
      196,
      sessionID: contaminated.sessionID
    ))) else {
      XCTFail("Expected commands to preserve mixed-Kitchen Recovery")
      return
    }
  }

  // swiftlint:disable:next function_body_length
  func testUnavailableRecoveryAndConflictsRemainTypedAttention() throws {
    let stored = recipe(seed: 100, withIngredient: true)
    let repository = InMemoryCookingSessionRepository()
    let logic = sessions(stored, repository: repository)
    let missingRootID = CookingSession.ID(rawValue: id(110))
    try repository.append(.activity(try rawFact(
      id: 111,
      sessionID: missingRootID,
      kitchenID: stored.recipe.kitchenID,
      heads: [],
      payload: .empty,
      kind: .stop
    )))
    let unavailable = try logic.perform(.resume(fact(112, sessionID: missingRootID)))
    guard case .attention(.unavailable) = unavailable else {
      XCTFail("Expected Unavailable attention")
      return
    }
    XCTAssertEqual(
      try logic.classifiedResult(id: missingRootID),
      unavailable
    )

    let collisionID = CookingSession.ID(rawValue: id(113))
    let ordinary = try logic.start(start(stored, session: 113))
    guard case let .accepted(ordinarySession) = ordinary else {
      XCTFail("Expected ordinary Session")
      return
    }
    XCTAssertEqual(
      logic.attention(from: .session(ordinarySession)),
      ordinary
    )
    let root = try XCTUnwrap(repository.evidence(id: collisionID)?.roots.first)
    try repository.append(.start(CookingSessionRootEvidence(
      id: root.id,
      kitchenID: root.kitchenID,
      recipeID: root.recipeID,
      recipeRevisionID: root.recipeRevisionID,
      startedAt: Date(timeIntervalSince1970: 999),
      snapshotFormatVersion: root.snapshotFormatVersion,
      snapshotData: root.snapshotData,
      snapshotDigest: root.snapshotDigest
    )))
    let recovery = try logic.perform(.stop(fact(114, sessionID: collisionID)))
    guard case .attention(.recovery) = recovery else {
      XCTFail("Expected Recovery attention")
      return
    }

    let conflictID = CookingSession.ID(rawValue: id(115))
    let projected = try accepted(logic.start(start(stored, session: 115)))
    let target = projected.snapshot.ingredientSections[0].ingredients[0].id
    let heads = [conflictID.rawValue]
    try repository.append(.activity(try rawFact(
      id: 116,
      sessionID: conflictID,
      kitchenID: stored.recipe.kitchenID,
      heads: heads,
      payload: .progress(.ingredient(.accounted)),
      kind: .progress,
      target: target.rawValue
    )))
    try repository.append(.activity(try rawFact(
      id: 117,
      sessionID: conflictID,
      kitchenID: stored.recipe.kitchenID,
      heads: heads,
      payload: .progress(.ingredient(.open)),
      kind: .progress,
      target: target.rawValue
    )))
    let finish = try logic.perform(.finish(FinishCookingSessionIntention(
      closureID: .init(rawValue: id(118)),
      sessionID: conflictID,
      finishedAt: Date(timeIntervalSince1970: 200),
      hasMeaningfulDraft: false
    )))
    guard case .attention(.conflicts) = finish else {
      XCTFail("Expected conflict attention")
      return
    }
  }

  func testCommandIdentityAndSelectionValidationRejectSemanticReuse() throws {
    let stored = recipe(seed: 120)
    let logic = sessions(stored, repository: InMemoryCookingSessionRepository())
    let sessionID = CookingSession.ID(rawValue: id(130))
    _ = try logic.start(start(stored, session: 130))
    let stop = fact(131, sessionID: sessionID)
    _ = try logic.perform(.stop(stop))
    XCTAssertThrowsError(try logic.perform(.resume(stop))) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .intentionIdentityCollision)
    }
    XCTAssertThrowsError(try logic.perform(.resolveClosure(
      ResolveCookingSessionClosureIntention(
        fact: fact(132, sessionID: sessionID),
        selectedClosureID: .init(rawValue: id(133)),
        observedClosureIDs: []
      )
    ))) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .invalidIntention)
    }
    XCTAssertEqual(
      try logic.perform(.continueSession(ContinueCookingSessionIntention(
        sessionID: .init(rawValue: id(134)),
        sourceSessionID: sessionID,
        startedAt: Date(timeIntervalSince1970: 200)
      ))),
      .attention(.commandNotAllowed(lifecycle: .stopped))
    )
  }

  // swiftlint:disable:next function_body_length
  func testRetargetAndTerminalRetriesCoverConflictAndCollisionEdges() throws {
    let stored = recipe(seed: 140, withIngredient: true)
    let repository = InMemoryCookingSessionRepository()
    let logic = sessions(stored, repository: repository)
    let sessionID = CookingSession.ID(rawValue: id(150))
    let started = try accepted(logic.start(start(stored, session: 150)))
    let submit = fact(151, sessionID: sessionID)
    _ = try logic.perform(.submitEntry(submit, text: "note", target: nil))
    let retarget = fact(152, sessionID: sessionID)
    let entryID = SessionEntry.ID(rawValue: submit.id.rawValue)
    let equivalentRevision = try logic.perform(.reviseEntry(
      retarget,
      entryID: entryID,
      text: "note",
      target: nil
    ))
    let first = try logic.perform(.retargetEntry(retarget, entryID: entryID, target: nil))
    XCTAssertEqual(first, equivalentRevision)
    let ingredient = started.snapshot.ingredientSections[0].ingredients[0].id
    XCTAssertThrowsError(try logic.perform(.retargetEntry(
      retarget,
      entryID: entryID,
      target: .ingredient(ingredient)
    ))) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .intentionIdentityCollision)
    }
    XCTAssertEqual(try logic.perform(.retargetEntry(
      retarget,
      entryID: entryID,
      target: nil
    )), first)
    XCTAssertThrowsError(try logic.perform(.retargetEntry(
      fact(153, sessionID: sessionID),
      entryID: .init(rawValue: id(199)),
      target: nil
    ))) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .invalidIntention)
    }
    _ = try logic.perform(.stop(fact(154, sessionID: sessionID)))
    XCTAssertEqual(
      try logic.perform(.retargetEntry(
        fact(155, sessionID: sessionID),
        entryID: entryID,
        target: nil
      )),
      .attention(.commandNotAllowed(lifecycle: .stopped))
    )

    let finishedID = CookingSession.ID(rawValue: id(156))
    _ = try logic.start(start(stored, session: 156))
    let finish = FinishCookingSessionIntention(
      closureID: .init(rawValue: id(157)),
      sessionID: finishedID,
      finishedAt: Date(timeIntervalSince1970: 200),
      hasMeaningfulDraft: false,
      deletion: FinishSessionDeletion(
        id: .init(rawValue: id(158)),
        deletedAt: Date(timeIntervalSince1970: 201)
      )
    )
    _ = try logic.perform(.finish(finish))
    XCTAssertThrowsError(try logic.perform(.finish(FinishCookingSessionIntention(
      closureID: finish.closureID,
      sessionID: finish.sessionID,
      finishedAt: Date(timeIntervalSince1970: 999),
      hasMeaningfulDraft: false,
      deletion: finish.deletion
    )))) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .intentionIdentityCollision)
    }
    XCTAssertThrowsError(try logic.perform(.finish(FinishCookingSessionIntention(
      closureID: finish.closureID,
      sessionID: finish.sessionID,
      finishedAt: finish.finishedAt,
      hasMeaningfulDraft: false,
      deletion: FinishSessionDeletion(
        id: .init(rawValue: id(158)),
        deletedAt: Date(timeIntervalSince1970: 999)
      )
    )))) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .intentionIdentityCollision)
    }
    let continued = ContinueCookingSessionIntention(
      sessionID: .init(rawValue: id(159)),
      sourceSessionID: finishedID,
      startedAt: Date(timeIntervalSince1970: 210)
    )
    _ = try logic.perform(.continueSession(continued))
    XCTAssertThrowsError(try logic.perform(.continueSession(ContinueCookingSessionIntention(
      sessionID: continued.sessionID,
      sourceSessionID: continued.sourceSessionID,
      startedAt: Date(timeIntervalSince1970: 999)
    )))) {
      XCTAssertEqual($0 as? CookingSessionLogicError, .intentionIdentityCollision)
    }
  }

  // swiftlint:disable:next function_body_length
  func testRetargetSurfacesEntryConflictAndMalformedEvidenceAttention() throws {
    let stored = recipe(seed: 160, withIngredient: true)
    let repository = InMemoryCookingSessionRepository()
    let logic = sessions(stored, repository: repository)
    let sessionID = CookingSession.ID(rawValue: id(170))
    let started = try accepted(logic.start(start(stored, session: 170)))
    let submit = fact(171, sessionID: sessionID)
    let entryID = SessionEntry.ID(rawValue: submit.id.rawValue)
    _ = try logic.perform(.submitEntry(submit, text: "original", target: nil))
    for (value, text) in [(172, "one"), (173, "two")] {
      try repository.append(.activity(try rawFact(
        id: value,
        sessionID: sessionID,
        kitchenID: stored.recipe.kitchenID,
        heads: [submit.id.rawValue],
        payload: .sessionEntry(.revise(entryID: entryID, text: text)),
        kind: .sessionEntry
      )))
    }
    let ingredient = started.snapshot.ingredientSections[0].ingredients[0].id
    for (value, state) in [
      (176, SessionIngredientProgress.accounted),
      (177, SessionIngredientProgress.open),
    ] {
      try repository.append(.activity(try rawFact(
        id: value,
        sessionID: sessionID,
        kitchenID: stored.recipe.kitchenID,
        heads: [sessionID.rawValue],
        payload: .progress(.ingredient(state)),
        kind: .progress,
        target: ingredient.rawValue
      )))
    }
    let conflicted = try logic.perform(.retargetEntry(
      fact(174, sessionID: sessionID),
      entryID: entryID,
      target: nil
    ))
    guard case .attention(.conflicts) = conflicted else {
      XCTFail("Expected entry conflict attention")
      return
    }
    let revised = try logic.perform(.reviseEntry(
      fact(178, sessionID: sessionID),
      entryID: entryID,
      text: "resolved",
      target: nil
    ))
    guard case .accepted = revised else {
      XCTFail("Expected a causal revision to resolve the entry conflict")
      return
    }

    let root = try XCTUnwrap(repository.evidence(id: sessionID)?.roots.first)
    try repository.append(.start(CookingSessionRootEvidence(
      id: root.id,
      kitchenID: root.kitchenID,
      recipeID: root.recipeID,
      recipeRevisionID: root.recipeRevisionID,
      startedAt: Date(timeIntervalSince1970: 999),
      snapshotFormatVersion: root.snapshotFormatVersion,
      snapshotData: root.snapshotData,
      snapshotDigest: root.snapshotDigest
    )))
    let recovery = try logic.perform(.retargetEntry(
      fact(175, sessionID: sessionID),
      entryID: entryID,
      target: nil
    ))
    guard case .attention(.recovery) = recovery else {
      XCTFail("Expected retained Recovery attention")
      return
    }
    let finishRecovery = try logic.perform(.finish(FinishCookingSessionIntention(
      closureID: .init(rawValue: id(176)),
      sessionID: sessionID,
      finishedAt: Date(timeIntervalSince1970: 300),
      hasMeaningfulDraft: false
    )))
    guard case .attention(.recovery) = finishRecovery else {
      XCTFail("Expected Finish Recovery attention")
      return
    }
  }

  private func recipe(
    seed: Int,
    title: String = "Soup",
    withIngredient: Bool = false
  ) -> StoredRecipe {
    let recipeID = Recipe.ID(rawValue: id(seed + 1))
    let revisionID = RecipeRevision.ID(rawValue: id(seed + 2))
    return StoredRecipe(
      recipe: Recipe(
        id: recipeID,
        kitchenID: .init(rawValue: id(seed)),
        currentRevisionID: revisionID
      ),
      revision: RecipeRevision(
        id: revisionID,
        recipeID: recipeID,
        revisionNumber: 1,
        title: title,
        ingredientSections: withIngredient ? [
          IngredientSection(ingredients: [
            RecipeIngredient(
              id: .init(rawValue: id(seed + 3)),
              originalText: "stock",
              ingredientText: "stock",
              parseState: .reviewed
            ),
          ]),
        ] : []
      )
    )
  }

  private func sessions(
    _ stored: StoredRecipe,
    repository: any CookingSessionRepository
  ) -> CookingSessions {
    CookingSessions(
      kitchenID: stored.recipe.kitchenID,
      recipeRepository: SessionRecipeRepository(stored: [stored]),
      sessionRepository: repository
    )
  }

  private func start(_ stored: StoredRecipe, session value: Int) -> StartCookingSessionIntention {
    StartCookingSessionIntention(
      sessionID: .init(rawValue: id(value)),
      recipeID: stored.recipe.id,
      recipeRevisionID: stored.revision.id,
      startedAt: Date(timeIntervalSince1970: 100)
    )
  }

  private func fact(_ value: Int, sessionID: CookingSession.ID) -> SessionFactIntention {
    SessionFactIntention(
      id: .init(rawValue: id(value)),
      sessionID: sessionID,
      authoredAt: Date(timeIntervalSince1970: 110)
    )
  }

  private func accepted(_ result: CookingSessionCommandResult) throws -> CookingSessionProjection {
    guard case let .accepted(session) = result else { throw ProbeError.read }
    return session
  }

  // Raw evidence mirrors the frozen repository record boundary.
  // swiftlint:disable:next function_parameter_count
  private func rawFact(
    id value: Int,
    sessionID: CookingSession.ID,
    kitchenID: Kitchen.ID,
    heads: [UUID],
    payload: SessionFactPayload,
    kind: SessionFact.Kind,
    target: UUID? = nil
  ) throws -> SessionFactEvidence {
    let encodedHeads = CausalHeadsCodec.encode(heads)
    let encodedPayload = try SessionFactPayloadCodec.encode(payload)
    return SessionFactEvidence(
      id: .init(rawValue: id(value)),
      sessionID: sessionID,
      kitchenID: kitchenID,
      kind: kind.rawValue,
      targetSnapshotElementID: target,
      authoredAt: Date(timeIntervalSince1970: 150),
      causalHeadsFormatVersion: encodedHeads.formatVersion,
      causalHeadsData: encodedHeads.data,
      payloadFormatVersion: encodedPayload.formatVersion,
      payloadData: encodedPayload.data,
      payloadDigest: encodedPayload.digest
    )
  }

  private func assertSessionReadFailure(_ error: Error) {
    XCTAssertEqual(error as? CookingSessionLogicError, .sessionReadFailed)
  }

  private func id(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0005-%012d", value))!
  }
}

@MainActor
private final class ReadFailureCookingSessionRepository: CookingSessionRepository {
  func append(_ transaction: CookingSessionTransaction) throws { throw ProbeError.read }
  func evidence(id: CookingSession.ID) throws -> SessionEvidence? { throw ProbeError.read }
  func session(id: CookingSession.ID) throws -> SessionProjectionResult? { throw ProbeError.read }
  func sessions(in id: Kitchen.ID) throws -> [SessionProjectionResult] { throw ProbeError.read }
  func sessions(for id: Recipe.ID) throws -> [SessionProjectionResult] { throw ProbeError.read }
  func sessions(for id: Recipe.ID, in kitchenID: Kitchen.ID) throws -> [SessionProjectionResult] {
    throw ProbeError.read
  }
  func finishedSessions(in id: Kitchen.ID, limit: Int) throws -> [SessionProjectionResult] {
    throw ProbeError.read
  }
  func deletions(in id: Kitchen.ID) throws -> [SessionDeletionEvidence] { throw ProbeError.read }
  func deletions(for id: CookingSession.ID) throws -> [SessionDeletionEvidence] { throw ProbeError.read }
  func deletions(id: SessionDeletion.ID) throws -> [SessionDeletionEvidence] { throw ProbeError.read }
  func restorations(for id: SessionDeletion.ID) throws -> [SessionDeletionResolutionEvidence] {
    throw ProbeError.read
  }
}

private enum ProbeError: Error { case read }

@MainActor
private final class ClassifiedReadRepository: CookingSessionRepository {
  enum Mode: Int, CaseIterable { case missing = 1, throwing = 2 }

  private let base = InMemoryCookingSessionRepository()
  private let mode: Mode

  init(mode: Mode) { self.mode = mode }
  func append(_ transaction: CookingSessionTransaction) throws { try base.append(transaction) }
  func evidence(id: CookingSession.ID) throws -> SessionEvidence? {
    if mode == .throwing { throw ProbeError.read }
    return nil
  }
  func session(id: CookingSession.ID) throws -> SessionProjectionResult? {
    if mode == .throwing { throw ProbeError.read }
    return nil
  }
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
