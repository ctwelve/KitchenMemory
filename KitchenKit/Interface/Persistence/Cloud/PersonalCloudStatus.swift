// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Account and managed-operation status for presentation, never proof that all evidence synchronized.
public enum PersonalCloudStatus: Equatable, Sendable {
  /// This device's selected store configuration does not participate in personal cloud sync.
  case notConfigured
  /// An account availability check is still pending.
  case checking
  /// The account is usable and no managed operation or retained failure is currently reported.
  /// This does not prove remote receipt or a complete synchronized frontier.
  case available
  /// A managed CloudKit operation has begun and has not yet reported completion.
  case syncing
  /// CloudKit reports no usable iCloud account.
  case noAccount
  /// CloudKit reports account access restricted by system policy.
  case restricted
  /// CloudKit reports temporary account unavailability.
  case temporarilyUnavailable
  /// Account checking or a managed operation failed; underlying error details remain adapter-owned.
  case failed
}
