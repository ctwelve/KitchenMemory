// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import Foundation
import KitchenKit
import XCTest

@MainActor
final class CookingSessionProgressPresentationTests: XCTestCase {
  func testIngredientProgressTargetsSnapshotIdentityWithResultingState() throws {
    let fixture = ProgressPresentationFixture()

    XCTAssertTrue(fixture.model.setIngredient(fixture.ingredientID, to: .accounted))

    guard case let .progress(intention, progress) = try XCTUnwrap(
      fixture.service.intentions.first
    ) else {
      XCTFail("Expected an ingredient progress intention")
      return
    }
    XCTAssertEqual(intention.sessionID, fixture.sessionID)
    XCTAssertEqual(progress.target, .ingredient(fixture.ingredientID))
    XCTAssertEqual(progress.state, .ingredient(.accounted))
    XCTAssertEqual(fixture.model.currentSession?.progress, [progress])
  }

  func testRapidIndependentProgressSurvivesInterruptionAndRetriesInOrder() throws {
    let fixture = ProgressPresentationFixture()
    fixture.service.rejectsCommands = true

    XCTAssertFalse(fixture.model.setIngredient(fixture.ingredientID, to: .accounted))
    XCTAssertFalse(fixture.model.setInstruction(fixture.instructionID, to: .completed))

    XCTAssertEqual(fixture.store.pendingCommands.count, 2)
    XCTAssertEqual(
      Set(try XCTUnwrap(fixture.model.currentSession).progress),
      [
        SessionProgress(
          target: .ingredient(fixture.ingredientID),
          state: .ingredient(.accounted)
        ),
        SessionProgress(
          target: .instruction(fixture.instructionID),
          state: .instruction(.completed)
        ),
      ]
    )
    let firstFactIDs = fixture.service.intentions.compactMap(\.progressFactID)
    XCTAssertFalse(firstFactIDs.isEmpty)
    XCTAssertEqual(Set(firstFactIDs).count, 1)

    fixture.service.rejectsCommands = false
    fixture.model.retryPendingCommands()

    XCTAssertTrue(fixture.store.pendingCommands.isEmpty)
    let attempts = fixture.service.intentions.compactMap(\.progressValue)
    XCTAssertEqual(attempts.suffix(2).map(\.target), [
      .ingredient(fixture.ingredientID),
      .instruction(fixture.instructionID),
    ])
    XCTAssertEqual(Set(try XCTUnwrap(fixture.model.currentSession).progress), Set(attempts.suffix(2)))
  }

  func testLaterResultingStateForSameTargetRemainsAuthoritativeAfterRetry() throws {
    let fixture = ProgressPresentationFixture()
    fixture.service.rejectsCommands = true

    XCTAssertFalse(fixture.model.setIngredient(fixture.ingredientID, to: .accounted))
    XCTAssertFalse(fixture.model.setIngredient(fixture.ingredientID, to: .open))
    XCTAssertEqual(
      fixture.model.currentSession?.progress,
      [SessionProgress(target: .ingredient(fixture.ingredientID), state: .ingredient(.open))]
    )

    fixture.service.rejectsCommands = false
    fixture.model.retryPendingCommands()

    XCTAssertEqual(
      fixture.model.currentSession?.progress,
      [SessionProgress(target: .ingredient(fixture.ingredientID), state: .ingredient(.open))]
    )
  }

  func testWorkingScaleReplacementRecomputesFromSnapshotInsteadOfCompounding() throws {
    let fixture = WorkingScalePresentationFixture()
    let requested = try XCTUnwrap(RecipeScale(
      baseYield: RationalQuantity(numerator: 2),
      workingYield: RationalQuantity(numerator: 3)
    ))

    XCTAssertTrue(fixture.model.replaceWorkingScale(with: requested))

    guard case let .replaceWorkingScale(_, replacement) = try XCTUnwrap(
      fixture.service.intentions.first
    )
    else {
      XCTFail("Expected a complete working-scale replacement")
      return
    }
    XCTAssertEqual(replacement.exactScale, RationalQuantity(numerator: 3, denominator: 2))
    XCTAssertEqual(
      replacement.quantities.first?.quantity.lowerBound,
      RationalQuantity(numerator: 3, denominator: 2)
    )
    XCTAssertEqual(
      fixture.model.currentSession?.snapshot.ingredientSections.first?.ingredients.first?
        .value.quantity?.lowerBound,
      RationalQuantity(numerator: 1)
    )
  }

