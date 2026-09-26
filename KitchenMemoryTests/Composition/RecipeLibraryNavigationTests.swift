// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import KitchenKit
import Foundation
import XCTest

@MainActor
final class RecipeLibraryNavigationTests: XCTestCase {
  func testAcceptedIntentDistinguishesBrowsingFromOpeningTheSameRecipe() {
    let navigation = RecipeLibraryNavigation()
    let recipeID = Recipe.ID()
    XCTAssertTrue(navigation.selectRecipe(recipeID))
    XCTAssertEqual(navigation.focus, .detail)
    XCTAssertTrue(navigation.browseRecipes {})
    XCTAssertEqual(navigation.destination, .recipe)
    XCTAssertEqual(navigation.selectedRecipeID, recipeID)
    XCTAssertEqual(navigation.focus, .content)
    XCTAssertTrue(navigation.selectRecipe(recipeID))
    XCTAssertEqual(navigation.focus, .detail)
    XCTAssertTrue(navigation.move(to: .history(.all)))
    XCTAssertEqual(navigation.focus, .content)
    XCTAssertTrue(navigation.move(to: .session(CookingSession.ID(), history: .all)))
    XCTAssertEqual(navigation.focus, .detail)
    XCTAssertTrue(navigation.selectAuxiliary(.organization))
    XCTAssertEqual(navigation.focus, .detail)
    XCTAssertTrue(navigation.move(to: .recovery))
    XCTAssertEqual(navigation.focus, .content)
    XCTAssertNil(navigation.auxiliarySelection)
  }

  func testFilteringAnEditedRecipePreservesDraftSelectionAndReturnContext() throws {
    let app = try AppRuntime.testing()
    let library = app.libraryModel
    library.loadIfNeeded()
    let organization = try XCTUnwrap(library.organization)
    let recipe = try XCTUnwrap(library.selectedRecipe)
    library.navigation.recipeListAnchor = recipe.id
    library.beginEditing(recipe)
    let editor = try XCTUnwrap(library.editor)
    editor.session.title = "Still editing this recipe"
    organization.filter.search = "a query with no matching recipe"
    XCTAssertTrue(organization.recipes(library.recipes, locale: .current).isEmpty)
    XCTAssertIdentical(library.editor, editor)
    XCTAssertEqual(library.selectedRecipeID, recipe.id)
    XCTAssertEqual(library.navigation.recipeListAnchor, recipe.id)
    XCTAssertEqual(library.navigation.contentDestination, .recipes)
    organization.resetFilters()
    XCTAssertTrue(organization.recipes(library.recipes, locale: .current).contains { $0.id == recipe.id })
    XCTAssertIdentical(library.editor, editor)
    library.closeEditor()
    XCTAssertEqual(library.drafts.drafts.first?.session.title, "Still editing this recipe")
  }

  func testBrowsingOrganizationPreservesFiltersWhenDraftCannotBeSaved() throws {
    let app = try AppRuntime.testing()
    let store = NavigationDraftStore()
    let library = RecipeLibraryModel(
      library: app.libraryModel.library,
      samplePreferences: VolatileKitchenPreferencesStore(sampleRecipeOnboardingResponse: .accepted),
      kitchenWasCreated: false, editingStore: store
    )
    library.loadIfNeeded()
    library.beginEditing()
    library.editor?.session.title = "Retain my draft"
    store.refusesWrites = true
    let focus = library.navigation.focus
    let selected = library.navigation.selectedRecipeID
    library.navigation.recipeListAnchor = selected
    var changedFilter = false
    XCTAssertFalse(library.navigation.browseRecipes { changedFilter = true })
    XCTAssertFalse(changedFilter)
    XCTAssertEqual(library.navigation.focus, focus)
    XCTAssertEqual(library.navigation.selectedRecipeID, selected)
    XCTAssertEqual(library.navigation.recipeListAnchor, selected)
    XCTAssertNotNil(library.editor)
    store.refusesWrites = false
    XCTAssertTrue(library.navigation.browseRecipes { changedFilter = true })
    XCTAssertTrue(changedFilter)
    XCTAssertEqual(library.navigation.destination, .recipe)
    XCTAssertEqual(library.drafts.drafts.first?.session.title, "Retain my draft")
  }

