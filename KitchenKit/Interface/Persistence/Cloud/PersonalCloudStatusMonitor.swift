// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CloudKit
import CoreData
import Foundation

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
  private let relevantStoreIdentifiers: Set<String>
  private let onSuccessfulTransfer: @MainActor (Date) -> Void
  private var state = PersonalCloudStatusState()
  private var accountCheckGeneration = 0

  /// Registers account and managed-operation observation without beginning the initial account check.
  /// Retain the monitor and call ``start()``. Callbacks run on the main actor; successful-transfer
  /// callbacks require a named relevant store and completed successful import/export event.
  /// A transfer callback is a local observation, never proof another device received all records.
  public init(
    notificationCenter: NotificationCenter = .default,
    accountChecker: any PersonalCloudAccountChecking,
    relevantStoreIdentifiers: Set<String> = [],
    onSuccessfulTransfer: @escaping @MainActor (Date) -> Void = { _ in },
    onStatusChange: @escaping @MainActor (PersonalCloudStatus) -> Void
  ) {
    self.notificationCenter = notificationCenter
    self.accountChecker = accountChecker
    self.relevantStoreIdentifiers = relevantStoreIdentifiers
    self.onSuccessfulTransfer = onSuccessfulTransfer
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

  /// Starts an asynchronous account check and immediately publishes checking status.
  /// Later checks supersede earlier results; managed CloudKit continues owning transport.
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
        succeeded: event.succeeded,
        storeIdentifier: event.storeIdentifier,
        endDate: event.endDate
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
    if event.ended, event.succeeded, let date = event.endDate,
       let identifier = event.storeIdentifier, relevantStoreIdentifiers.contains(identifier),
       event.type == NSPersistentCloudKitContainer.EventType.import.rawValue
        || event.type == NSPersistentCloudKitContainer.EventType.export.rawValue {
      onSuccessfulTransfer(date)
    }
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
