// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CryptoKit
import Foundation
import KitchenKit

enum AcceptanceScenario: String, CaseIterable {
  case e1 = "E1"
  case e2b = "E2b"
  case e3 = "E3"
  case e4a = "E4a"
  case e4b = "E4b"
  case e5 = "E5"
  case e7 = "E7"
}

enum AcceptanceActor: String {
  case a = "A"
  case a1 = "A1"
  case a2 = "A2"
  case b = "B"
  case restoration = "R"

  init?(argument: String) {
    self.init(rawValue: argument.uppercased())
  }
}

struct AcceptanceCheckpointPlan {
  let checkpoint: AcceptanceCheckpoint
  let actors: [AcceptanceActor]
}

struct AcceptanceScenarioPlan {
  let sessionLabels: [String]
  let checkpoints: [AcceptanceCheckpointPlan]

  func actors(at checkpoint: AcceptanceCheckpoint) throws -> [AcceptanceActor] {
    guard let plan = checkpoints.first(where: { $0.checkpoint == checkpoint }) else {
      throw AcceptanceHarnessError.invalidArguments
    }
    return plan.actors
  }
}

extension AcceptanceScenario {
  var plan: AcceptanceScenarioPlan {
    switch self {
    case .e1:
      AcceptanceScenarioPlan(
        sessionLabels: ["duplicate", "collision"],
        checkpoints: [
          AcceptanceCheckpointPlan(checkpoint: .final, actors: [.a, .b]),
        ]
      )
    case .e2b, .e4b:
      AcceptanceScenarioPlan(
        sessionLabels: ["primary"],
        checkpoints: [
          AcceptanceCheckpointPlan(checkpoint: .final, actors: [.a, .b]),
        ]
      )
    case .e3:
      AcceptanceScenarioPlan(
        sessionLabels: ["primary"],
        checkpoints: [
          AcceptanceCheckpointPlan(checkpoint: .final, actors: [.a]),
        ]
      )
    case .e4a:
      AcceptanceScenarioPlan(
        sessionLabels: ["primary"],
        checkpoints: [
          AcceptanceCheckpointPlan(checkpoint: .partial, actors: [.a]),
          AcceptanceCheckpointPlan(checkpoint: .final, actors: [.a, .b]),
        ]
      )
    case .e5:
      AcceptanceScenarioPlan(
        sessionLabels: ["primary"],
        checkpoints: [
          AcceptanceCheckpointPlan(checkpoint: .deleted, actors: [.a, .b]),
          AcceptanceCheckpointPlan(
            checkpoint: .final,
            actors: [.a, .b, .restoration]
          ),
        ]
      )
    case .e7:
      AcceptanceScenarioPlan(
        sessionLabels: ["first", "second"],
        checkpoints: [
          AcceptanceCheckpointPlan(checkpoint: .first, actors: [.a1]),
          AcceptanceCheckpointPlan(checkpoint: .final, actors: [.a1, .a2]),
        ]
      )
    }
  }
}

@MainActor
struct AcceptanceFixture {
  let runID: UUID
  let scenario: AcceptanceScenario

  var kitchenID: Kitchen.ID { KitchenBootstrapService.personalKitchenID }

  func transactions(for actor: AcceptanceActor) throws -> [CookingSessionTransaction] {
    switch (scenario, actor) {
    case (.e1, .a):
      return [.start(try root("duplicate")), .start(try root("collision"))]
    case (.e1, .b):
      return [
        .start(try root("duplicate")),
        .start(try root("collision", startedAtOffset: 1)),
      ]
    case (.e2b, .a):
      let value = try root("primary")
      return [.start(value), .activity(try fact(root: value, label: "fact-a"))]
    case (.e2b, .b):
      let value = try root("primary")
      return [.start(value), .activity(try fact(root: value, label: "fact-b"))]
    case (.e3, .a):
      return [.start(try root("primary"))]
    case (.e4a, .a):
      let values = try completeEvidence()
      return [.finish(values.closure), .restore([values.restoration])]
    case (.e4a, .b):
      let values = try completeEvidence()
      return [
        .start(values.root), .activity(values.fact), .delete(values.deletion),
      ]
    case (.e4b, .a):
      let value = try root("primary")
      return [.start(value), .activity(try fact(root: value, label: "fact-a"))]
    case (.e4b, .b):
      let value = try root("primary")
      return [.start(value), .activity(try fact(root: value, label: "fact-b"))]
    case (.e5, .a):
      let value = try root("primary")
      return [
        .start(value),
        .delete(deletion(root: value, sessionHeads: [value.id.rawValue])),
      ]
    case (.e5, .b):
      let value = try root("primary")
      return [.start(value), .activity(try fact(root: value, label: "offline-fact"))]
    case (.e5, .restoration):
      let value = try root("primary")
      let marker = deletion(root: value, sessionHeads: [value.id.rawValue])
      return [.restore([restoration(root: value, deletion: marker)])]
    case (.e7, .a1):
      return [.start(try root("first"))]
    case (.e7, .a2):
      return [.start(try root("second"))]
    default:
      throw AcceptanceHarnessError.unsupportedActor
    }
  }

  func observedSessionIDs() -> [CookingSession.ID] {
    scenario.plan.sessionLabels.map(sessionID)
  }

  func expectation(
    at checkpoint: AcceptanceCheckpoint
  ) throws -> AcceptanceExpectation {
    let repository = InMemoryCookingSessionRepository()
    for actor in try scenario.plan.actors(at: checkpoint) {
      for transaction in try transactions(for: actor) {
        try repository.append(transaction)
      }
    }
    let observations = try observedSessionIDs().compactMap {
      try AcceptanceObservation.read(sessionID: $0, repository: repository)
    }
    return AcceptanceExpectation(observations: observations)
  }

