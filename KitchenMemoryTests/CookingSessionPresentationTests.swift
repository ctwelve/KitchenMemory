// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import Foundation
import KitchenKit
import XCTest

@MainActor
final class CookingSessionPresentationTests: XCTestCase {
  func testRuntimeComposesRetainedSessionDependenciesAndStartsWithoutChangingRecipe() throws {
    let store = VolatileCookingSessionPresentationStore()
    let preparedApp = try AppRuntime.testing(.init(
      library: .installed,
      sessionPresentationStore: store
    ))
    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(preparedApp.libraryModel.recipes.first)

    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))

    let session = try XCTUnwrap(preparedApp.sessionModel.currentSession)
    XCTAssertEqual(session.lifecycle, .active)
    XCTAssertEqual(session.snapshot.title, recipe.revision.title)
    XCTAssertEqual(preparedApp.libraryModel.recipes.first, recipe)
    XCTAssertEqual(store.currentSessionID, session.id)
    XCTAssertTrue(store.pendingCommands.isEmpty)
    XCTAssertNotNil(preparedApp.cookingSessionRepository)
  }

  func testStopResumeAndConfirmedFinishAreExplicitLifecycleCommands() throws {
    let preparedApp = try AppRuntime.testing()
    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(preparedApp.libraryModel.recipes.first)
    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))

    XCTAssertTrue(preparedApp.sessionModel.stopCurrentSession())
    XCTAssertEqual(preparedApp.sessionModel.currentSession?.lifecycle, .stopped)
    XCTAssertTrue(preparedApp.sessionModel.resumeCurrentSession())
    XCTAssertEqual(preparedApp.sessionModel.currentSession?.lifecycle, .active)
    XCTAssertTrue(preparedApp.sessionModel.finishCurrentSession())

    XCTAssertNil(preparedApp.sessionModel.currentSession)
    XCTAssertTrue(preparedApp.sessionModel.sessions.isEmpty)
    XCTAssertEqual(preparedApp.sessionModel.finishedSessionCount, 1)
  }

  func testRelaunchReturnsToCurrentActiveSessionWithoutCreatingLifecycleEvidence() throws {
    let store = VolatileCookingSessionPresentationStore()
    let preparedApp = try AppRuntime.testing(.init(
      library: .installed,
      sessionPresentationStore: store
    ))
    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(preparedApp.libraryModel.recipes.first)
    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))
    let active = try XCTUnwrap(preparedApp.sessionModel.currentSession)

    let relaunched = CookingSessionPresentationModel(
      sessions: preparedApp.cookingSessions,
      store: store
    )
    relaunched.loadIfNeeded()

    XCTAssertEqual(relaunched.currentSession, active)
    XCTAssertEqual(relaunched.currentSession?.lifecycle, .active)
    XCTAssertTrue(store.pendingCommands.isEmpty)
  }

  func testSeveralActiveSessionsRemainDistinctAndSelectable() throws {
    let preparedApp = try AppRuntime.testing()
    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(preparedApp.libraryModel.recipes.first)

    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))
    let firstID = try XCTUnwrap(preparedApp.sessionModel.currentSession?.id)
    XCTAssertTrue(preparedApp.sessionModel.leaveCurrentSession())
    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))
    let secondID = try XCTUnwrap(preparedApp.sessionModel.currentSession?.id)

    XCTAssertNotEqual(firstID, secondID)
    XCTAssertEqual(preparedApp.sessionModel.sessions.count, 2)
    XCTAssertTrue(preparedApp.sessionModel.selectSession(firstID))
    XCTAssertEqual(preparedApp.sessionModel.currentSession?.id, firstID)
    XCTAssertEqual(preparedApp.sessionModel.currentSession?.lifecycle, .active)
  }

  func testExternalStoreRefreshReloadsRetainedSessionEvidence() throws {
    let preparedApp = try AppRuntime.testing()
    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.sessionModel.loadIfNeeded()
    let observerProjection = CookingSessionPresentationModel(
      sessions: preparedApp.cookingSessions,
      store: VolatileCookingSessionPresentationStore()
    )
    observerProjection.loadIfNeeded()
    let recipe = try XCTUnwrap(preparedApp.libraryModel.recipes.first)

    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))
    XCTAssertTrue(observerProjection.sessions.isEmpty)
    observerProjection.reloadAfterExternalStoreChange()

    XCTAssertEqual(observerProjection.sessions.count, 1)
    XCTAssertEqual(observerProjection.sessions.first?.lifecycle, .active)
  }

  func testExternalFinishClearsDurableCurrentSessionPointer() {
    let sessionID = CookingSession.ID()
    let active = CookingSessionProjection(
      id: sessionID,
      snapshot: ExecutionSnapshot(title: "Soup")
    )
    let service = ClassifiedSessionService(results: [.session(active)])
    let store = VolatileCookingSessionPresentationStore()
    store.currentSessionID = sessionID
    let model = CookingSessionPresentationModel(sessions: service, store: store)
    model.loadIfNeeded()
    service.results = [
      .session(CookingSessionProjection(
        id: sessionID,
        snapshot: active.snapshot,
        lifecycle: .finished,
        lifecycleBeforeFinish: .active
      )),
    ]

    model.reloadAfterExternalStoreChange()

    XCTAssertNil(model.currentSessionID)
    XCTAssertNil(store.currentSessionID)
    XCTAssertEqual(model.finishedSessionCount, 1)
  }

  func testOutboxRetainsOneIdentityUntilLogicReportsLocalDurability() throws {
    let sessionID = CookingSession.ID()
    let recipeID = Recipe.ID()
    let revisionID = RecipeRevision.ID()
    let accepted = CookingSessionProjection(
      id: sessionID,
      snapshot: ExecutionSnapshot(title: "Soup")
    )
    let service = AmbiguousStartService(accepted: accepted)
    let store = VolatileCookingSessionPresentationStore()
    let model = CookingSessionPresentationModel(sessions: service, store: store)
    let recipe = StoredRecipe(
      recipe: Recipe(
        id: recipeID,
        kitchenID: Kitchen.ID(),
        currentRevisionID: revisionID
      ),
      revision: RecipeRevision(
        id: revisionID,
        recipeID: recipeID,
        revisionNumber: 1,
        title: "Soup"
      )
    )

    XCTAssertFalse(model.start(from: recipe))
    let pending = try XCTUnwrap(store.pendingCommands.first)
    guard case let .start(firstSessionID, _, _, _) = pending else {
      XCTFail("Expected a pending Start intention")
      return
    }
    XCTAssertNil(model.currentSession)

    model.retryPendingCommands()

    XCTAssertEqual(service.attemptedSessionIDs, [firstSessionID, firstSessionID])
    XCTAssertEqual(model.currentSession?.id, firstSessionID)
    XCTAssertTrue(store.pendingCommands.isEmpty)
  }

  func testReloadSeparatesFinishedUnavailableAndRecoveryFromOrdinaryDiscovery() {
    let active = CookingSessionProjection(
      id: CookingSession.ID(),
      snapshot: ExecutionSnapshot(title: "Active")
    )
    let finished = CookingSessionProjection(
      id: CookingSession.ID(),
      snapshot: ExecutionSnapshot(title: "Finished"),
      lifecycle: .finished
    )
    let unavailableEvidence = SessionEvidence(sessionID: CookingSession.ID())
    let recoveryEvidence = SessionEvidence(sessionID: CookingSession.ID())
    let service = ClassifiedSessionService(results: [
      .session(active),
      .session(finished),
      .unavailable(UnavailableSession(
        evidence: unavailableEvidence,
        reasons: [.missingRoot]
      )),
      .recovery(SessionRecovery(
        evidence: recoveryEvidence,
        reasons: [.digestMismatch]
      )),
    ])
    let model = CookingSessionPresentationModel(
      sessions: service,
      store: VolatileCookingSessionPresentationStore()
    )

    model.loadIfNeeded()

    XCTAssertEqual(model.sessions, [active])
    XCTAssertEqual(model.finishedSessionCount, 1)
    XCTAssertEqual(model.unavailableSessionCount, 1)
    XCTAssertEqual(model.recoverySessionCount, 1)
  }

  func testAttentionKeepsPendingIdentityForExplicitRetry() throws {
    let service = AttentionStartService()
    let store = VolatileCookingSessionPresentationStore()
    let model = CookingSessionPresentationModel(sessions: service, store: store)
    let recipeID = Recipe.ID()
    let revisionID = RecipeRevision.ID()
    let recipe = StoredRecipe(
      recipe: Recipe(
        id: recipeID,
        kitchenID: Kitchen.ID(),
        currentRevisionID: revisionID
      ),
      revision: RecipeRevision(
        id: revisionID,
        recipeID: recipeID,
        revisionNumber: 1,
        title: "Soup"
      )
    )

    XCTAssertFalse(model.start(from: recipe))
    let pending = try XCTUnwrap(store.pendingCommands.first)
    XCTAssertEqual(model.issue, .attention(.commandNotAllowed(lifecycle: .active)))

    model.retryPendingCommands()

    XCTAssertEqual(store.pendingCommands, [pending])
    XCTAssertEqual(service.attemptedSessionIDs, [pending.sessionID, pending.sessionID])
  }
}

