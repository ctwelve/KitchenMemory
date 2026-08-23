// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import CoreData
import Foundation

/// Bridges managed-store notifications into application-facing refresh work.
///
/// CloudKit remains a persistence detail: this adapter observes Core Data's
/// generic remote-store notification and tells the composition root that its
/// read model is stale. Neither the domain nor product-logic frameworks need
/// to know which transport produced the change.
@MainActor
public final class PersistentStoreChangeObserver: NSObject {
  private let notificationCenter: NotificationCenter
  private let onChange: @MainActor () -> Void

  public init(
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

  // Core Data posts remote-store changes on a private queue. The Objective-C
  // selector must accept that delivery context before crossing to UI state.
  @objc nonisolated private func storeDidChange() {
    Task { @MainActor [weak self] in
      self?.onChange()
    }
  }
}
