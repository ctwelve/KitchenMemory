// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// A complete URL-to-candidate import operation.
///
/// Product logic depends on this small boundary so transport and parsing
/// failures can be tested without making a network request.
public protocol RecipeURLImporting: Sendable {
  func importRecipe(from url: URL) async throws -> RecipeImportResult
}
