// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import KitchenKit
import Foundation
import XCTest

@MainActor
final class RecipeLibraryNavigationTests: XCTestCase {
  func testFailedDraftLeaveVetoesEveryNavigationEntryPointWithoutChangingSelection() throws {
    let app = try AppRuntime.testing()
    let store = NavigationDraftStore()
    let library = RecipeLibraryModel(
      library: app.libraryModel.library,
      samplePreferences: VolatileKitchenPreferencesStore(sampleRecipeOnboardingResponse: .accepted),
      kitchenWasCreated: false, editingStore: store
    )
    let sessions = CookingSessionPresentationModel(
      sessions: app.cookingSessions, store: VolatileCookingSessionPresentationStore(), navigation: library.navigation
    )
    library.loadIfNeeded()
    sessions.loadIfNeeded()
    let recipe = try XCTUnwrap(library.selectedRecipe)
    XCTAssertTrue(sessions.start(from: recipe))
    let sessionID = try XCTUnwrap(sessions.currentSessionID)
    var openedImport = false
    var focused = false
    let actions = LibraryCommandActions(library: library, sessions: sessions,
                                       openImport: { openedImport = true }, focusDestination: { focused = true })
    XCTAssertTrue(actions.perform(.newRecipe))
    let editor = try XCTUnwrap(library.editor)
    focused = false
    store.refusesWrites = true
    editor.session.title = "Keep latest contents"
    let destination = library.navigation.destination
    for command: LibraryCommandActions.Command in [.newRecipe, .importRecipe, .sessions, .deletedItems, .drafts] {
      XCTAssertFalse(actions.perform(command))
      XCTAssertEqual(library.navigation.destination, destination)
    }
    XCTAssertFalse(library.selectRecipeForReading(nil))
    XCTAssertFalse(sessions.selectSession(sessionID))
    XCTAssertFalse(sessions.showRecipeSessionHistory(for: recipe.id))
    library.closeEditor()
    XCTAssertEqual(library.navigation.destination, destination)
    XCTAssertIdentical(library.editor, editor)
    XCTAssertEqual(library.selectedRecipeID, recipe.id)
    XCTAssertEqual(library.drafts.drafts.count, 1)
    XCTAssertFalse(openedImport)
    XCTAssertFalse(focused)
    store.refusesWrites = false
    library.retryEditingStorage()
    XCTAssertTrue(actions.perform(.sessions))
    XCTAssertEqual(library.navigation.destination, .history(.all))
  }

  func testHistoryAndFinishedDestinationsRetainTheirReturnScope() throws {
    let app = try AppRuntime.testing()
    let library = app.libraryModel
    let sessions = app.sessionModel
    library.loadIfNeeded()
    sessions.loadIfNeeded()
    let recipe = try XCTUnwrap(library.selectedRecipe)
    XCTAssertTrue(sessions.start(from: recipe))
    let id = try XCTUnwrap(sessions.currentSessionID)
    XCTAssertTrue(sessions.showRecipeSessionHistory(for: recipe.id))
    XCTAssertTrue(sessions.selectSessionFromHistory(id))
    XCTAssertEqual(library.navigation.destination, .session(id, history: .recipe(recipe.id)))
    XCTAssertTrue(sessions.leaveCurrentSession())
    XCTAssertEqual(library.navigation.destination, .history(.recipe(recipe.id)))
    XCTAssertTrue(sessions.selectSession(id))
    XCTAssertTrue(sessions.finishCurrentSession())
    XCTAssertEqual(library.navigation.destination, .finished(id, history: .all))
    sessions.dismissObservedFinishedSession()
    XCTAssertTrue(sessions.showRecipeSessionHistory(for: recipe.id))
    XCTAssertTrue(sessions.observeFinishedSession(id))
    XCTAssertEqual(library.navigation.destination, .finished(id, history: .recipe(recipe.id)))
    library.reload()
    XCTAssertEqual(library.navigation.destination, .finished(id, history: .recipe(recipe.id)))
    sessions.dismissObservedFinishedSession()
    XCTAssertEqual(library.navigation.destination, .history(.recipe(recipe.id)))
    XCTAssertTrue(sessions.continueSession(id))
    XCTAssertNotEqual(sessions.currentSessionID, id)
    XCTAssertNil(sessions.historyScope)
  }

  func testSharedDestinationChangesWithoutStoppingAnActiveSession() throws {
    let app = try AppRuntime.testing()
    let library = app.libraryModel
    let sessions = app.sessionModel
    library.loadIfNeeded()
    sessions.loadIfNeeded()
    XCTAssertIdentical(library.navigation, sessions.navigation)
    let actions = LibraryCommandActions(library: library, sessions: sessions)
    XCTAssertTrue(actions.perform(.startCooking))
    let session = try XCTUnwrap(sessions.currentSession)
    XCTAssertEqual(library.navigation.destination, .session(session.id, history: nil))
    XCTAssertTrue(actions.perform(.newRecipe))
    let draft = try XCTUnwrap(library.editor)
    XCTAssertEqual(library.navigation.destination, .editor(draft.id))
    XCTAssertNil(sessions.currentSession)
    XCTAssertFalse(actions.canPerform(.editRecipe))
    XCTAssertTrue(actions.perform(.sessions))
    XCTAssertEqual(library.navigation.destination, .history(.all))
    XCTAssertTrue(sessions.selectSession(session.id))
    XCTAssertTrue(library.selectRecipeForReading(library.recipes.first?.id))
    XCTAssertEqual(library.navigation.destination, .recipe)
    XCTAssertNil(sessions.currentSession)
    sessions.reload()
    XCTAssertEqual(sessions.sessions.first { $0.id == session.id }?.lifecycle, .active)
    XCTAssertTrue(actions.canPerform(.editRecipe))
  }
}

@MainActor
private final class NavigationDraftStore: RecipeEditingStoring {
  var refusesWrites = false
  private var records: [RecipeEditingRecord] = []
  func load() throws -> [RecipeEditingRecord] { records }
  func save(_ records: [RecipeEditingRecord]) throws {
    if refusesWrites { throw CocoaError(.fileWriteUnknown) }
    self.records = records
  }
}
