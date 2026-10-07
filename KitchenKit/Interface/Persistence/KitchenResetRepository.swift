// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

/// One atomic persistence boundary for returning a Kitchen to bundled samples.
@MainActor
public protocol KitchenResetRepository: AnyObject {
  /// Atomically replaces this Kitchen's durable contents with explicitly supplied Recipes.
  /// Callers own separate device-local draft and delivery cleanup before invoking reset.
  func reset(kitchenID: Kitchen.ID, to recipes: [StoredRecipe]) throws
}
