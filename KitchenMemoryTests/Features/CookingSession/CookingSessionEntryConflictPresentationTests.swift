// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import Foundation
import KitchenKit
import XCTest

@MainActor
extension CookingSessionEntryPresentationTests {
  // swiftlint:disable:next function_body_length
  func testTargetLabelsDisambiguateRepeatedAuthoredTextBySnapshotPosition() {
    let firstIngredient = SessionIngredient.ID()
    let secondIngredient = SessionIngredient.ID()
    let firstInstruction = SessionInstruction.ID()
    let secondInstruction = SessionInstruction.ID()
    let snapshot = ExecutionSnapshot(
      title: "Soup",
      ingredientSections: [
        SessionIngredientSection(title: nil, ingredients: [
          SessionIngredient(
            id: firstIngredient,
            sourceIngredientID: nil,
            value: RecipeIngredient(originalText: "1 lime")
          ),
        ]),
        SessionIngredientSection(title: nil, ingredients: [
          SessionIngredient(
            id: secondIngredient,
            sourceIngredientID: nil,
            value: RecipeIngredient(originalText: "1 lime")
          ),
        ]),
      ],
      instructionSections: [
        SessionInstructionSection(title: nil, steps: [
          SessionInstruction(
            id: firstInstruction,
            sourceInstructionID: nil,
            value: InstructionStep(text: "Stir")
          ),
          SessionInstruction(
            id: secondInstruction,
            sourceInstructionID: nil,
            value: InstructionStep(text: "Stir")
          ),
        ]),
      ],
    )
    let expectations = [
      (
        "en-US",
        [
          "Ingredient 1.1 — 1 lime",
          "Ingredient 2.1 — 1 lime",
          "Instruction 1.1 — Stir",
          "Instruction 1.2 — Stir",
        ]
      ),
      (
        "fr-CA",
        [
          "Ingrédient 1.1 — 1 lime",
          "Ingrédient 2.1 — 1 lime",
          "Instruction 1.1 — Stir",
          "Instruction 1.2 — Stir",
        ]
      ),
      (
        "es-MX",
        [
          "Ingrediente 1.1 — 1 lime",
          "Ingrediente 2.1 — 1 lime",
          "Instrucción 1.1 — Stir",
          "Instrucción 1.2 — Stir",
        ]
      ),
    ]

    for (localeIdentifier, expectedLabels) in expectations {
      let presentation = SessionEntryTargetPresentation(
        snapshot: snapshot,
        locale: Locale(identifier: localeIdentifier)
      )
      XCTAssertEqual(presentation.options.map(\.label), expectedLabels)
    }
  }

  // Exercises the real evidence repository, projector, Logic command path, and
  // presentation model so conflict resolution cannot be faked by a permissive service.
  // swiftlint:disable:next function_body_length
  func testConcurrentEntryEditsRetainEvidenceAndResolveCausally() throws {
    let preparedApp = try AppRuntime.testing()
    preparedApp.libraryModel.loadIfNeeded()
    preparedApp.sessionModel.loadIfNeeded()
    let recipe = try XCTUnwrap(preparedApp.libraryModel.recipes.first)
    XCTAssertTrue(preparedApp.sessionModel.start(from: recipe))
    let session = try XCTUnwrap(preparedApp.sessionModel.currentSession)
    let ingredientID = try XCTUnwrap(
      session.snapshot.ingredientSections.first?.ingredients.first?.id
    )
    let instructionID = try XCTUnwrap(
      session.snapshot.instructionSections.first?.steps.first?.id
    )
    preparedApp.sessionModel.updateCurrentEntryDraft(text: "Original", target: nil)
    XCTAssertTrue(preparedApp.sessionModel.submitCurrentEntryDraft())
    let entryID = try XCTUnwrap(preparedApp.sessionModel.currentSession?.entries.first?.id)
    let submittedEvidence = try XCTUnwrap(
      preparedApp.cookingSessionRepository.evidence(id: session.id)
    )
    let root = try XCTUnwrap(submittedEvidence.roots.first)
    let submitFact = try XCTUnwrap(submittedEvidence.facts.first)
    let ingredientEdit = try concurrentSessionFact(
      sessionID: session.id,
      kitchenID: root.kitchenID,
      head: submitFact.id,
      kind: .sessionEntry,
      target: .ingredient(ingredientID),
      payload: .sessionEntry(.revise(entryID: entryID, text: "More lime"))
    )
    let instructionEdit = try concurrentSessionFact(
      sessionID: session.id,
      kitchenID: root.kitchenID,
      head: submitFact.id,
      kind: .sessionEntry,
      target: .instruction(instructionID),
      payload: .sessionEntry(.revise(entryID: entryID, text: "More lime"))
    )
    try preparedApp.cookingSessionRepository.append(.activity(ingredientEdit))
    try preparedApp.cookingSessionRepository.append(.activity(instructionEdit))
    preparedApp.sessionModel.reloadAfterExternalStoreChange()

    let conflicted = try XCTUnwrap(preparedApp.sessionModel.currentSession)
    XCTAssertTrue(conflicted.entries.isEmpty)
    guard case let .entry(conflictedID, factIDs, values) = try XCTUnwrap(
      conflicted.conflicts.first
    ) else {
      XCTFail("Expected concurrent Entry edits")
      return
    }
    XCTAssertEqual(conflictedID, entryID)
    XCTAssertEqual(Set(factIDs), Set([ingredientEdit.id, instructionEdit.id]))
    XCTAssertTrue(values.contains(.present(SessionEntry(
      id: entryID,
      target: .ingredient(ingredientID),
      text: "More lime"
    ))))
    XCTAssertTrue(values.contains(.present(SessionEntry(
      id: entryID,
      target: .instruction(instructionID),
      text: "More lime"
    ))))

    XCTAssertTrue(preparedApp.sessionModel.reviseEntry(
      entryID,
      text: "Resolved without flattening history",
      target: .instruction(instructionID)
    ))
    let resolved = try XCTUnwrap(preparedApp.sessionModel.currentSession)
    XCTAssertTrue(resolved.conflicts.isEmpty)
    XCTAssertEqual(resolved.entries, [
      SessionEntry(
        id: entryID,
        target: .instruction(instructionID),
        text: "Resolved without flattening history"
      ),
    ])
    let retainedEvidence = try XCTUnwrap(
      preparedApp.cookingSessionRepository.evidence(id: session.id)
    )
    XCTAssertEqual(retainedEvidence.facts.count, 4)
    XCTAssertEqual(
      try decodedPayload(in: retainedEvidence, factID: ingredientEdit.id),
      .sessionEntry(.revise(entryID: entryID, text: "More lime"))
    )
    XCTAssertEqual(
      try decodedPayload(in: retainedEvidence, factID: instructionEdit.id),
      .sessionEntry(.revise(entryID: entryID, text: "More lime"))
    )
  }
}
