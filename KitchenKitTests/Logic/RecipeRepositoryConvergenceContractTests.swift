// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import XCTest

@MainActor
final class RecipeRepositoryConvergenceContractTests: XCTestCase {
  func testRepositoryWithoutOwnershipConvergenceSupportFailsExplicitly() throws {
    let repository = SessionRecipeRepository(stored: [])
    let ownerID = KitchenOwner.ID(rawValue: "test-owner")

    XCTAssertThrowsError(
      try repository.convergeKitchens(
        into: Kitchen(ownerID: ownerID, name: "Home"),
        ownedBy: ownerID
      )
    ) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .ownershipConvergenceUnsupported
      )
    }
  }
}
