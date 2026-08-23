// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import CoreData
import Foundation

/// Bridges persistence notifications into application-facing refresh work.
///
/// CloudKit remains a persistence detail: this adapter observes Core Data's
/// generic remote-store notification and tells the composition root that its
/// read model is stale. Neither the domain nor product-logic frameworks need
/// to know which transport produced the change.
@MainActor
final class PersistentStoreChangeObserver: NSObject {
  private let notificationCenter: NotificationCenter
  private let onChange: @MainActor () -> Void

  init(
    notificationCenter: NotificationCenter = .default,
    onChange: @escaping @MainActor () -> Void
  ) {
    self.notificationCenter = notificationCenter
    self.onChange = onChange
    super.init()
    notificationCenter.addObserver(
      self,
      selector: #selector(storeDidChange),
      name: .NSPersistentStoreRemoteChange,
      object: nil
    )
  }

  deinit {
    notificationCenter.removeObserver(self)
  }

  @objc private func storeDidChange() {
    onChange()
  }
}
