// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
@testable import KitchenMemory
import Observation
import XCTest

@MainActor
final class OrganizationPreferenceCompositionTests: XCTestCase {
  func testRuntimeSharesObservablePreferencesAndResetPreservesFeatureChoices() async throws {
    let preferences = VolatileKitchenPreferencesStore(sampleRecipeOnboardingResponse: .accepted)
    let app = try AppRuntime.testing(.init(preferencesStore: preferences))
    let organization = try XCTUnwrap(app.libraryModel.organization)
    let kitchenID = try XCTUnwrap(app.recipeRepository.kitchens().first).id
    let settings = preferences.organizationPreferences(
      scope: app.ownerID.rawValue + ".local", kitchenID: kitchenID)
    let changed = expectation(description: "Sidebar observes shared visibility")
    withObservationTracking {
      _ = organization.preferences.foldersEnabled
    } onChange: {
      changed.fulfill()
    }
    settings.foldersEnabled = false
    settings.tagsEnabled = false
    settings.tagsExpanded = false
    settings.expanded = [Folder.ID()]
    await fulfillment(of: [changed], timeout: 1)
    XCTAssertFalse(organization.preferences.foldersEnabled)
    XCTAssertFalse(organization.preferences.tagsEnabled)
    XCTAssertFalse(organization.preferences.tagsExpanded)
    XCTAssertEqual(organization.preferences.expanded, settings.expanded)

    organization.clearForReset()

    XCTAssertFalse(settings.foldersEnabled)
    XCTAssertFalse(settings.tagsEnabled)
    XCTAssertTrue(settings.tagsExpanded)
    XCTAssertTrue(settings.expanded.isEmpty)
    let anotherApp = try AppRuntime.testing()
    XCTAssertTrue(try XCTUnwrap(anotherApp.libraryModel.organization).preferences.foldersEnabled)
  }
}
