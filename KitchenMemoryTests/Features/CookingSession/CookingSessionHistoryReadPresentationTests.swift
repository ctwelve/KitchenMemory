// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import Foundation
import KitchenKit
import XCTest

@MainActor
final class HistoryReadPresentationTests: XCTestCase {
  func testReloadProjectsClassificationsAndRetainedRecipeHistory() throws {
    for usesInMemoryRepository in [false, true] {
      let scenario = try arrangeHistoryScenario(usingInMemoryRepository: usesInMemoryRepository)
      scenario.model.reload()

      XCTAssertEqual(Set(scenario.model.sessions.map(\.id)), [scenario.ordinaryID])
      XCTAssertEqual(Set(scenario.model.deletedSessions.map(\.id)), [scenario.deletedID])
      XCTAssertEqual(Set(scenario.model.waitingSessions.map(\.evidence.sessionID)), [scenario.missingRootID])
      XCTAssertEqual(Set(scenario.model.recoverySessions.map(\.evidence.sessionID)), [scenario.collisionID])
      XCTAssertEqual(
        scenario.model.finishedSessions.map(\.id),
        [scenario.olderSelectedID, scenario.tiedFinishID]
      )
      XCTAssertEqual(
        scenario.model.historySessionIDsByRecipe[scenario.recipeID],
        [scenario.ordinaryID, scenario.deletedID, scenario.collisionID,
         scenario.olderSelectedID, scenario.tiedFinishID, ]
      )
      XCTAssertEqual(scenario.model.historySessionIDsByRecipe[scenario.otherRecipeID], [scenario.collisionID])

      scenario.model.showSessionHistory()
      XCTAssertEqual(
        Set(scenario.model.displayedHistorySessions.map(\.id)),
        [scenario.ordinaryID, scenario.olderSelectedID, scenario.tiedFinishID]
      )
      XCTAssertTrue(scenario.model.showRecipeSessionHistory(for: scenario.recipeID))
      XCTAssertEqual(
        Set(scenario.model.displayedHistorySessions.map(\.id)),
        [scenario.ordinaryID, scenario.olderSelectedID, scenario.tiedFinishID]
      )
    }
  }

  func testExternalRefreshAndKitchenResetRebuildPresentedHistory() throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let recipe = try XCTUnwrap(app.libraryModel.recipes.first)
    let first = try makeRoot(120, kitchenID: recipe.recipe.kitchenID, recipeID: recipe.recipe.id)
    try app.cookingSessionRepository.append(.start(first))
    app.sessionModel.loadIfNeeded()
    XCTAssertEqual(app.sessionModel.sidebarSessions(for: recipe.recipe.id).map(\.id), [first.id])

    let externalWriter = SwiftDataCookingSessionRepository(modelContainer: app.modelContainer)
    let imported = try makeRoot(121, kitchenID: recipe.recipe.kitchenID, recipeID: recipe.recipe.id)
    try externalWriter.append(.start(imported))
    app.reloadAfterExternalStoreChange()

    XCTAssertEqual(
      Set(app.sessionModel.sidebarSessions(for: recipe.recipe.id).map(\.id)),
      [first.id, imported.id]
    )
    app.sessionModel.showRecipeSessionHistory(for: recipe.recipe.id)
    XCTAssertEqual(
      Set(app.sessionModel.displayedHistorySessions.map(\.id)),
      [first.id, imported.id]
    )

    XCTAssertTrue(app.libraryModel.resetKitchen())
    app.sessionModel.showSessionHistory()
    XCTAssertTrue(app.sessionModel.displayedHistorySessions.isEmpty)
    XCTAssertTrue(app.sessionModel.sidebarSessions(for: recipe.recipe.id).isEmpty)
    XCTAssertTrue(app.sessionModel.finishedSessions.isEmpty)
    XCTAssertTrue(app.sessionModel.deletedSessions.isEmpty)
  }
}

