// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Positive integrity failures remain explicit, including after a transport decode.
enum FolderEvidenceValidation {
  static func validate(_ actions: [OrganizationAction<FolderChange>]) throws {
    var creations: Set<Folder.ID> = []
    for action in actions {
      try validate(action.payload)
      if case let .create(id, _, _) = action.payload, !creations.insert(id).inserted {
        throw FolderError.identityCollision(id)
      }
    }
  }
  private static func validate(_ change: FolderChange) throws {
    switch change {
    case let .create(id, name, parentID):
      try validateDistinct(id, parentID)
      try validateName(name)
    case let .rename(_, name): try validateName(name)
    case let .move(id, parentID):
      try validateDistinct(id, parentID)
    case let .reorder(id, anchor):
      try validateDistinct(id, anchor)
    case let .merge(ids, survivorID, name):
      try validateMerge(ids: ids, survivorID: survivorID, name: name)
    case let .delete(ids):
      guard !ids.isEmpty, Set(ids).count == ids.count else { throw FolderError.invalidEvidence }
    case .assign, .ordering: break
    }
  }

  private static func validateDistinct(_ id: Folder.ID, _ other: Folder.ID?) throws {
    guard id != other else { throw FolderError.invalidEvidence }
  }

  private static func validateMerge(ids: [Folder.ID], survivorID: Folder.ID, name: String) throws {
    guard ids.count >= 2, Set(ids).count == ids.count, ids.contains(survivorID) else {
      throw FolderError.invalidEvidence
    }
    try validateName(name)
  }

  private static func validateName(_ name: String) throws {
    guard try OrganizationName(name).value == name else { throw FolderError.invalidEvidence }
  }

}