  func testAcceptedSessionCommandStaysRetiredWhenEditorPreservationVetoesNavigation() throws {
    let app = try AppRuntime.testing()
    let draftStore = NavigationDraftStore()
    let library = RecipeLibraryModel(library: app.libraryModel.library,
      samplePreferences: VolatileKitchenPreferencesStore(sampleRecipeOnboardingResponse: .accepted),
      kitchenWasCreated: false, editingStore: draftStore)
    let commandStore = VolatileCookingSessionPresentationStore()
    let sessions = CookingSessionPresentationModel(sessions: app.cookingSessions,
      store: commandStore, navigation: library.navigation)
    library.loadIfNeeded()
    sessions.loadIfNeeded()
    let recipe = try XCTUnwrap(library.selectedRecipe)
    library.beginEditing(recipe)
    let editor = try XCTUnwrap(library.editor)
    editor.session.title = "Preserve before leaving"
    draftStore.refusesWrites = true
    let destination = library.navigation.destination
    let focus = library.navigation.focus
    XCTAssertTrue(sessions.start(from: recipe))
    XCTAssertTrue(commandStore.pendingCommands.isEmpty)
    XCTAssertEqual(sessions.sessions.count, 1)
    let acceptedID = try XCTUnwrap(sessions.sessions.first?.id)
    XCTAssertEqual(library.navigation.destination, destination)
    XCTAssertEqual(library.navigation.focus, focus)
    XCTAssertIdentical(library.editor, editor)
    XCTAssertTrue(library.editingStorageFailed)
    sessions.retryPendingCommands()
    sessions.reloadAfterExternalStoreChange()
    XCTAssertTrue(commandStore.pendingCommands.isEmpty)
    XCTAssertEqual(sessions.sessions.map(\.id), [acceptedID])
    XCTAssertEqual(library.navigation.destination, destination)
    XCTAssertEqual(editor.session.title, "Preserve before leaving")
  }

  func testAutomaticAndExplicitRetryPreserveAcceptanceAcrossNavigationVeto() throws {
    for trigger in ["launch", "external", "explicit"] {
      for veto in [false, true] {
        let app = try AppRuntime.testing()
        let draftStore = NavigationDraftStore()
        let library = RecipeLibraryModel(library: app.libraryModel.library,
          samplePreferences: VolatileKitchenPreferencesStore(sampleRecipeOnboardingResponse: .accepted),
          kitchenWasCreated: false, editingStore: draftStore)
        library.loadIfNeeded()
        let recipe = try XCTUnwrap(library.selectedRecipe)
        library.beginEditing(recipe)
        let editor = try XCTUnwrap(library.editor)
        editor.session.title = "Keep this edit"
        draftStore.refusesWrites = veto
        let destination = library.navigation.destination
        let commandStore = VolatileCookingSessionPresentationStore()
        let id = CookingSession.ID()
        let command = PendingCookingSessionCommand.start(sessionID: id,
          recipeID: recipe.recipe.id, revisionID: recipe.revision.id, startedAt: Date())
        commandStore.pendingCommands = [command]
        let service = NavigationRetryService(base: app.cookingSessions)
        service.refusesStart = trigger != "launch"
        let sessions = CookingSessionPresentationModel(sessions: service,
          store: commandStore, navigation: library.navigation)
        sessions.loadIfNeeded()
        if trigger != "launch" {
          XCTAssertEqual(commandStore.pendingCommands, [command])
          service.refusesStart = false
          if trigger == "external" { sessions.reloadAfterExternalStoreChange() }
          else { sessions.retryCurrentIssue() }
        }
        XCTAssertTrue(commandStore.pendingCommands.isEmpty, trigger)
        XCTAssertEqual(sessions.sessions.map(\.id), [id], trigger)
        XCTAssertEqual(library.navigation.destination,
          veto ? destination : .session(id, history: nil), trigger)
        if veto {
          XCTAssertIdentical(library.editor, editor)
          XCTAssertEqual(editor.session.title, "Keep this edit")
        }
        sessions.retryCurrentIssue()
        sessions.reloadAfterExternalStoreChange()
        XCTAssertTrue(commandStore.pendingCommands.isEmpty)
        XCTAssertEqual(sessions.sessions.map(\.id), [id])
      }
    }
  }

  func testReconciliationDoesNotReportAcceptanceWhenExistingEditorCannotBePreserved() throws {
    let app = try AppRuntime.testing()
    let store = NavigationDraftStore()
    let library = RecipeLibraryModel(library: app.libraryModel.library,
      samplePreferences: VolatileKitchenPreferencesStore(sampleRecipeOnboardingResponse: .accepted),
      kitchenWasCreated: false, editingStore: store)
    library.loadIfNeeded()
    library.beginEditing()
    let editor = try XCTUnwrap(library.editor)
    store.refusesWrites = true
    let recipeID = Recipe.ID()
    let comparison = try RecipeReconciliation(kitchenID: Kitchen.ID(), revisions: [
      RecipeRevision(recipeID: recipeID, revisionNumber: 1, title: "Soup"),
      RecipeRevision(recipeID: recipeID, revisionNumber: 2, title: "Stew"),
    ], observedSelectionIDs: [])
    var windowEffects = 0
    if library.beginReconciliation(comparison) { windowEffects += 1 }
    XCTAssertEqual(windowEffects, 0)
    XCTAssertIdentical(library.editor, editor)
    XCTAssertEqual(library.navigation.destination, .editor(editor.id))
  }

