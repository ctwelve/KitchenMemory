// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemory
import KitchenMemoryDomain
import KitchenMemoryPersistence
import XCTest

@MainActor
final class KitchenMemoryTests: XCTestCase {
  func testStarterRecipeLoadsThroughAppComposition() throws {
    let dependencies = try AppDependencies(inMemory: true)

    dependencies.libraryModel.loadIfNeeded()

    XCTAssertEqual(dependencies.libraryModel.recipes.count, 1)
    XCTAssertEqual(
      dependencies.libraryModel.selectedRecipe?.revision.title,
      "Tuna Noodle Hotdish"
    )
  }

  func testReloadingDoesNotDuplicateStarterContent() throws {
    let dependencies = try AppDependencies(inMemory: true)

    dependencies.libraryModel.loadIfNeeded()
    dependencies.libraryModel.reload()

    XCTAssertEqual(dependencies.libraryModel.recipes.count, 1)
  }
}
