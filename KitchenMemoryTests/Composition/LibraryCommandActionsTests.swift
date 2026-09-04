// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import KitchenKit
import XCTest

@MainActor
final class LibraryCommandActionsTests: XCTestCase {
#if os(macOS)
  func testImportMenuWorksWithoutAWindowButDoesNotBypassBlockedWindowActions() throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    var appDialogCount = 0
    var windowDialogCount = 0
    let fallback = RecipeLibraryCommands.resolveImportActions(
      app: app, focused: nil, libraryWindowPresent: false, openImport: { appDialogCount += 1 }
    )
    XCTAssertTrue(try XCTUnwrap(fallback).perform(.importRecipe))
    XCTAssertEqual(appDialogCount, 1)
    let focused = LibraryCommandActions(
      library: app.libraryModel, sessions: app.sessionModel, openImport: { windowDialogCount += 1 }
    )
    let routed = RecipeLibraryCommands.resolveImportActions(
      app: app, focused: focused, libraryWindowPresent: true, openImport: { appDialogCount += 1 }
    )
    XCTAssertTrue(try XCTUnwrap(routed).perform(.importRecipe))
    XCTAssertEqual(windowDialogCount, 1)
    XCTAssertEqual(appDialogCount, 1)
    XCTAssertNil(RecipeLibraryCommands.resolveImportActions(
      app: app, focused: nil, libraryWindowPresent: true, openImport: { appDialogCount += 1 }
    ))
    XCTAssertNil(RecipeLibraryCommands.resolveImportActions(
      app: nil, focused: nil, libraryWindowPresent: false, openImport: { appDialogCount += 1 }
    ))
    XCTAssertTrue(focused.perform(.newRecipe))
    app.libraryModel.editor?.confirmsDiscard = true
    XCTAssertFalse(try XCTUnwrap(fallback).perform(.importRecipe))
    XCTAssertEqual(appDialogCount, 1)
  }
#endif

  func testNavigationRetainsDraftAndCandidateCannotPublishFromSaveCommand() throws {
    let app = try AppRuntime.testing()
    let actions = LibraryCommandActions(library: app.libraryModel, sessions: app.sessionModel)
    app.libraryModel.loadIfNeeded()
    app.sessionModel.loadIfNeeded()
    XCTAssertFalse(actions.canPerform(.drafts))
    XCTAssertTrue(actions.perform(.newRecipe))
    let draft = try XCTUnwrap(app.libraryModel.editor)
    draft.session.title = "Retain on menu navigation"
    draft.confirmsDiscard = true
    XCTAssertFalse(actions.perform(.newRecipe))
    XCTAssertFalse(actions.perform(.saveRevision))
    draft.confirmsDiscard = false
    XCTAssertTrue(actions.perform(.drafts))
    XCTAssertNil(app.libraryModel.editor)
    XCTAssertTrue(app.libraryModel.isShowingDrafts)
    XCTAssertEqual(app.libraryModel.editingDrafts.first?.id, draft.id)
    XCTAssertTrue(actions.perform(.deletedItems))
    XCTAssertTrue(app.sessionModel.isShowingDeletedItems)
    XCTAssertTrue(app.libraryModel.beginImportReview(RecipeImportOption(
      id: .init(blockIndex: 0, objectIndex: 0), draft: RecipeDraft(title: "Candidate"), concerns: []
    )))
    XCTAssertFalse(actions.canPerform(.saveRevision))
    XCTAssertFalse(actions.perform(.saveRevision))
    try app.installRecoveryNavigationFixture()
    app.sessionModel.reload()
    XCTAssertTrue(actions.perform(.recovery))
    XCTAssertTrue(app.sessionModel.isShowingRecovery)
  }

  func testIndependentCommandContextsDoNotRouteToAnotherLibrary() throws {
    let first = try AppRuntime.testing()
    let second = try AppRuntime.testing()
    first.libraryModel.loadIfNeeded()
    second.libraryModel.loadIfNeeded()
    var importWindow: Int?
    let actions = LibraryCommandActions(library: first.libraryModel, sessions: first.sessionModel,
                                       openImport: { importWindow = 1 })
    let otherActions = LibraryCommandActions(library: second.libraryModel, sessions: second.sessionModel,
                                            openImport: { importWindow = 2 })
    XCTAssertTrue(otherActions.perform(.importRecipe))
    XCTAssertEqual(importWindow, 2)
    XCTAssertTrue(actions.perform(.importRecipe))
    XCTAssertEqual(importWindow, 1)
    XCTAssertTrue(actions.perform(.newRecipe))
    XCTAssertNotNil(first.libraryModel.editor)
    XCTAssertNil(second.libraryModel.editor)
    first.libraryModel.closeEditor()
    let recipe = try XCTUnwrap(first.libraryModel.recipes.first)
    first.libraryModel.selectRecipeForReading(recipe.id)
    XCTAssertTrue(actions.perform(.recipeHistory))
    XCTAssertTrue(first.sessionModel.isShowingSessionHistory)
    XCTAssertFalse(second.sessionModel.isShowingSessionHistory)
  }

  func testCommandsFollowSelectionAndExplicitDraftSaveAvailability() throws {
    let app = try AppRuntime.testing()
    let actions = LibraryCommandActions(library: app.libraryModel, sessions: app.sessionModel)
    XCTAssertFalse(actions.canPerform(.newRecipe))
    app.libraryModel.loadIfNeeded()
    app.sessionModel.loadIfNeeded()
    app.libraryModel.selectedRecipeID = nil
    XCTAssertFalse(actions.canPerform(.editRecipe))
    XCTAssertFalse(actions.canPerform(.saveRevision))
    XCTAssertFalse(actions.canPerform(.recovery))
    let recipe = try XCTUnwrap(app.libraryModel.recipes.first)
    app.libraryModel.selectRecipeForReading(recipe.id)
    XCTAssertTrue(actions.perform(.editRecipe))
    XCTAssertEqual(app.libraryModel.editor?.original?.id, recipe.id)
    XCTAssertFalse(actions.canPerform(.startCooking))
    app.libraryModel.editor?.session.title = ""
    XCTAssertFalse(actions.perform(.saveRevision))
    app.libraryModel.editor?.session.title = "Menu-authored revision"
    XCTAssertTrue(actions.perform(.saveRevision))
    XCTAssertEqual(app.libraryModel.selectedRecipe?.revision.title, "Menu-authored revision")
    XCTAssertTrue(actions.perform(.startCooking))
    XCTAssertEqual(app.sessionModel.currentSession?.snapshot.title, "Menu-authored revision")
    XCTAssertFalse(actions.canPerform(.editRecipe))
    XCTAssertTrue(actions.perform(.sessions))
    XCTAssertTrue(app.sessionModel.isShowingSessionHistory)
  }
}
