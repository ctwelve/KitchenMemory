// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

// Cooking Session rows are immutable document evidence joined only by stable
// scalar identities. Recognizable declaration defaults satisfy managed
// CloudKit's nonoptional-field requirements; repository mapping rejects them
// rather than treating framework-created placeholders as authored evidence.

@Model final class CookingSessionRecord {
  var id: UUID = UUID.zero
  var kitchenID: UUID = UUID.zero
  var recipeID: UUID = UUID.zero
  var recipeRevisionID: UUID = UUID.zero
  var startedAt: Date = Date.distantPast
  var snapshotFormatVersion: Int = -1
  var snapshotData: Data = Data()
  var snapshotDigest: Data = Data()
  var sourceSessionID: UUID?
  var sourceClosureID: UUID?

  init(
    id: UUID, kitchenID: UUID, recipeID: UUID, recipeRevisionID: UUID,
    startedAt: Date, snapshotFormatVersion: Int, snapshotData: Data,
    snapshotDigest: Data, sourceSessionID: UUID?, sourceClosureID: UUID?
  ) {
    self.id = id
    self.kitchenID = kitchenID
    self.recipeID = recipeID
    self.recipeRevisionID = recipeRevisionID
    self.startedAt = startedAt
    self.snapshotFormatVersion = snapshotFormatVersion
    self.snapshotData = snapshotData
    self.snapshotDigest = snapshotDigest
    self.sourceSessionID = sourceSessionID
    self.sourceClosureID = sourceClosureID
  }
}

@Model final class SessionFactRecord {
  var id: UUID = UUID.zero
  var sessionID: UUID = UUID.zero
  var kitchenID: UUID = UUID.zero
  var kind: String = ""
  var targetSnapshotElementID: UUID?
  var authoredAt: Date = Date.distantPast
  var causalHeadsFormatVersion: Int = -1
  var causalHeadsData: Data = Data()
  var payloadFormatVersion: Int = -1
  var payloadData: Data = Data()
  var payloadDigest: Data = Data()

  init(
    id: UUID, sessionID: UUID, kitchenID: UUID, kind: String,
    targetSnapshotElementID: UUID?, authoredAt: Date,
    causalHeadsFormatVersion: Int, causalHeadsData: Data,
    payloadFormatVersion: Int, payloadData: Data, payloadDigest: Data
  ) {
    self.id = id
    self.sessionID = sessionID
    self.kitchenID = kitchenID
    self.kind = kind
    self.targetSnapshotElementID = targetSnapshotElementID
    self.authoredAt = authoredAt
    self.causalHeadsFormatVersion = causalHeadsFormatVersion
    self.causalHeadsData = causalHeadsData
    self.payloadFormatVersion = payloadFormatVersion
    self.payloadData = payloadData
    self.payloadDigest = payloadDigest
  }
}

@Model final class SessionClosureRecord {
  var id: UUID = UUID.zero
  var sessionID: UUID = UUID.zero
  var kitchenID: UUID = UUID.zero
  var finishedAt: Date = Date.distantPast
  var causalHeadsFormatVersion: Int = -1
  var causalHeadsData: Data = Data()
  var snapshotFormatVersion: Int = -1
  var snapshotDigest: Data = Data()
  var projectionFormatVersion: Int = -1
  var projectionDigest: Data = Data()
  var outcomeFormatVersion: Int?
  var outcomeData: Data?

  init(
    id: UUID, sessionID: UUID, kitchenID: UUID, finishedAt: Date,
    causalHeadsFormatVersion: Int, causalHeadsData: Data,
    snapshotFormatVersion: Int, snapshotDigest: Data,
    projectionFormatVersion: Int, projectionDigest: Data,
    outcomeFormatVersion: Int?, outcomeData: Data?
  ) {
    self.id = id
    self.sessionID = sessionID
    self.kitchenID = kitchenID
    self.finishedAt = finishedAt
    self.causalHeadsFormatVersion = causalHeadsFormatVersion
    self.causalHeadsData = causalHeadsData
    self.snapshotFormatVersion = snapshotFormatVersion
    self.snapshotDigest = snapshotDigest
    self.projectionFormatVersion = projectionFormatVersion
    self.projectionDigest = projectionDigest
    self.outcomeFormatVersion = outcomeFormatVersion
    self.outcomeData = outcomeData
  }
}

@Model final class SessionDeletionRecord {
  var id: UUID = UUID.zero
  var sessionID: UUID = UUID.zero
  var kitchenID: UUID = UUID.zero
  var deletedAt: Date = Date.distantPast
  var sessionHeadsFormatVersion: Int = -1
  var sessionHeadsData: Data = Data()
  var dispositionHeadsFormatVersion: Int = -1
  var dispositionHeadsData: Data = Data()

  init(
    id: UUID, sessionID: UUID, kitchenID: UUID, deletedAt: Date,
    sessionHeadsFormatVersion: Int, sessionHeadsData: Data,
    dispositionHeadsFormatVersion: Int, dispositionHeadsData: Data
  ) {
    self.id = id
    self.sessionID = sessionID
    self.kitchenID = kitchenID
    self.deletedAt = deletedAt
    self.sessionHeadsFormatVersion = sessionHeadsFormatVersion
    self.sessionHeadsData = sessionHeadsData
    self.dispositionHeadsFormatVersion = dispositionHeadsFormatVersion
    self.dispositionHeadsData = dispositionHeadsData
  }
}

@Model final class SessionDeletionResolutionRecord {
  var id: UUID = UUID.zero
  var deletionID: UUID = UUID.zero
  var sessionID: UUID = UUID.zero
  var kitchenID: UUID = UUID.zero
  var restoredAt: Date = Date.distantPast
  var dispositionHeadsFormatVersion: Int = -1
  var dispositionHeadsData: Data = Data()

  init(
    id: UUID, deletionID: UUID, sessionID: UUID, kitchenID: UUID,
    restoredAt: Date, dispositionHeadsFormatVersion: Int,
    dispositionHeadsData: Data
  ) {
    self.id = id
    self.deletionID = deletionID
    self.sessionID = sessionID
    self.kitchenID = kitchenID
    self.restoredAt = restoredAt
    self.dispositionHeadsFormatVersion = dispositionHeadsFormatVersion
    self.dispositionHeadsData = dispositionHeadsData
  }
}

private extension UUID {
  static let zero = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
}