extension HistoryReadPresentationTests {
  private func arrangeHistoryScenario(usingInMemoryRepository: Bool) throws -> HistoryScenario {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let recipe = try XCTUnwrap(app.libraryModel.recipes.first)
    let otherRecipe = try XCTUnwrap(app.libraryModel.recipes.dropFirst().first)
    let repository: any CookingSessionRepository = usingInMemoryRepository
      ? InMemoryCookingSessionRepository()
      : app.cookingSessionRepository
    let service = CookingSessions(
      kitchenID: recipe.recipe.kitchenID,
      recipeRepository: app.recipeRepository,
      sessionRepository: repository
    )
    let model = CookingSessionPresentationModel(
      sessions: service,
      store: VolatileCookingSessionPresentationStore()
    )
    let ids = try appendClassifiedFixtures(
      to: repository, recipe: recipe.recipe.id, otherRecipe: otherRecipe.recipe.id,
      kitchen: recipe.recipe.kitchenID
    )
    let finishedIDs = try appendFinishedFixtures(
      to: repository, recipe: recipe.recipe.id, kitchen: recipe.recipe.kitchenID
    )
    app.libraryModel.deleteRecipe(try app.libraryModel.library.prepareDeletion(of: recipe.recipe.id))
    return HistoryScenario(
      model: model,
      recipeID: recipe.recipe.id,
      otherRecipeID: otherRecipe.recipe.id,
      ordinaryID: ids.ordinaryID,
      deletedID: ids.deletedID,
      missingRootID: ids.missingRootID,
      collisionID: ids.collisionID,
      olderSelectedID: finishedIDs.olderSelectedID,
      tiedFinishID: finishedIDs.tiedFinishID
    )
  }

  private func appendClassifiedFixtures(
    to repository: any CookingSessionRepository,
    recipe: Recipe.ID,
    otherRecipe: Recipe.ID,
    kitchen: Kitchen.ID
  ) throws -> ClassifiedFixtureIDs {
    let ordinary = try makeRoot(100, kitchenID: kitchen, recipeID: recipe)
    let deleted = try makeRoot(101, kitchenID: kitchen, recipeID: recipe)
    let missingRootID = CookingSession.ID(rawValue: id(102))
    let collisionID = CookingSession.ID(rawValue: id(103))
    let collisionRoot = try makeRoot(
      sessionID: collisionID, kitchenID: kitchen, recipeID: recipe, startedAt: 200
    )
    let competingRoot = try makeRoot(
      sessionID: collisionID, kitchenID: kitchen, recipeID: otherRecipe, startedAt: 201
    )
    let foreign = try makeRoot(104, kitchenID: Kitchen.ID(rawValue: id(105)), recipeID: recipe)
    try repository.append(.start(ordinary))
    try repository.append(.start(deleted))
    try repository.append(.delete(try makeDeletion(for: deleted)))
    try repository.append(.activity(try makeFact(
      sessionID: missingRootID, kitchenID: kitchen, kind: .stop
    )))
    try repository.append(.start(collisionRoot))
    try repository.append(.start(competingRoot))
    try repository.append(.start(foreign))
    return ClassifiedFixtureIDs(
      ordinaryID: ordinary.id, deletedID: deleted.id,
      missingRootID: missingRootID, collisionID: collisionID
    )
  }

  private func appendFinishedFixtures(
    to repository: any CookingSessionRepository,
    recipe: Recipe.ID,
    kitchen: Kitchen.ID
  ) throws -> (olderSelectedID: CookingSession.ID, tiedFinishID: CookingSession.ID) {
    let olderSelected = try makeRoot(106, kitchenID: kitchen, recipeID: recipe)
    let tiedFinish = try makeRoot(107, kitchenID: kitchen, recipeID: recipe)
    let olderClosure = try makeClosure(for: olderSelected, id: 108, finishedAt: 400)
    let newerClosure = try makeClosure(for: olderSelected, id: 109, finishedAt: 500)
    let tiedClosure = try makeClosure(for: tiedFinish, id: 110, finishedAt: 500)
    try repository.append(.start(olderSelected))
    try repository.append(.finish(olderClosure))
    try repository.append(.finish(newerClosure))
    try repository.append(.start(tiedFinish))
    try repository.append(.finish(tiedClosure))
    try repository.append(.resolveClosure(try makeClosureResolution(
      for: olderSelected,
      selected: olderClosure.id,
      observed: [olderClosure.id, newerClosure.id]
    )))
    return (olderSelected.id, tiedFinish.id)
  }

  private func makeRoot(
    _ number: Int,
    kitchenID: Kitchen.ID,
    recipeID: Recipe.ID,
    startedAt: TimeInterval = 100
  ) throws -> CookingSessionRootEvidence {
    try makeRoot(
      sessionID: CookingSession.ID(rawValue: id(number)),
      kitchenID: kitchenID,
      recipeID: recipeID,
      startedAt: startedAt
    )
  }

  private func makeRoot(
    sessionID: CookingSession.ID,
    kitchenID: Kitchen.ID,
    recipeID: Recipe.ID,
    startedAt: TimeInterval
  ) throws -> CookingSessionRootEvidence {
    let encoded = try ExecutionSnapshotCodec.encode(ExecutionSnapshot(title: "Soup"))
    return CookingSessionRootEvidence(
      id: sessionID,
      kitchenID: kitchenID,
      recipeID: recipeID,
      recipeRevisionID: RecipeRevision.ID(),
      startedAt: Date(timeIntervalSince1970: startedAt),
      snapshotFormatVersion: encoded.formatVersion,
      snapshotData: encoded.data,
      snapshotDigest: encoded.digest
    )
  }

