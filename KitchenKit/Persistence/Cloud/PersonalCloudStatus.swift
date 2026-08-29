// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

public enum PersonalCloudStatus: Equatable, Sendable {
  case notConfigured
  case checking
  case available
  case syncing
  case noAccount
  case restricted
  case temporarilyUnavailable
  case failed
}

/// Reduces account and CloudKit-event inputs to the status shown by the app.
///
/// Keeping this value state separate from the Apple notification adapter makes
/// the actual status rules deterministic and exhaustively testable.
struct PersonalCloudStatusState {
  var accountStatus: PersonalCloudStatus = .checking
  private var activeEventIDs = Set<UUID>()
  private var failedEventTypes = Set<Int>()

  init(accountStatus: PersonalCloudStatus = .checking) {
    self.accountStatus = accountStatus
  }

  var status: PersonalCloudStatus {
    guard accountStatus == .available else { return accountStatus }
    if !activeEventIDs.isEmpty { return .syncing }
    return failedEventTypes.isEmpty ? .available : .failed
  }

  mutating func recordEvent(
    id: UUID,
    type: Int,
    ended: Bool,
    succeeded: Bool
  ) {
    if ended {
      activeEventIDs.remove(id)
      if succeeded {
        failedEventTypes.remove(type)
      } else {
        failedEventTypes.insert(type)
      }
    } else {
      activeEventIDs.insert(id)
    }
  }
}

/// A concurrency-safe copy of the CloudKit event fields used by the UI.
///
/// Core Data owns the original event object and posts it on a private queue.
/// Copying only value-typed fields lets the notification callback cross to the
/// main actor without transferring Core Data or Foundation objects between
/// concurrency domains.
struct PersonalCloudEventSnapshot: Sendable {
  let id: UUID
  let type: Int
  let ended: Bool
  let succeeded: Bool
}
