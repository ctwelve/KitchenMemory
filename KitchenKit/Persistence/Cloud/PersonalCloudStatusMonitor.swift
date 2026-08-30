// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CloudKit
import CoreData
import Foundation

@MainActor
public protocol PersonalCloudAccountChecking {
  func status() async -> PersonalCloudStatus
}

@MainActor
public struct CloudKitAccountChecker: PersonalCloudAccountChecking {
  private let container: CKContainer

  public init(containerIdentifier: String) {
    container = CKContainer(identifier: containerIdentifier)
  }

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

/// Reports account and managed-import/export state without owning sync itself.
///
/// SwiftData remains the transport owner. This monitor listens to public
/// CloudKit/Core Data signals so Settings can report honest availability and
/// operation failures without introducing CloudKit into reusable frameworks.
@MainActor
public final class PersonalCloudStatusMonitor: NSObject {
  private let notificationCenter: NotificationCenter
  private let accountChecker: any PersonalCloudAccountChecking
  private let onStatusChange: @MainActor (PersonalCloudStatus) -> Void
  private var state = PersonalCloudStatusState()
  private var accountCheckGeneration = 0

  public init(
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

  public func start() {
    refreshAccountStatus()
  }

  @objc nonisolated private func accountChanged() {
    Task { @MainActor [weak self] in
      self?.refreshAccountStatus()
    }
  }

  @objc nonisolated private func cloudEventChanged(_ notification: Notification) {
    guard let event = notification.userInfo?[
      NSPersistentCloudKitContainer.eventNotificationUserInfoKey
    ] as? NSPersistentCloudKitContainer.Event else { return }
    receiveCloudEvent(
      PersonalCloudEventSnapshot(
        id: event.identifier,
        type: event.type.rawValue,
        ended: event.endDate != nil,
        succeeded: event.succeeded
      )
    )
  }

  nonisolated func receiveCloudEvent(_ event: PersonalCloudEventSnapshot) {
    Task { @MainActor [weak self] in
      self?.recordCloudEvent(event)
    }
  }

  private func recordCloudEvent(_ event: PersonalCloudEventSnapshot) {
    state.recordEvent(
      id: event.id,
      type: event.type,
      ended: event.ended,
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