  func testRapidScaleReplacementsRetryWithoutCompounding() throws {
    let fixture = WorkingScalePresentationFixture()
    fixture.service.rejectsCommands = true
    let first = try XCTUnwrap(RecipeScale(
      baseYield: RationalQuantity(numerator: 2),
      workingYield: RationalQuantity(numerator: 3)
    ))
    let second = try XCTUnwrap(RecipeScale(
      baseYield: RationalQuantity(numerator: 2),
      workingYield: RationalQuantity(numerator: 4)
    ))

    XCTAssertFalse(fixture.model.replaceWorkingScale(with: first))
    XCTAssertFalse(fixture.model.replaceWorkingScale(with: second))
    XCTAssertEqual(fixture.model.currentSession?.workingScale?.exactScale, second.multiplier)

    fixture.service.rejectsCommands = false
    fixture.model.retryPendingCommands()

    XCTAssertEqual(fixture.model.currentSession?.workingScale?.exactScale, second.multiplier)
    let accepted = fixture.service.intentions.compactMap(\.workingScaleValue).suffix(2)
    XCTAssertEqual(accepted.map(\.exactScale), [first.multiplier, second.multiplier])
    XCTAssertEqual(
      accepted.compactMap { $0.quantities.first?.quantity.lowerBound },
      [
        RationalQuantity(numerator: 3, denominator: 2),
        RationalQuantity(numerator: 2),
      ]
    )
  }
}

@MainActor
private struct WorkingScalePresentationFixture {
  let service: WorkingScaleSessionService
  let model: CookingSessionPresentationModel

  init() {
    let sessionID = CookingSession.ID()
    let ingredientID = SessionIngredient.ID()
    let ingredient = SessionIngredient(
      id: ingredientID,
      sourceIngredientID: RecipeIngredient.ID(),
      value: RecipeIngredient(
        originalText: "1 cup broth",
        quantity: exactQuantity(1),
        unitText: "cup",
        ingredientText: "broth",
        parseState: .reviewed
      )
    )
    let session = CookingSessionProjection(
      id: sessionID,
      snapshot: ExecutionSnapshot(
        title: "Soup",
        baseYield: RecipeYield(
          quantity: exactQuantity(2),
          unitText: "servings",
          originalText: "2 servings"
        ),
        ingredientSections: [
          SessionIngredientSection(title: nil, ingredients: [ingredient]),
        ]
      ),
      workingScale: SessionWorkingScale(
        workingYield: RecipeYield(
          quantity: exactQuantity(4),
          unitText: "servings",
          originalText: "2 servings"
        ),
        exactScale: RationalQuantity(numerator: 2),
        quantities: [
          SessionIngredientQuantity(ingredientID: ingredientID, quantity: exactQuantity(2)),
        ]
      )
    )
    service = WorkingScaleSessionService(session: session)
    let store = VolatileCookingSessionPresentationStore()
    store.currentSessionID = sessionID
    model = CookingSessionPresentationModel(sessions: service, store: store)
    model.loadIfNeeded()
  }
}

private func exactQuantity(_ value: Int) -> QuantityExpression {
  QuantityExpression(kind: .exact, lowerBound: RationalQuantity(numerator: value))
}

@MainActor
private struct ProgressPresentationFixture {
  let sessionID = CookingSession.ID()
  let ingredientID = SessionIngredient.ID()
  let instructionID = SessionInstruction.ID()
  let service: ProgressSessionService
  let store = VolatileCookingSessionPresentationStore()
  let model: CookingSessionPresentationModel

