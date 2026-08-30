// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import Foundation
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
    case .submitEntry, .progress:
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

func concurrentSessionFact(
  id: SessionFact.ID = SessionFact.ID(),
  sessionID: CookingSession.ID,
  kitchenID: Kitchen.ID,
  head: SessionFact.ID,
  kind: SessionFact.Kind,
  target: SessionProgressTarget? = nil,
  payload: SessionFactPayload
) throws -> SessionFactEvidence {
  let encodedHeads = CausalHeadsCodec.encode([head.rawValue])
  let encodedPayload = try SessionFactPayloadCodec.encode(payload)
  return SessionFactEvidence(
    id: id,
    sessionID: sessionID,
    kitchenID: kitchenID,
    kind: kind.rawValue,
    targetSnapshotElementID: target.map(targetIdentifier),
    authoredAt: Date(),
    causalHeadsFormatVersion: encodedHeads.formatVersion,
    causalHeadsData: encodedHeads.data,
    payloadFormatVersion: encodedPayload.formatVersion,
    payloadData: encodedPayload.data,
    payloadDigest: encodedPayload.digest
  )
}

func decodedPayload(
  in evidence: SessionEvidence,
  factID: SessionFact.ID
) throws -> SessionFactPayload? {
  guard let fact = evidence.facts.first(where: { $0.id == factID }) else { return nil }
  return try SessionFactPayloadCodec.decode(
    formatVersion: fact.payloadFormatVersion,
    data: fact.payloadData
  )
}

private func targetIdentifier(_ target: SessionProgressTarget) -> UUID {
  switch target {
  case let .ingredient(id): id.rawValue
  case let .instruction(id): id.rawValue
  }
}
