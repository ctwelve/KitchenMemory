// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import XCTest

final class RecipeAuthorityDuplicateSaveTests: XCTestCase {
  func testDifferentSaveCommandsCannotOwnTheSameRevision() throws {
    let fixture = RecipeAuthorityFixture()
    let first = fixture.revision(1)
    let save = try fixture.save(1, revision: first)
    let selection = fixture.selection(11, revision: first)
    let secondSaveForRevision = try fixture.save(2, revision: first)
    XCTAssertEqual(
      RecipeAuthorityProjector.project(fixture.evidence(
        saves: [save, secondSaveForRevision], selections: [selection], revisions: [first]
      )),
      .recovery(.commandCollision(secondSaveForRevision.id))
    )
  }
}