  init() {
    let session = CookingSessionProjection(
      id: sessionID,
      snapshot: ExecutionSnapshot(
        title: "Soup",
        ingredientSections: [
          SessionIngredientSection(
            title: nil,
            ingredients: [
              SessionIngredient(
                id: ingredientID,
                sourceIngredientID: RecipeIngredient.ID(),
                value: RecipeIngredient(originalText: "1 onion")
              ),
            ]
          ),
        ],
        instructionSections: [
          SessionInstructionSection(
            title: nil,
            steps: [
              SessionInstruction(
                id: instructionID,
                sourceInstructionID: InstructionStep.ID(),
                value: InstructionStep(text: "Simmer")
              ),
            ]
          ),
        ]
      )
    )
    service = ProgressSessionService(session: session)
    store.currentSessionID = sessionID
    model = CookingSessionPresentationModel(sessions: service, store: store)
    model.loadIfNeeded()
  }
}

@MainActor
private final class ProgressSessionService: CookingSessionServing {
  private(set) var session: CookingSessionProjection
  private(set) var intentions: [CookingSessionIntention] = []
  var rejectsCommands = false

  init(session: CookingSessionProjection) {
    self.session = session
  }

  func sessions() throws -> [SessionProjectionResult] { [.session(session)] }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    throw CookingSessionLogicError.invalidIntention
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    intentions.append(intention)
    if rejectsCommands { throw CookingSessionLogicError.sessionWriteFailed }
    guard case let .progress(_, progress) = intention else {
      throw CookingSessionLogicError.invalidIntention
    }
    var values = session.progress.filter { $0.target != progress.target }
    values.append(progress)
    session = session.replacingProgress(values)
    return .accepted(session)
  }
}

@MainActor
private final class WorkingScaleSessionService: CookingSessionServing {
  private var session: CookingSessionProjection
  private(set) var intentions: [CookingSessionIntention] = []
  var rejectsCommands = false

  init(session: CookingSessionProjection) {
    self.session = session
  }

  func sessions() throws -> [SessionProjectionResult] { [.session(session)] }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    throw CookingSessionLogicError.invalidIntention
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    intentions.append(intention)
    if rejectsCommands { throw CookingSessionLogicError.sessionWriteFailed }
    guard case let .replaceWorkingScale(_, scale) = intention else {
      throw CookingSessionLogicError.invalidIntention
    }
    session = CookingSessionProjection(
      id: session.id,
      snapshot: session.snapshot,
      lifecycle: session.lifecycle,
      lifecycleBeforeFinish: session.lifecycleBeforeFinish,
      disposition: session.disposition,
      progress: session.progress,
      workingScale: scale,
      entries: session.entries,
      outcome: session.outcome,
      conflicts: session.conflicts,
      selectedClosureID: session.selectedClosureID,
      lateEvidence: session.lateEvidence
    )
    return .accepted(session)
  }
}

private extension CookingSessionIntention {
  var workingScaleValue: SessionWorkingScale? {
    guard case let .replaceWorkingScale(_, value) = self else { return nil }
    return value
  }
}

private extension CookingSessionIntention {
  var progressFactID: SessionFact.ID? {
    guard case let .progress(intention, _) = self else { return nil }
    return intention.id
  }

  var progressValue: SessionProgress? {
    guard case let .progress(_, progress) = self else { return nil }
    return progress
  }
}

private extension CookingSessionProjection {
  func replacingProgress(_ progress: [SessionProgress]) -> Self {
    CookingSessionProjection(
      id: id,
      snapshot: snapshot,
      lifecycle: lifecycle,
      lifecycleBeforeFinish: lifecycleBeforeFinish,
      disposition: disposition,
      progress: progress,
      workingScale: workingScale,
      entries: entries,
      outcome: outcome,
      conflicts: conflicts,
      selectedClosureID: selectedClosureID,
      lateEvidence: lateEvidence
    )
  }
}
