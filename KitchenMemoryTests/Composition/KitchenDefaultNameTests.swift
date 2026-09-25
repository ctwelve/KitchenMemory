// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
@testable import KitchenMemory
import XCTest

@MainActor
final class KitchenDefaultNameTests: XCTestCase {
  private let names = [
    "en-US": "Home Kitchen", "en-GB": "Home Kitchen",
    "es-MX": "Cocina de casa", "fr-CA": "Cuisine de la maison",
    "de-DE": "Küche zu Hause", "it-IT": "Cucina di casa",
  ]

  func testStartupCreatesKitchenWithLocalizedDefaultAndStableIdentity() throws {
    for (language, name) in names {
      let app = try AppRuntime.testing(.init(library: .empty, locale: Locale(identifier: language)))
      let kitchen = try XCTUnwrap(app.recipeRepository.kitchen(id: KitchenBootstrapService.personalKitchenID))
      XCTAssertEqual(kitchen.name, name, language)
      XCTAssertEqual(kitchen.ownerID, app.ownerID)
    }
  }

  func testOwnershipRefreshCreatesMissingDefaultInEveryLocale() throws {
    for (language, name) in names {
      let container = try KitchenMemorySchema.makeContainer(inMemory: true)
      let repository = SwiftDataRecipeRepository(modelContainer: container)
      let owner = KitchenOwner.ID(rawValue: "test:localized-owner")
      try reconcileKitchenOwnership(repository: repository, ownerID: owner, locale: Locale(identifier: language))
      let kitchen = try XCTUnwrap(repository.kitchen(id: KitchenBootstrapService.personalKitchenID))
      XCTAssertEqual(kitchen.name, name, language)
      XCTAssertEqual(kitchen.ownerID, owner)
    }
  }

  func testDifferentLocalePreservesStoredNameAndIdentityOnBootstrapAndRefresh() throws {
    let app = try AppRuntime.testing(.init(library: .empty, locale: Locale(identifier: "fr-CA")))
    let original = try XCTUnwrap(app.recipeRepository.kitchen(id: KitchenBootstrapService.personalKitchenID))
    for name in [original.name, "La cuisine d’Élodie", "Home Kitchen"] {
      let stored = Kitchen(id: original.id, ownerID: app.ownerID, name: name)
      try app.recipeRepository.save(stored)
      let prepared = try KitchenBootstrapService(repository: app.recipeRepository)
        .prepareInitialKitchenWithStatus(named: "Cucina di casa", ownerID: app.ownerID)
      XCTAssertFalse(prepared.wasCreated)
      XCTAssertEqual(prepared.kitchen, stored)
      try reconcileKitchenOwnership(repository: app.recipeRepository, ownerID: app.ownerID,
        locale: Locale(identifier: "de-DE"))
      XCTAssertEqual(try app.recipeRepository.kitchen(id: stored.id), stored)
      app.reloadAfterExternalStoreChange()
      XCTAssertEqual(try app.recipeRepository.kitchen(id: stored.id), stored)
    }
  }

  func testOwnershipRefreshPreservesLegacyKitchenNameDuringConvergence() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    try repository.save(Kitchen(name: "Cuisine familiale"))
    let owner = KitchenOwner.ID(rawValue: "test:legacy-owner")
    try reconcileKitchenOwnership(repository: repository, ownerID: owner, locale: Locale(identifier: "it-IT"))
    let kitchen = try XCTUnwrap(repository.kitchen(id: KitchenBootstrapService.personalKitchenID))
    XCTAssertEqual(kitchen.name, "Cuisine familiale")
    XCTAssertEqual(kitchen.ownerID, owner)
  }
}
