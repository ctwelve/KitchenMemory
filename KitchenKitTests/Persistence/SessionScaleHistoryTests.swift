// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import UndoKit
import XCTest

@MainActor
final class SessionScaleHistoryTests: XCTestCase {
  func testUndoRestoresCompletePriorScaleAndRedoAppendsFreshFacts() async throws {
    var draft = RecipeDraft(title: "Soup", ingredientLines: ["2 cups water"], instructionLines: ["Simmer"])
    draft.recipeYield = RecipeYield(quantity: QuantityExpression(kind: .exact,
      lowerBound: RationalQuantity(numerator: 2)), unitText: "bowls", originalText: "2 bowls")
    draft.ingredientSections[0].ingredients[0].quantity = QuantityExpression(kind: .exact,
      lowerBound: RationalQuantity(numerator: 2))
    let fixture = try ProgressHistoryFixture(draft: draft)
    defer { fixture.base.removeFiles() }
    let original = try XCTUnwrap(fixture.session().workingScale)
    let replacement = SessionWorkingScale(workingYield: RecipeYield(originalText: "A bigger pot"),
      exactScale: RationalQuantity(numerator: 3, denominator: 2), quantities: [SessionIngredientQuantity(
        ingredientID: original.quantities[0].ingredientID,
        quantity: QuantityExpression(kind: .approximate, lowerBound: RationalQuantity(numerator: 3))),
      ])
    let history = RecipeOrganizationHistory(repository: fixture.base.repository)
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    assertOrganizationHistoryAccepted(try await history.scale(fixture.id, to: replacement))
    XCTAssertEqual(try fixture.session().workingScale, replacement)
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertEqual(try fixture.session().workingScale, original)
    assertOrganizationHistoryAccepted(await history.redo())
    XCTAssertEqual(try fixture.session().workingScale, replacement)
    XCTAssertEqual(try fixture.repository.evidence(id: fixture.id)?.facts.count, 3)
    XCTAssertEqual(try fixture.session().snapshot.initialWorkingScale, original)
    await history.close()
  }

  func testRepeatedScaleProgressFolderAndTagChangesKeepOneTimelineAndNoOpsKeepRedo() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    let original = try XCTUnwrap(fixture.session().workingScale)
    let double = SessionWorkingScale(exactScale: RationalQuantity(numerator: 2))
    let half = SessionWorkingScale(exactScale: RationalQuantity(numerator: 1, denominator: 2))
    let tag = Tag.ID()
    try fixture.base.repository.accept(fixture.base.repository.load(in: fixture.base.kitchenID).prepare(
      tag: .create(id: tag, name: "Dinner")))
    let history = RecipeOrganizationHistory(repository: fixture.base.repository)
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    assertOrganizationHistoryAccepted(try await history.scale(fixture.id, to: double))
    assertOrganizationHistoryAccepted(try await history.progress(fixture.id, to: fixture.completed))
    assertOrganizationHistoryAccepted(try await history.move([fixture.base.recipeID], to: fixture.base.first))
    assertOrganizationHistoryAccepted(try await history.classify([fixture.base.recipeID], tagID: tag, adding: true))
    assertOrganizationHistoryAccepted(try await history.scale(fixture.id, to: half))
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertEqual(try fixture.session().workingScale, double)
    let noOp = try await history.scale(fixture.id, to: double)
    XCTAssertEqual(noOp, .rejected)
    XCTAssertTrue(try XCTUnwrap(history.session).status.canRedo)
    assertOrganizationHistoryAccepted(await history.undo())
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertNil(try fixture.base.placement())
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertEqual(try fixture.progress(), .instruction(.open))
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertEqual(try fixture.session().workingScale, original)
    assertOrganizationHistoryAccepted(await history.redo())
    assertOrganizationHistoryAccepted(try await history.scale(fixture.id, to: half))
    XCTAssertFalse(try XCTUnwrap(history.session).status.canRedo)
    await history.close()
  }

  func testScaleHistoryWaitsForOrdinaryWorkAndRejectsUnopenedOrUnadmittedSubmissions() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    var pending = false
    let history = RecipeOrganizationHistory(repository: fixture.base.repository, sessionAdmission: { _ in !pending })
    let double = SessionWorkingScale(exactScale: RationalQuantity(numerator: 2))
    do {
      _ = try await history.scale(fixture.id, to: double)
      XCTFail("Closed history must refuse")
    } catch { XCTAssertEqual(error as? RecipeOrganizationHistoryError, .notOpen) }
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    pending = true
    do {
      _ = try await history.scale(fixture.id, to: double)
      XCTFail("Pending work must refuse")
    } catch { XCTAssertEqual(error as? RecipeOrganizationHistoryError, .ineligible) }
    pending = false
    assertOrganizationHistoryAccepted(try await history.scale(fixture.id, to: double))
    pending = true
    XCTAssertTrue(history.sessionDeliveryIsBlocked)
    let refused = await history.undo()
    XCTAssertEqual(refused, .rejected)
    pending = false
    assertOrganizationHistoryAccepted(await history.undo())
    pending = true
    let nativeRefused = await history.session?.redo()
    XCTAssertEqual(nativeRefused, .rejected)
    XCTAssertNil(history.pendingSessionID)
    await history.close()
  }

  func testStopRetiresScaleAndInterleavedFolderHistoryAcrossResumeAndReopen() async throws {
    let fixture = try ProgressHistoryFixture()
    defer { fixture.base.removeFiles() }
    let history = RecipeOrganizationHistory(repository: fixture.base.repository)
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    assertOrganizationHistoryAccepted(try await history.scale(fixture.id,
      to: SessionWorkingScale(exactScale: RationalQuantity(numerator: 2))))
    assertOrganizationHistoryAccepted(try await history.move([fixture.base.recipeID], to: fixture.base.first))
    _ = try fixture.sessions.perform(.stop(.init(id: .init(), sessionID: fixture.id, authoredAt: Date())))
    let refused = await history.undo()
    XCTAssertEqual(refused, .rejected)
    XCTAssertEqual(try fixture.base.placement(), fixture.base.first)
    _ = try fixture.sessions.perform(.resume(.init(id: .init(), sessionID: fixture.id, authoredAt: Date())))
    await history.close()
    try await history.open(scope: fixture.base.scope, historyURL: fixture.base.historyURL)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canUndo)
    XCTAssertFalse(try XCTUnwrap(history.session).status.canRedo)
    await history.close()
  }

}

extension ProgressHistoryFixture {
  func session() throws -> CookingSessionProjection {
    guard case let .session(value) = try repository.session(id: id) else {
      throw NSError(domain: "ProgressHistoryFixture", code: 2)
    }
    return value
  }
}
