// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

/// Scalar-only immutable envelope shared by organization policies.
@Model final class OrganizationActionRecord {
  var id: UUID = UUID()
  var kitchenID: UUID = UUID()
  var namespace: String = ""
  var authoredAt: Date = Date(timeIntervalSince1970: 0)
  var formatVersion: Int = 1
  var payloadData: Data = Data()
  var payloadDigest: Data = Data()

  init(command: FolderCommand) throws {
    id = command.id
    kitchenID = command.kitchenID.rawValue
    namespace = "folders"
    authoredAt = command.action.authoredAt
    payloadData = try OrganizationCoding.encode(command.action)
    payloadDigest = try OrganizationCoding.digest(command.action)
  }
}

/// Reconstructive evidence and its minimum anti-resurrection retention promise.
@Model final class OrganizationCheckpointRecord {
  var id: UUID = UUID()
  var kitchenID: UUID = UUID()
  var namespace: String = ""
  var createdAt: Date = Date(timeIntervalSince1970: 0)
  var antiResurrectionUntil: Date = Date(timeIntervalSince1970: 0)
  var formatVersion: Int = 1
  var checkpointData: Data = Data()
  var checkpointDigest: Data = Data()

  init(checkpoint: FolderCheckpoint) throws {
    id = checkpoint.id
    kitchenID = checkpoint.kitchenID.rawValue
    namespace = "folders"
    createdAt = checkpoint.createdAt
    antiResurrectionUntil = checkpoint.antiResurrectionUntil
    checkpointData = try OrganizationCoding.encode(checkpoint.evidence)
    checkpointDigest = try OrganizationCoding.digest(checkpoint.evidence)
  }
}
