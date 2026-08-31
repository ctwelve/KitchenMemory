// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CoreData
import Foundation

private struct AcceptanceCloudEvent: Sendable {
  let id: UUID
  let type: Int
  let ended: Bool
  let succeeded: Bool
}

@MainActor
final class CloudEventRecorder: NSObject {
  private let notificationCenter: NotificationCenter
  private(set) var completedEventCount = 0
  private(set) var remoteChangeCount = 0

  init(notificationCenter: NotificationCenter = .default) {
    self.notificationCenter = notificationCenter
    super.init()
    notificationCenter.addObserver(
      self,
      selector: #selector(cloudEventChanged),
      name: NSPersistentCloudKitContainer.eventChangedNotification,
      object: nil
    )
    notificationCenter.addObserver(
      self,
      selector: #selector(remoteStoreChanged),
      name: .NSPersistentStoreRemoteChange,
      object: nil
    )
  }

  deinit {
    notificationCenter.removeObserver(self)
  }

  @objc nonisolated private func cloudEventChanged(_ notification: Notification) {
    guard let event = notification.userInfo?[
      NSPersistentCloudKitContainer.eventNotificationUserInfoKey
    ] as? NSPersistentCloudKitContainer.Event else { return }
    receive(AcceptanceCloudEvent(
      id: event.identifier,
      type: event.type.rawValue,
      ended: event.endDate != nil,
      succeeded: event.succeeded
    ))
  }

  @objc nonisolated private func remoteStoreChanged() {
    Task { @MainActor [weak self] in
      guard let self else { return }
      remoteChangeCount += 1
      AcceptanceOutput.emit([
        "event": "remote-change",
        "count": remoteChangeCount,
        "claim": "refresh-request-only",
      ])
    }
  }

  nonisolated private func receive(_ event: AcceptanceCloudEvent) {
    Task { @MainActor [weak self] in
      guard let self else { return }
      if event.ended { completedEventCount += 1 }
      AcceptanceOutput.emit([
        "event": "cloud-operation",
        "id": event.id.uuidString,
        "type": event.type,
        "ended": event.ended,
        "succeeded": event.succeeded,
        "claim": "operation-only",
      ])
    }
  }
}
