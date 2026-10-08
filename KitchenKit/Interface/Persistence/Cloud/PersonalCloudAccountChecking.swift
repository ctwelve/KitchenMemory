// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

/// Main-actor account-availability seam for cloud-status presentation and deterministic test adapters.
@MainActor
public protocol PersonalCloudAccountChecking {
  /// Checks current account availability without proving managed record delivery.
  func status() async -> PersonalCloudStatus
}
