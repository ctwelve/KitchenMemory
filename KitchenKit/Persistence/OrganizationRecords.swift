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

  convenience init(command: FolderCommand) throws {
    try self.init(action: command.action, kitchenID: command.kitchenID, namespace: "folders")
  }

  convenience init(command: TagCommand) throws {
    try self.init(action: command.action, kitchenID: command.kitchenID, namespace: "tags")
  }

  init<Payload>(action: OrganizationAction<Payload>, kitchenID: Kitchen.ID, namespace: String) throws {
    id = action.id
    self.kitchenID = kitchenID.rawValue
    self.namespace = namespace
    authoredAt = action.authoredAt
    payloadData = try OrganizationCoding.encode(action)
    payloadDigest = try OrganizationCoding.digest(action)
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

  convenience init(checkpoint: FolderCheckpoint) throws {
    try self.init(id: checkpoint.id, kitchenID: checkpoint.kitchenID, namespace: "folders",
                  createdAt: checkpoint.createdAt, antiResurrectionUntil: checkpoint.antiResurrectionUntil,
                  evidence: checkpoint.evidence)
  }

  convenience init(checkpoint: TagCheckpoint) throws {
    try self.init(id: checkpoint.id, kitchenID: checkpoint.kitchenID, namespace: "tags",
                  createdAt: checkpoint.createdAt, antiResurrectionUntil: checkpoint.antiResurrectionUntil,
                  evidence: checkpoint.evidence)
  }

  init<Payload>(id: UUID, kitchenID: Kitchen.ID, namespace: String, createdAt: Date,
                antiResurrectionUntil: Date, evidence: OrganizationCheckpoint<Payload>) throws {
    self.id = id
    self.kitchenID = kitchenID.rawValue
    self.namespace = namespace
    self.createdAt = createdAt
    self.antiResurrectionUntil = antiResurrectionUntil
    checkpointData = try OrganizationCoding.encode(evidence)
    checkpointDigest = try OrganizationCoding.digest(evidence)
  }
}
