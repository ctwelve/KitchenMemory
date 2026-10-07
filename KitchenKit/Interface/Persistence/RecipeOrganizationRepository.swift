// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

/// Main-actor boundary for Kitchen organization reads and atomic batch acceptance.
@MainActor
public protocol RecipeOrganizationRepository {
  /// Reads Folder and Tag domain projections for the Kitchen; invalid evidence throws.
  func load(in kitchenID: Kitchen.ID) throws -> RecipeOrganization
  /// Accepts a frozen organization batch and optional first Recipe Save in one local transaction.
  /// The batch and child receipts preserve exact retry; changed command reuse throws.
  func accept(_ command: RecipeOrganizationCommand, firstSave: RecipeSaveCommand?) throws
}
