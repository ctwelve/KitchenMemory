// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CloudKit

/// Resolves Apple's opaque current-user record identity for one CloudKit container.
public struct CloudKitKitchenOwnerIDResolver: Sendable {
  private let containerIdentifier: String

  /// Selects the CloudKit container whose opaque current-account record establishes owner scope.
  public init(containerIdentifier: String) {
    self.containerIdentifier = containerIdentifier
  }

  /// Resolves an opaque owner identity scoped to this container and current CloudKit account.
  /// Throws account or CloudKit failures rather than inventing a local owner; no person-facing
  /// name or contact information is returned.
  public func ownerID() async throws -> KitchenOwner.ID {
    let recordID = try await CKContainer(identifier: containerIdentifier).userRecordID()
    return Self.ownerID(
      containerIdentifier: containerIdentifier,
      userRecordName: recordID.recordName
    )
  }

  static func ownerID(
    containerIdentifier: String,
    userRecordName: String
  ) -> KitchenOwner.ID {
    KitchenOwner.ID(rawValue: "cloudkit:\(containerIdentifier):\(userRecordName)")
  }
}