  private func completeEvidence() throws -> (
    root: CookingSessionRootEvidence,
    fact: SessionFactEvidence,
    closure: SessionClosureEvidence,
    deletion: SessionDeletionEvidence,
    restoration: SessionDeletionResolutionEvidence
  ) {
    let root = try root("primary")
    let fact = try fact(root: root, label: "fact")
    let closure = try closure(root: root, facts: [fact])
    let deletion = deletion(root: root, sessionHeads: [closure.id.rawValue])
    return (
      root, fact, closure, deletion,
      restoration(root: root, deletion: deletion)
    )
  }

  private func root(
    _ label: String,
    startedAtOffset: TimeInterval = 0
  ) throws -> CookingSessionRootEvidence {
    let snapshot = try ExecutionSnapshotCodec.encode(
      ExecutionSnapshot(title: "Synthetic Session")
    )
    return CookingSessionRootEvidence(
      id: sessionID(label),
      kitchenID: kitchenID,
      recipeID: Recipe.ID(rawValue: identifier("\(label)-recipe")),
      recipeRevisionID: RecipeRevision.ID(rawValue: identifier("\(label)-revision")),
      startedAt: Date(timeIntervalSinceReferenceDate: 800_000_000 + startedAtOffset),
      snapshotFormatVersion: snapshot.formatVersion,
      snapshotData: snapshot.data,
      snapshotDigest: snapshot.digest
    )
  }

  private func fact(
    root: CookingSessionRootEvidence,
    label: String
  ) throws -> SessionFactEvidence {
    let heads = CausalHeadsCodec.encode([root.id.rawValue])
    let payload = try SessionFactPayloadCodec.encode(.empty)
    return SessionFactEvidence(
      id: SessionFact.ID(rawValue: identifier(label)),
      sessionID: root.id,
      kitchenID: root.kitchenID,
      kind: SessionFact.Kind.stop.rawValue,
      targetSnapshotElementID: nil,
      authoredAt: Date(timeIntervalSinceReferenceDate: 800_000_060),
      causalHeadsFormatVersion: heads.formatVersion,
      causalHeadsData: heads.data,
      payloadFormatVersion: payload.formatVersion,
      payloadData: payload.data,
      payloadDigest: payload.digest
    )
  }

  private func closure(
    root: CookingSessionRootEvidence,
    facts: [SessionFactEvidence]
  ) throws -> SessionClosureEvidence {
    let evidence = SessionEvidence(sessionID: root.id, roots: [root], facts: facts)
    guard case let .session(projection) = SessionEvidenceProjector.project(evidence) else {
      throw AcceptanceHarnessError.invalidFixture
    }
    let closed = try ClosedSessionProjectionCodec.encode(
      ClosedSessionProjection(projection)
    )
    let heads = CausalHeadsCodec.encode(
      facts.isEmpty ? [root.id.rawValue] : facts.map(\.id.rawValue)
    )
    return SessionClosureEvidence(
      id: SessionClosure.ID(rawValue: identifier("closure")),
      sessionID: root.id,
      kitchenID: root.kitchenID,
      finishedAt: Date(timeIntervalSinceReferenceDate: 800_000_120),
      causalHeadsFormatVersion: heads.formatVersion,
      causalHeadsData: heads.data,
      snapshotFormatVersion: root.snapshotFormatVersion,
      snapshotDigest: root.snapshotDigest,
      projectionFormatVersion: closed.formatVersion,
      projectionDigest: closed.digest,
      outcomeFormatVersion: nil,
      outcomeData: nil
    )
  }

  private func deletion(
    root: CookingSessionRootEvidence,
    sessionHeads: [UUID]
  ) -> SessionDeletionEvidence {
    let session = CausalHeadsCodec.encode(sessionHeads)
    let disposition = CausalHeadsCodec.encode([])
    return SessionDeletionEvidence(
      id: SessionDeletion.ID(rawValue: identifier("deletion")),
      sessionID: root.id,
      kitchenID: root.kitchenID,
      deletedAt: Date(timeIntervalSinceReferenceDate: 800_000_180),
      sessionHeadsFormatVersion: session.formatVersion,
      sessionHeadsData: session.data,
      dispositionHeadsFormatVersion: disposition.formatVersion,
      dispositionHeadsData: disposition.data
    )
  }

  private func restoration(
    root: CookingSessionRootEvidence,
    deletion: SessionDeletionEvidence
  ) -> SessionDeletionResolutionEvidence {
    let heads = CausalHeadsCodec.encode([deletion.id.rawValue])
    return SessionDeletionResolutionEvidence(
      id: SessionDeletionResolution.ID(rawValue: identifier("restoration")),
      deletionID: deletion.id,
      sessionID: root.id,
      kitchenID: root.kitchenID,
      restoredAt: Date(timeIntervalSinceReferenceDate: 800_000_240),
      dispositionHeadsFormatVersion: heads.formatVersion,
      dispositionHeadsData: heads.data
    )
  }

  private func sessionID(_ label: String) -> CookingSession.ID {
    CookingSession.ID(rawValue: identifier("session-\(label)"))
  }

  private func identifier(_ label: String) -> UUID {
    let input = Data("\(runID.uuidString)|\(scenario.rawValue)|\(label)".utf8)
    var bytes = Array(SHA256.hash(data: input).prefix(16))
    bytes[6] = (bytes[6] & 0x0f) | 0x40
    bytes[8] = (bytes[8] & 0x3f) | 0x80
    return UUID(uuid: (
      bytes[0], bytes[1], bytes[2], bytes[3],
      bytes[4], bytes[5], bytes[6], bytes[7],
      bytes[8], bytes[9], bytes[10], bytes[11],
      bytes[12], bytes[13], bytes[14], bytes[15]
    ))
  }
}
