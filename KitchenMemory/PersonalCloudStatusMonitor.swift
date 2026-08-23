// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import CloudKit
import CoreData
import Foundation

enum PersonalCloudStatus: Equatable {
  case notConfigured
  case checking
  case available
  case syncing
  case noAccount
  case restricted
  case temporarilyUnavailable
  case failed
}

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

@MainActor
protocol PersonalCloudAccountChecking {
  func status() async -> PersonalCloudStatus
}

@MainActor
struct CloudKitAccountChecker: PersonalCloudAccountChecking {
  private let container: CKContainer

  init(containerIdentifier: String) {
    container = CKContainer(identifier: containerIdentifier)
  }

  func status() async -> PersonalCloudStatus {
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

/// Reports account and managed-import/export state without owning sync itself.
///
/// SwiftData remains the transport owner. This monitor listens to public
/// CloudKit/Core Data signals so Settings can report honest availability and
/// operation failures without introducing CloudKit into reusable frameworks.
@MainActor
final class PersonalCloudStatusMonitor: NSObject {
  private let notificationCenter: NotificationCenter
  private let accountChecker: any PersonalCloudAccountChecking
  private let onStatusChange: @MainActor (PersonalCloudStatus) -> Void
  private var state = PersonalCloudStatusState()
  private var accountCheckGeneration = 0

  init(
    notificationCenter: NotificationCenter = .default,
    accountChecker: any PersonalCloudAccountChecking,
    onStatusChange: @escaping @MainActor (PersonalCloudStatus) -> Void
  ) {
    self.notificationCenter = notificationCenter
    self.accountChecker = accountChecker
    self.onStatusChange = onStatusChange
    super.init()
    notificationCenter.addObserver(
      self,
      selector: #selector(accountChanged),
      name: .CKAccountChanged,
      object: nil
    )
    notificationCenter.addObserver(
      self,
      selector: #selector(cloudEventChanged),
      name: NSPersistentCloudKitContainer.eventChangedNotification,
      object: nil
    )
  }

  deinit {
    notificationCenter.removeObserver(self)
  }

  func start() {
    refreshAccountStatus()
  }

  @objc private func accountChanged() {
    refreshAccountStatus()
  }

  @objc private func cloudEventChanged(_ notification: Notification) {
    guard let event = notification.userInfo?[
      NSPersistentCloudKitContainer.eventNotificationUserInfoKey
    ] as? NSPersistentCloudKitContainer.Event else { return }
    state.recordEvent(
      id: event.identifier,
      type: event.type.rawValue,
      ended: event.endDate != nil,
      succeeded: event.succeeded
    )
    publishStatus()
  }

  private func refreshAccountStatus() {
    accountCheckGeneration += 1
    let generation = accountCheckGeneration
    state.accountStatus = .checking
    publishStatus()
    Task { [weak self, accountChecker] in
      let status = await accountChecker.status()
      guard self?.accountCheckGeneration == generation else { return }
      self?.state.accountStatus = status
      self?.publishStatus()
    }
  }

  private func publishStatus() {
    onStatusChange(state.status)
  }
}