extension CookingSessionPresentationTests {
  func testPendingStartSurvivesDurableStoreReopenAndUsesOriginalIdentity() throws {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "KitchenMemory-Slice14-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let defaultsName = "KitchenMemory.Slice14.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
    defer { defaults.removePersistentDomain(forName: defaultsName) }
    let storeURL = directory.appending(path: "KitchenMemory.store")
    let sessionID = CookingSession.ID()
    try stageInterruptedStart(sessionID, storeURL: storeURL, defaults: defaults)

    let container = try KitchenMemorySchema.makeContainer(storeURL: storeURL)
    let recipeRepository = SwiftDataRecipeRepository(modelContainer: container)
    let kitchen = try KitchenBootstrapService(repository: recipeRepository)
      .prepareInitialKitchenWithStatus().kitchen
    let sessionRepository = SwiftDataCookingSessionRepository(modelContainer: container)
    let store = DefaultsCookingSessionPresentationStore(defaults: defaults)
    let model = CookingSessionPresentationModel(
      sessions: CookingSessions(
        kitchenID: kitchen.id,
        recipeRepository: recipeRepository,
        sessionRepository: sessionRepository
      ),
      store: store
    )

    model.loadIfNeeded()

    XCTAssertEqual(model.currentSession?.id, sessionID)
    XCTAssertTrue(store.pendingCommands.isEmpty)
    guard case let .session(persisted) = try XCTUnwrap(
      sessionRepository.session(id: sessionID)
    ) else {
      XCTFail("Expected the retried Start to be locally durable")
      return
    }
    XCTAssertEqual(persisted.id, sessionID)
  }
}

