// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import KitchenKit
import Foundation
import XCTest

@MainActor
final class CookingSessionReadingPresentationTests: XCTestCase {
  func testIncomingProgressAndStopResumePreserveInitialChoiceAndPlace() throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let recipe = try XCTUnwrap(app.libraryModel.selectedRecipe)
    let model = app.sessionModel
    model.loadIfNeeded()
    XCTAssertTrue(model.start(from: recipe))
    let session = try XCTUnwrap(model.currentSession)
    let first = try XCTUnwrap(session.snapshot.instructionSections.flatMap(\.steps).first)
    let position = CookingSessionReadingPosition(instructionID: first.id, offset: 24)
    let otherWindow = CookingSessionPresentationModel(sessions: app.cookingSessions,
      store: VolatileCookingSessionPresentationStore())
    otherWindow.loadIfNeeded()
    otherWindow.select(session.id)
    XCTAssertTrue(otherWindow.setInstruction(first.id, to: .completed))
    model.reloadAfterExternalStoreChange()
    let updated = try XCTUnwrap(model.currentSession)
    XCTAssertEqual(model.readingPreference(for: updated).emphasizedInstructionID, first.id)
    XCTAssertNil(model.readingPreference(for: updated).position)
    model.rememberReadingPosition(position, in: updated)
    XCTAssertNil(model.readingCompletion)
    XCTAssertTrue(model.stopCurrentSession())
    XCTAssertTrue(model.resumeCurrentSession())
    XCTAssertEqual(model.readingPreference(for: try XCTUnwrap(model.currentSession)).position, position)
    XCTAssertNil(model.readingCompletion)
  }

  func testCorruptReadingStorageAndMissingSnapshotAnchorsFallBackAndReset() throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let defaults = try makeTestUserDefaults(suiteNamePrefix: "ReadingFallback").defaults
    let store = DefaultsCookingSessionPresentationStore(defaults: defaults)
    defaults.set(Data([0, 255]), forKey: DefaultsCookingSessionPresentationStore.readingPreferencesKey)
    XCTAssertTrue(store.readingPreferences.isEmpty)
    let model = CookingSessionPresentationModel(sessions: app.cookingSessions, store: store)
    model.loadIfNeeded()
    XCTAssertTrue(model.start(from: try XCTUnwrap(app.libraryModel.selectedRecipe)))
    let session = try XCTUnwrap(model.currentSession)
    let first = session.snapshot.instructionSections.flatMap(\.steps).first?.id
    let missing = SessionInstruction.ID(rawValue: UUID())
    store.readingPreferences = [.init(sessionID: session.id, emphasizedInstructionID: missing,
      position: .init(instructionID: missing, offset: 80), keepsScreenAwake: false),]
    let reopened = CookingSessionPresentationModel(sessions: app.cookingSessions, store: store)
    reopened.loadIfNeeded()
    let preference = reopened.readingPreference(for: try XCTUnwrap(reopened.currentSession))
    XCTAssertEqual(preference.emphasizedInstructionID, first)
    XCTAssertNil(preference.position)
    XCTAssertFalse(preference.keepsScreenAwake)
    reopened.resetAfterKitchenReset()
    XCTAssertTrue(store.readingPreferences.isEmpty)
  }

  func testOnlyCompletingTheEmphasizedOpenStepAdvancesWithoutWrappingOrFinishing() throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let model = app.sessionModel
    model.loadIfNeeded()
    XCTAssertTrue(model.start(from: try XCTUnwrap(app.libraryModel.selectedRecipe)))
    let session = try XCTUnwrap(model.currentSession)
    let steps = session.snapshot.instructionSections.flatMap(\.steps)
    XCTAssertGreaterThan(steps.count, 1)
    let first = try XCTUnwrap(steps.first), last = try XCTUnwrap(steps.last)
    XCTAssertTrue(model.setInstruction(first.id, to: .skipped))
    XCTAssertEqual(model.readingPreference(for: session).emphasizedInstructionID, first.id)
    XCTAssertNil(model.readingCompletion)
    XCTAssertTrue(model.setInstruction(first.id, to: .open))
    if let ingredient = session.snapshot.ingredientSections.flatMap(\.ingredients).first {
      XCTAssertTrue(model.setIngredient(ingredient.id, to: .accounted))
      XCTAssertEqual(model.readingPreference(for: session).emphasizedInstructionID, first.id)
      XCTAssertNil(model.readingCompletion)
    }
    model.chooseReadingInstruction(last.id, in: session)
    XCTAssertTrue(model.setInstruction(first.id, to: .completed))
    XCTAssertEqual(model.readingPreference(for: session).emphasizedInstructionID, last.id)
    XCTAssertNil(model.readingCompletion)
    model.chooseReadingInstruction(first.id, in: session)
    XCTAssertTrue(model.setInstruction(first.id, to: .open))
    XCTAssertEqual(model.readingPreference(for: session).emphasizedInstructionID, first.id)
    XCTAssertNil(model.readingCompletion)
    XCTAssertTrue(model.setInstruction(first.id, to: .completed))
    XCTAssertEqual(model.readingPreference(for: session).emphasizedInstructionID, steps[1].id)
    XCTAssertEqual(model.readingCompletion?.nextInstructionID, steps[1].id)

    model.chooseReadingInstruction(last.id, in: session)
    XCTAssertTrue(model.setInstruction(last.id, to: .completed))

    XCTAssertNil(model.readingPreference(for: session).emphasizedInstructionID)
    XCTAssertNil(model.readingCompletion?.nextInstructionID)
    XCTAssertEqual(model.currentSession?.lifecycle, .active)
    XCTAssertNil(model.currentSession?.selectedClosureID)
  }

  func testChosenStepAndPositionSurviveRelaunchWithoutLeakingToAnotherCook() throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let recipe = try XCTUnwrap(app.libraryModel.selectedRecipe)
    let defaults = try makeTestUserDefaults(suiteNamePrefix: "SessionReading").defaults
    let model = CookingSessionPresentationModel(sessions: app.cookingSessions,
      store: DefaultsCookingSessionPresentationStore(defaults: defaults))
    model.loadIfNeeded()
    XCTAssertTrue(model.start(from: recipe))
    let first = try XCTUnwrap(model.currentSession)
    let last = try XCTUnwrap(first.snapshot.instructionSections.flatMap(\.steps).last)
    model.chooseReadingInstruction(last.id, in: first)
    model.rememberReadingPosition(.init(instructionID: last.id, offset: 37), in: first)
    model.setKeepsScreenAwake(false, in: first)
    XCTAssertTrue(model.start(from: recipe))
    let second = try XCTUnwrap(model.currentSession)
    XCTAssertNil(model.readingPreference(for: second).position)
    XCTAssertTrue(model.readingPreference(for: second).keepsScreenAwake)
    model.select(first.id)

    let reopened = CookingSessionPresentationModel(sessions: app.cookingSessions,
      store: DefaultsCookingSessionPresentationStore(defaults: defaults))
    reopened.loadIfNeeded()

    let preference = reopened.readingPreference(for: try XCTUnwrap(reopened.currentSession))
    XCTAssertEqual(preference.emphasizedInstructionID, last.id)
    XCTAssertEqual(preference.position, .init(instructionID: last.id, offset: 37))
    XCTAssertFalse(preference.keepsScreenAwake)
    XCTAssertEqual(reopened.currentSession?.lifecycle, .active)
    XCTAssertTrue(reopened.pendingCommands.isEmpty)
  }

  func testChoosingReadingStepDoesNotChangeProgressOrLifecycle() throws {
    let app = try AppRuntime.testing()
    app.libraryModel.loadIfNeeded()
    let model = app.sessionModel
    model.loadIfNeeded()
    XCTAssertTrue(model.start(from: try XCTUnwrap(app.libraryModel.selectedRecipe)))
    let session = try XCTUnwrap(model.currentSession)
    let steps = session.snapshot.instructionSections.flatMap(\.steps)
    let last = try XCTUnwrap(steps.last)

    XCTAssertEqual(model.readingPreference(for: session).emphasizedInstructionID, steps.first?.id)
    model.chooseReadingInstruction(last.id, in: session)

    XCTAssertEqual(model.readingPreference(for: session).emphasizedInstructionID, last.id)
    XCTAssertEqual(model.currentSession?.progress, session.progress)
    XCTAssertEqual(model.currentSession?.lifecycle, .active)
    XCTAssertTrue(model.pendingCommands.isEmpty)
  }
}