  func testMiddleColumnRetainsDraftAndHistoryContextWhileDetailChanges() {
    let navigation = RecipeLibraryNavigation()
    XCTAssertTrue(navigation.move(to: .drafts))
    XCTAssertTrue(navigation.move(to: .editor(UUID())))
    XCTAssertEqual(navigation.contentDestination, .drafts)
    let recipeID = Recipe.ID(), sessionID = CookingSession.ID()
    XCTAssertTrue(navigation.move(to: .history(.recipe(recipeID))))
    XCTAssertTrue(navigation.move(to: .session(sessionID, history: .recipe(recipeID))))
    XCTAssertEqual(navigation.contentDestination, .history(.recipe(recipeID)))
    XCTAssertTrue(navigation.move(to: .finished(sessionID, history: .recipe(recipeID))))
    XCTAssertEqual(navigation.contentDestination, .history(.recipe(recipeID)))
    XCTAssertTrue(navigation.browseRecipes {})
    XCTAssertEqual(navigation.contentDestination, .recipes)
  }

  func testAuxiliarySelectionRoutesToItsListAndRespectsDraftVeto() {
    let navigation = RecipeLibraryNavigation()
    let recipeID = Recipe.ID()
    XCTAssertTrue(navigation.selectAuxiliary(.deletedRecipe(recipeID)))
    XCTAssertEqual(navigation.destination, .deletedItems)
    XCTAssertEqual(navigation.contentDestination, .deletedItems)
    XCTAssertEqual(navigation.auxiliarySelection, .deletedRecipe(recipeID))
    XCTAssertTrue(navigation.move(to: .editor(UUID())))
    navigation.prepareToLeaveEditor = { false }
    XCTAssertFalse(navigation.selectAuxiliary(.organization))
    XCTAssertEqual(navigation.contentDestination, .drafts)
    navigation.prepareToLeaveEditor = { true }
    XCTAssertTrue(navigation.selectAuxiliary(.organization))
    XCTAssertEqual(navigation.destination, .recovery)
    XCTAssertEqual(navigation.contentDestination, .recovery)
    XCTAssertEqual(navigation.auxiliarySelection, .organization)
  }

  func testContinuingFinishedSessionKeepsHistoryPopulatedAndScoped() throws {
    for recipeScoped in [false, true] {
      let app = try AppRuntime.testing()
      let library = app.libraryModel, sessions = app.sessionModel
      library.loadIfNeeded()
      sessions.loadIfNeeded()
      let recipe = try XCTUnwrap(library.selectedRecipe)
      XCTAssertTrue(sessions.start(from: recipe))
      let finishedID = try XCTUnwrap(sessions.currentSessionID)
      XCTAssertTrue(sessions.finishCurrentSession())
      if recipeScoped {
        XCTAssertTrue(sessions.showRecipeSessionHistory(for: recipe.id))
        XCTAssertTrue(sessions.observeFinishedSession(finishedID))
      }
      XCTAssertTrue(sessions.continueSession(finishedID))
      let continuedID = try XCTUnwrap(sessions.currentSessionID)
      XCTAssertNil(sessions.historyScope)
      XCTAssertEqual(Set(sessions.displayedHistorySessions.map(\.id)), [finishedID, continuedID])
      XCTAssertTrue(sessions.observeFinishedSession(finishedID))
      XCTAssertEqual(sessions.historyScope, recipeScoped ? .recipe(recipe.id) : .all)
    }
  }

  func testSuccessfulDraftRemovalDoesNotAskForAnotherWriteBeforeLeaving() throws {
    for savesRecipe in [false, true] {
      let app = try AppRuntime.testing()
      let store = NavigationDraftStore()
      let library = RecipeLibraryModel(
        library: app.libraryModel.library,
        samplePreferences: VolatileKitchenPreferencesStore(sampleRecipeOnboardingResponse: .accepted),
        kitchenWasCreated: false, editingStore: store
      )
      library.loadIfNeeded()
      library.beginEditing()
      library.editor?.session.title = "Complete this action"
      store.refusesWritesAfterRemoval = true
      if savesRecipe {
        XCTAssertTrue(library.saveEditor())
      } else {
        library.discardEditor(confirmed: true)
      }
      XCTAssertTrue(library.drafts.drafts.isEmpty)
      XCTAssertNil(library.editor)
      XCTAssertEqual(library.navigation.destination, .recipe)
      XCTAssertFalse(library.editingStorageFailed)
    }
  }

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
                                       openImport: { openedImport = true }, focusDestination: { _ in focused = true })
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
  var refusesWritesAfterRemoval = false
  private var records: [RecipeEditingRecord] = []
  func load() throws -> [RecipeEditingRecord] { records }
  func save(_ records: [RecipeEditingRecord]) throws {
    if refusesWrites { throw CocoaError(.fileWriteUnknown) }
    self.records = records
    if refusesWritesAfterRemoval && records.isEmpty { refusesWrites = true }
  }
}

@MainActor
private final class NavigationRetryService: CookingSessionServing {
  let base: any CookingSessionServing
  var refusesStart = false
  init(base: any CookingSessionServing) { self.base = base }
  func sessions() throws -> [SessionProjectionResult] { try base.sessions() }
  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    if refusesStart { throw CookingSessionLogicError.sessionWriteFailed }
    return try base.start(intention)
  }
  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    try base.perform(intention)
  }
}
