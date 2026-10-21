// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenKit
import UndoKit
import XCTest

@MainActor
final class RecipeOrganizationTagHistoryTests: XCTestCase {
  func testOlderAddUndoFollowsOnlyItsReplacementAfterRemoveUndo() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.removeFiles() }
    let tag = Tag.ID()
    try fixture.repository.accept(fixture.repository.load(in: fixture.kitchenID).prepare(
      tag: .create(id: tag, name: "Dinner")))
    let history = RecipeOrganizationHistory(repository: fixture.repository)
    try await history.open(scope: fixture.scope, historyURL: fixture.historyURL)
    assertOrganizationHistoryAccepted(try await history.classify([fixture.recipeID], tagID: tag, adding: true))
    assertOrganizationHistoryAccepted(try await history.classify([fixture.recipeID], tagID: tag, adding: false))
    XCTAssertFalse(try fixture.repository.load(in: fixture.kitchenID).tags.tagIDs(for: fixture.recipeID).contains(tag))
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertTrue(try fixture.repository.load(in: fixture.kitchenID).tags.tagIDs(for: fixture.recipeID).contains(tag))
    assertOrganizationHistoryAccepted(await history.undo())
    XCTAssertFalse(try fixture.repository.load(in: fixture.kitchenID).tags.tagIDs(for: fixture.recipeID).contains(tag))
    assertOrganizationHistoryAccepted(await history.redo())
    assertOrganizationHistoryAccepted(await history.redo())
    XCTAssertFalse(try fixture.repository.load(in: fixture.kitchenID).tags.tagIDs(for: fixture.recipeID).contains(tag))
    await history.close()
  }
}
