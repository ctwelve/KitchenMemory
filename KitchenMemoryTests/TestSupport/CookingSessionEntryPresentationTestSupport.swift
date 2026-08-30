// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import KitchenKit

enum AmbiguousEntryError: Error {
  case interrupted
  case unexpectedCommand
}

@MainActor
final class AmbiguousEntryService: CookingSessionServing {
  let active: CookingSessionProjection
  var attempts: [PendingCookingSessionCommand] = []

  init(active: CookingSessionProjection) {
    self.active = active
  }

  func sessions() -> [SessionProjectionResult] { [.session(active)] }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    throw AmbiguousEntryError.unexpectedCommand
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    guard case let .submitEntry(fact, text, target) = intention else {
      throw AmbiguousEntryError.unexpectedCommand
    }
    let pending = PendingCookingSessionCommand.submitEntry(
      factID: fact.id,
      sessionID: fact.sessionID,
      authoredAt: fact.authoredAt,
      text: text,
      target: target
    )
    attempts.append(pending)
    guard attempts.count > 1 else { throw AmbiguousEntryError.interrupted }
    return .accepted(CookingSessionProjection(
      id: active.id,
      snapshot: active.snapshot,
      entries: [
        SessionEntry(
          id: .init(rawValue: fact.id.rawValue),
          target: target,
          text: text
        ),
      ]
    ))
  }
}

@MainActor
final class ContinuationAcceptanceService: CookingSessionServing {
  let source: CookingSessionProjection

  init(sourceID: CookingSession.ID) {
    source = CookingSessionProjection(
      id: sourceID,
      snapshot: ExecutionSnapshot(title: "Soup"),
      lifecycle: .finished
    )
  }

  func sessions() -> [SessionProjectionResult] { [.session(source)] }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    throw AmbiguousEntryError.unexpectedCommand
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    guard case let .continueSession(value) = intention else {
      throw AmbiguousEntryError.unexpectedCommand
    }
    return .accepted(CookingSessionProjection(
      id: value.sessionID,
      snapshot: ExecutionSnapshot(title: "Soup")
    ))
  }
}

@MainActor
final class RemoteFinishDuringSubmitService: CookingSessionServing {
  let sessionID: CookingSession.ID
  var isRemotelyFinished = false

  init(sessionID: CookingSession.ID) {
    self.sessionID = sessionID
  }

  func sessions() -> [SessionProjectionResult] {
    [
      .session(CookingSessionProjection(
        id: sessionID,
        snapshot: ExecutionSnapshot(title: "Soup"),
        lifecycle: isRemotelyFinished ? .finished : .active
      )),
    ]
  }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    throw AmbiguousEntryError.unexpectedCommand
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    switch intention {
    case .submitEntry:
      if isRemotelyFinished {
        return .attention(.commandNotAllowed(lifecycle: .finished))
      }
      throw AmbiguousEntryError.interrupted
    case let .continueSession(value):
      return .accepted(CookingSessionProjection(
        id: value.sessionID,
        snapshot: ExecutionSnapshot(title: "Soup")
      ))
    default:
      throw AmbiguousEntryError.unexpectedCommand
    }
  }
}

@MainActor
final class ConflictResolutionService: CookingSessionServing {
  var session: CookingSessionProjection
  private(set) var intentions: [CookingSessionIntention] = []

  init(session: CookingSessionProjection) {
    self.session = session
  }

  func sessions() -> [SessionProjectionResult] { [.session(session)] }

  func start(_ intention: StartCookingSessionIntention) throws -> CookingSessionCommandResult {
    throw AmbiguousEntryError.unexpectedCommand
  }

  func perform(_ intention: CookingSessionIntention) throws -> CookingSessionCommandResult {
    intentions.append(intention)
    return .accepted(CookingSessionProjection(id: session.id, snapshot: session.snapshot))
  }
}

@MainActor
final class RecordingEntryStore: CookingSessionPresentationStoring {
  enum Event: Equatable {
    case pending(Int)
    case draftSession(CookingSession.ID?)
  }

  var currentSessionID: CookingSession.ID?
  var pendingCommands: [PendingCookingSessionCommand] = [] {
    didSet { events.append(.pending(pendingCommands.count)) }
  }
  var entryDrafts: [CookingSessionEntryDraft] = [] {
    didSet { events.append(.draftSession(entryDrafts.first?.sessionID)) }
  }
  var events: [Event] = []
}

struct ConflictedEntryFixture {
  let sessionID = CookingSession.ID()
  let entryID = SessionEntry.ID()
  let ingredientID = SessionIngredient.ID()
  let instructionID = SessionInstruction.ID()
  let snapshot: ExecutionSnapshot
  let projection: CookingSessionProjection

  init() {
    snapshot = conflictedEntrySnapshot(
      ingredientID: ingredientID,
      instructionID: instructionID
    )
    projection = conflictedEntryProjection(
      sessionID: sessionID,
      entryID: entryID,
      ingredientID: ingredientID,
      instructionID: instructionID,
      snapshot: snapshot
    )
  }
}

private func conflictedEntrySnapshot(
  ingredientID: SessionIngredient.ID,
  instructionID: SessionInstruction.ID
) -> ExecutionSnapshot {
  ExecutionSnapshot(
    title: "Soup",
    ingredientSections: [
      SessionIngredientSection(
        title: nil,
        ingredients: [
          SessionIngredient(
            id: ingredientID,
            sourceIngredientID: RecipeIngredient.ID(),
            value: RecipeIngredient(originalText: "1 lime")
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
}

private func conflictedEntryProjection(
  sessionID: CookingSession.ID,
  entryID: SessionEntry.ID,
  ingredientID: SessionIngredient.ID,
  instructionID: SessionInstruction.ID,
  snapshot: ExecutionSnapshot
) -> CookingSessionProjection {
  CookingSessionProjection(
    id: sessionID,
    snapshot: snapshot,
    conflicts: [
      .entry(
        entryID: entryID,
        factIDs: [SessionFact.ID(), SessionFact.ID()],
        values: [
          .present(SessionEntry(
            id: entryID,
            target: .ingredient(ingredientID),
            text: "More lime"
          )),
          .present(SessionEntry(
            id: entryID,
            target: .instruction(instructionID),
            text: "More lime"
          )),
        ]
      ),
      .outcome(
        factIDs: [SessionFact.ID(), SessionFact.ID()],
        values: [.value(.coarse(.great)), .cleared]
      ),
    ]
  )
}
