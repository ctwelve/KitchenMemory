// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CloudKit
import CoreData
import Foundation

/// Maps one container's CloudKit account availability into plain presentation status.
@MainActor
public struct CloudKitAccountChecker: PersonalCloudAccountChecking {
  private let container: CKContainer

  /// Selects the CloudKit container whose account status will be checked.
  public init(containerIdentifier: String) {
    container = CKContainer(identifier: containerIdentifier)
  }

  /// Checks account availability and maps unknown or thrown failures to failed status.
  public func status() async -> PersonalCloudStatus {
    do {
      return Self.status(for: try await container.accountStatus())
    } catch {
      return .failed
    }
  }

  static func status(for accountStatus: CKAccountStatus) -> PersonalCloudStatus {
    switch accountStatus {
    case .available: .available
    case .noAccount: .noAccount
    case .restricted: .restricted
    case .temporarilyUnavailable: .temporarilyUnavailable
    case .couldNotDetermine: .failed
    @unknown default: .failed
    }
  }
}
