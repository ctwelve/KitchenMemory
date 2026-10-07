// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

/// Main-actor boundary for reversible sample-pack intent and locally atomic acceptance.
@MainActor
public protocol SamplePackRepository {
  /// Derives accepted enablement intent and content counts from supplied stable sample identities.
  /// Throws for invalid samples or unreadable organization/Recipe evidence.
  func status(in kitchenID: Kitchen.ID, samples: [StoredRecipe]) throws -> SamplePackStatus
  /// Accepts a frozen pack transition with Recipe and organization evidence in one local transaction.
  /// Retries use the same command; removal must be revalidated against current maintained content.
  func accept(_ command: SamplePackCommand) throws
}
