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

@MainActor
struct AcceptanceFixture {
  let runID: UUID
  let scenario: AcceptanceScenario

  var kitchenID: Kitchen.ID { KitchenBootstrapService.personalKitchenID }

  func transactions(for actor: String) throws -> [CookingSessionTransaction] {
    switch (scenario, actor.uppercased()) {
    case (.e1, "A"):
      return [.start(try root("duplicate")), .start(try root("collision"))]
    case (.e1, "B"):
      return [
        .start(try root("duplicate")),
        .start(try root("collision", startedAtOffset: 1)),
      ]
    case (.e2b, "A"):
      let value = try root("primary")
      return [.start(value), .activity(try fact(root: value, label: "fact-a"))]
    case (.e2b, "B"):
      let value = try root("primary")
      return [.start(value), .activity(try fact(root: value, label: "fact-b"))]
    case (.e3, "A"):
      return [.start(try root("primary"))]
    case (.e4a, "A"):
      let values = try completeEvidence()
      return [.finish(values.closure), .restore([values.restoration])]
    case (.e4a, "B"):
      let values = try completeEvidence()
      return [
        .start(values.root), .activity(values.fact), .delete(values.deletion),
      ]
    case (.e4b, "A"):
      let value = try root("primary")
      return [.start(value), .activity(try fact(root: value, label: "fact-a"))]
    case (.e4b, "B"):
      let value = try root("primary")
      return [.start(value), .activity(try fact(root: value, label: "fact-b"))]
    case (.e5, "A"):
      let value = try root("primary")
      return [
        .start(value),
        .delete(deletion(root: value, sessionHeads: [value.id.rawValue])),
      ]
    case (.e5, "B"):
      let value = try root("primary")
      return [.start(value), .activity(try fact(root: value, label: "offline-fact"))]
    case (.e5, "R"):
      let value = try root("primary")
      let marker = deletion(root: value, sessionHeads: [value.id.rawValue])
      return [.restore([restoration(root: value, deletion: marker)])]
    case (.e7, "A1"):
      return [.start(try root("first"))]
    case (.e7, "A2"):
      return [.start(try root("second"))]
    default:
      throw AcceptanceHarnessError.unsupportedActor
    }
  }

  func observedSessionIDs() -> [CookingSession.ID] {
    switch scenario {
    case .e1:
      [sessionID("duplicate"), sessionID("collision")]
    case .e7:
      [sessionID("first"), sessionID("second")]
    default:
      [sessionID("primary")]
    }
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
