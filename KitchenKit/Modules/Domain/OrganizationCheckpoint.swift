// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CryptoKit
import Foundation

/// Policy identifies independently replaceable registers; structural payloads use nil.
protocol OrganizationPayload: Codable, Equatable, Sendable {
  var compactableRegister: String? { get }
}

/// Retains identity and causality after a dominated value's raw payload is removed.
struct OrganizationReceipt: Codable, Equatable, Sendable {
  let id: UUID
  let authoredAt: Date
  let observed: [UUID]
  let digest: Data
  let register: String?
}

struct OrganizationCheckpoint<Payload: OrganizationPayload>: Codable, Equatable, Sendable {
  let receipts: [OrganizationReceipt]
  let retained: [OrganizationAction<Payload>]
}

enum OrganizationCoding {
  static func encode<Value: Encodable>(_ value: Value) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(value)
  }

  static func digest<Value: Encodable>(_ value: Value) throws -> Data {
    Data(SHA256.hash(data: try encode(value)))
  }
}

extension OrganizationAction {
  func receipt() throws -> OrganizationReceipt {
    OrganizationReceipt(id: id, authoredAt: authoredAt, observed: observed,
                        digest: try OrganizationCoding.digest(self), register: payload.compactableRegister)
  }
}

extension OrganizationCheckpoint {
  func validate() throws {
    var byID: [UUID: OrganizationReceipt] = [:]
    for receipt in receipts {
      if let prior = byID[receipt.id], prior != receipt { throw FolderError.actionCollision(receipt.id) }
      byID[receipt.id] = receipt
    }
    let graph = CausalGraph(parentsByNode: byID.mapValues(\.observed), orderedBy: { $0.uuidString < $1.uuidString })
    guard !graph.containsCycle else { throw FolderError.causalCycle }
    guard receipts.allSatisfy({ $0.observed.allSatisfy { byID[$0] != nil } }) else {
      throw FolderError.invalidEvidence
    }
    for action in retained {
      guard try byID[action.id] == action.receipt() else { throw FolderError.invalidEvidence }
    }
    let retainedIDs = Set(retained.map(\.id))
    for receipt in receipts where !retainedIDs.contains(receipt.id) {
      guard let register = receipt.register,
            retained.contains(where: {
              $0.payload.compactableRegister == register && graph.isAncestor(receipt.id, of: $0.id)
            }) else { throw FolderError.invalidEvidence }
    }
  }
}