@MainActor
private func stageInterruptedStart(
  _ sessionID: CookingSession.ID,
  storeURL: URL,
  defaults: UserDefaults
) throws {
  let container = try KitchenMemorySchema.makeContainer(storeURL: storeURL)
  let recipeRepository = SwiftDataRecipeRepository(modelContainer: container)
  let kitchen = try KitchenBootstrapService(repository: recipeRepository)
    .prepareInitialKitchenWithStatus().kitchen
  let library = RecipeLibrary(
    kitchenID: kitchen.id,
    repository: recipeRepository,
    samples: BundledSampleRecipeProvider(preferredLanguages: ["en-US"]),
    importer: RecipeImportService()
  )
  try library.installSamples()
  let recipe = try XCTUnwrap(library.load().recipes.first)
  DefaultsCookingSessionPresentationStore(defaults: defaults).pendingCommands = [
    .start(
      sessionID: sessionID,
      recipeID: recipe.recipe.id,
      revisionID: recipe.revision.id,
      startedAt: Date(timeIntervalSince1970: 1_800_000_000)
    ),
  ]
}

@MainActor
private final class AmbiguousStartService: CookingSessionServing {
  let accepted: CookingSessionProjection
  var attemptedSessionIDs: [CookingSession.ID] = []

  init(accepted: CookingSessionProjection) {
    self.accepted = accepted
  }

  func sessions() throws -> [SessionProjectionResult] { [] }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    attemptedSessionIDs.append(intention.sessionID)
    if attemptedSessionIDs.count == 1 {
      throw CookingSessionLogicError.sessionWriteFailed
    }
    return .accepted(CookingSessionProjection(
      id: intention.sessionID,
      snapshot: accepted.snapshot
    ))
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    XCTFail("Unexpected non-Start intention: \(intention)")
    return .accepted(accepted)
  }
}

@MainActor
private final class ClassifiedSessionService: CookingSessionServing {
  var results: [SessionProjectionResult]

  init(results: [SessionProjectionResult]) {
    self.results = results
  }

  func sessions() throws -> [SessionProjectionResult] { results }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    throw CookingSessionLogicError.invalidIntention
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    throw CookingSessionLogicError.invalidIntention
  }
}

@MainActor
private final class AttentionStartService: CookingSessionServing {
  var attemptedSessionIDs: [CookingSession.ID] = []

  func sessions() throws -> [SessionProjectionResult] { [] }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    attemptedSessionIDs.append(intention.sessionID)
    return .attention(.commandNotAllowed(lifecycle: .active))
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    throw CookingSessionLogicError.invalidIntention
  }
}
