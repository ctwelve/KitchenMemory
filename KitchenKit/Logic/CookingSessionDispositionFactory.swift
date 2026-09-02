// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Algorithms
import Foundation

struct CookingSessionDispositionFactory {
  private let commands: CookingSessionCommandFactory

  init(commands: CookingSessionCommandFactory) {
    self.commands = commands
  }

  func deletion(
    intention: DeleteCookingSessionIntention,
    kitchenID: Kitchen.ID,
    evidence: SessionEvidence
  ) throws -> SessionDeletionEvidence {
    let sessionHeads = CausalHeadsCodec.encode(try commands.maximalSessionHeads(evidence))
    let dispositionHeads = CausalHeadsCodec.encode(try maximalDispositionHeads(evidence))
    return SessionDeletionEvidence(
      id: intention.deletionID,
      sessionID: intention.sessionID,
      kitchenID: kitchenID,
      deletedAt: intention.deletedAt,
      sessionHeadsFormatVersion: sessionHeads.formatVersion,
      sessionHeadsData: sessionHeads.data,
      dispositionHeadsFormatVersion: dispositionHeads.formatVersion,
      dispositionHeadsData: dispositionHeads.data
    )
  }

  func restorations(
    intention: RestoreCookingSessionIntention,
    kitchenID: Kitchen.ID,
    deletions: [SessionDeletionEvidence],
    evidence: SessionEvidence
  ) throws -> [SessionDeletionResolutionEvidence] {
    let heads = CausalHeadsCodec.encode(try maximalDispositionHeads(evidence))
    return deletions.map { deletion in
      SessionDeletionResolutionEvidence(
        id: resolutionID(commandID: intention.id, deletionID: deletion.id),
        deletionID: deletion.id,
        sessionID: intention.sessionID,
        kitchenID: kitchenID,
        restoredAt: intention.restoredAt,
        dispositionHeadsFormatVersion: heads.formatVersion,
        dispositionHeadsData: heads.data
      )
    }
  }

  func resolutionID(
    commandID: RestoreCookingSessionIntention.ID,
    deletionID: SessionDeletion.ID
  ) -> SessionDeletionResolution.ID {
    .init(rawValue: derivedID(
      namespace: commandID.rawValue,
      kind: "restore",
      source: deletionID.rawValue
    ))
  }

  private func maximalDispositionHeads(_ evidence: SessionEvidence) throws -> [UUID] {
    let deletions = evidence.deletions.uniqued(on: \.id)
    let restorations = evidence.restorations.uniqued(on: \.id)
    var parents: [UUID: [UUID]] = [:]
    for deletion in deletions {
      parents[deletion.id.rawValue] = try decode(
        version: deletion.dispositionHeadsFormatVersion,
        data: deletion.dispositionHeadsData
      )
    }
    for restoration in restorations {
      parents[restoration.id.rawValue] = try decode(
        version: restoration.dispositionHeadsFormatVersion,
        data: restoration.dispositionHeadsData
      )
    }
    return DirectedGraph(parentsByNode: parents).maximalNodes.sorted {
      $0.uuidString < $1.uuidString
    }
  }

  private func decode(version: Int, data: Data) throws -> [UUID] {
    try CausalHeadsCodec.decode(formatVersion: version, data: data)
  }

}
