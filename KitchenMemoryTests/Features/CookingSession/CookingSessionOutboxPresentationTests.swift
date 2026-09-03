// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import KitchenKit
import XCTest

@MainActor
final class CookingSessionOutboxPresentationTests: XCTestCase {
  func testFailureAtEachPositionPreventsLaterCommandsFromOvertaking() throws {
    let fixture = OutboxPositionFixture()
    fixture.service.rejectsCommands = true
    XCTAssertFalse(fixture.model.setIngredient(fixture.ingredientID, to: .accounted))
    XCTAssertFalse(fixture.model.setInstruction(fixture.instructionID, to: .completed))
    XCTAssertFalse(fixture.model.setIngredient(fixture.ingredientID, to: .open))
    let original = fixture.store.pendingCommands
    XCTAssertEqual(original.count, 3)

    fixture.service.rejectsCommands = false
    fixture.service.failureAttemptNumbers = [fixture.service.intentions.count + 2]
    fixture.model.retryPendingCommands()
    XCTAssertEqual(fixture.store.pendingCommands, Array(original.dropFirst()))
    XCTAssertEqual(
      fixture.service.intentions.suffix(2).compactMap(\.progressFactID),
      original.prefix(2).compactMap(\.progressFactID)
    )

    fixture.service.failureAttemptNumbers = [fixture.service.intentions.count + 2]
    fixture.model.retryPendingCommands()
    XCTAssertEqual(fixture.store.pendingCommands, [try XCTUnwrap(original.last)])
    XCTAssertEqual(
      fixture.service.intentions.suffix(2).compactMap(\.progressFactID),
      original.suffix(2).compactMap(\.progressFactID)
    )

    fixture.service.failureAttemptNumbers = []
    fixture.model.retryPendingCommands()
    XCTAssertTrue(fixture.store.pendingCommands.isEmpty)
    XCTAssertEqual(
      fixture.service.intentions.last?.progressFactID,
      original.last?.progressFactID
    )
  }
}

private extension PendingCookingSessionCommand {
  var progressFactID: SessionFact.ID? {
    guard case let .progress(identifier, _, _, _) = self else { return nil }
    return identifier
  }
}

private extension CookingSessionIntention {
  var progressFactID: SessionFact.ID? {
    guard case let .progress(intention, _) = self else { return nil }
    return intention.id
  }
}

@MainActor
private struct OutboxPositionFixture {
  let sessionID = CookingSession.ID()
  let ingredientID = SessionIngredient.ID()
  let instructionID = SessionInstruction.ID()
  let service: OutboxPositionService
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
    service = OutboxPositionService(session: session)
    store.currentSessionID = sessionID
    model = CookingSessionPresentationModel(sessions: service, store: store)
    model.loadIfNeeded()
  }
}

@MainActor
private final class OutboxPositionService: CookingSessionServing {
  private var session: CookingSessionProjection
  private(set) var intentions: [CookingSessionIntention] = []
  var rejectsCommands = false
  var failureAttemptNumbers = Set<Int>()

  init(session: CookingSessionProjection) {
    self.session = session
  }

  func sessions() throws -> [SessionProjectionResult] { [.session(session)] }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    _ = intention
    throw CookingSessionLogicError.invalidIntention
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    intentions.append(intention)
    if rejectsCommands || failureAttemptNumbers.contains(intentions.count) {
      throw CookingSessionLogicError.sessionWriteFailed
    }
    guard case let .progress(_, progress) = intention else {
      throw CookingSessionLogicError.invalidIntention
    }
    var values = session.progress.filter { $0.target != progress.target }
    values.append(progress)
    session = session.replacingProgress(values)
    return .accepted(session)
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