  private func makeClosure(
    for root: CookingSessionRootEvidence,
    id closureID: Int,
    finishedAt: TimeInterval
  ) throws -> SessionClosureEvidence {
    let snapshot = try ExecutionSnapshotCodec.decode(
      formatVersion: root.snapshotFormatVersion,
      data: root.snapshotData
    )
    let closed = try ClosedSessionProjectionCodec.encode(
      ClosedSessionProjection(CookingSessionProjection(id: root.id, snapshot: snapshot))
    )
    let heads = CausalHeadsCodec.encode([root.id.rawValue])
    return SessionClosureEvidence(
      id: SessionClosure.ID(rawValue: id(closureID)),
      sessionID: root.id,
      kitchenID: root.kitchenID,
      finishedAt: Date(timeIntervalSince1970: finishedAt),
      causalHeadsFormatVersion: heads.formatVersion,
      causalHeadsData: heads.data,
      snapshotFormatVersion: root.snapshotFormatVersion,
      snapshotDigest: root.snapshotDigest,
      projectionFormatVersion: closed.formatVersion,
      projectionDigest: closed.digest,
      outcomeFormatVersion: nil,
      outcomeData: nil
    )
  }

  private func makeClosureResolution(
    for root: CookingSessionRootEvidence,
    selected: SessionClosure.ID,
    observed: [SessionClosure.ID]
  ) throws -> SessionFactEvidence {
    let heads = CausalHeadsCodec.encode(observed.map(\.rawValue))
    let payload = try SessionFactPayloadCodec.encode(.closureResolution(
      ClosureSelection(selectedClosureID: selected, observedClosureIDs: observed)
    ))
    return SessionFactEvidence(
      id: SessionFact.ID(rawValue: id(111)),
      sessionID: root.id,
      kitchenID: root.kitchenID,
      kind: SessionFact.Kind.conflictResolution.rawValue,
      targetSnapshotElementID: nil,
      authoredAt: Date(timeIntervalSince1970: 510),
      causalHeadsFormatVersion: heads.formatVersion,
      causalHeadsData: heads.data,
      payloadFormatVersion: payload.formatVersion,
      payloadData: payload.data,
      payloadDigest: payload.digest
    )
  }

  private func makeDeletion(for root: CookingSessionRootEvidence) throws -> SessionDeletionEvidence {
    let sessionHeads = CausalHeadsCodec.encode([root.id.rawValue])
    let dispositionHeads = CausalHeadsCodec.encode([])
    return SessionDeletionEvidence(
      id: SessionDeletion.ID(rawValue: id(112)),
      sessionID: root.id,
      kitchenID: root.kitchenID,
      deletedAt: Date(timeIntervalSince1970: 300),
      sessionHeadsFormatVersion: sessionHeads.formatVersion,
      sessionHeadsData: sessionHeads.data,
      dispositionHeadsFormatVersion: dispositionHeads.formatVersion,
      dispositionHeadsData: dispositionHeads.data
    )
  }

  private func makeFact(
    sessionID: CookingSession.ID,
    kitchenID: Kitchen.ID,
    kind: SessionFact.Kind
  ) throws -> SessionFactEvidence {
    let heads = CausalHeadsCodec.encode([sessionID.rawValue])
    let payload = try SessionFactPayloadCodec.encode(.empty)
    return SessionFactEvidence(
      id: SessionFact.ID(rawValue: id(113)),
      sessionID: sessionID,
      kitchenID: kitchenID,
      kind: kind.rawValue,
      targetSnapshotElementID: nil,
      authoredAt: Date(timeIntervalSince1970: 250),
      causalHeadsFormatVersion: heads.formatVersion,
      causalHeadsData: heads.data,
      payloadFormatVersion: payload.formatVersion,
      payloadData: payload.data,
      payloadDigest: payload.digest
    )
  }

  private func id(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
  }
}

@MainActor
private struct HistoryScenario {
  let model: CookingSessionPresentationModel
  let recipeID: Recipe.ID
  let otherRecipeID: Recipe.ID
  let ordinaryID: CookingSession.ID
  let deletedID: CookingSession.ID
  let missingRootID: CookingSession.ID
  let collisionID: CookingSession.ID
  let olderSelectedID: CookingSession.ID
  let tiedFinishID: CookingSession.ID
}

private struct ClassifiedFixtureIDs {
  let ordinaryID: CookingSession.ID
  let deletedID: CookingSession.ID
  let missingRootID: CookingSession.ID
  let collisionID: CookingSession.ID
}
