// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// A complete URL-to-candidate import operation.
///
/// Product logic depends on this small boundary so transport and parsing
/// failures can be tested without making a network request.
public protocol RecipeURLImporting: Sendable {
  /// Acquires and interprets one URL into reviewable candidates.
  ///
  /// Implementations own transport and parsing failures; success does not accept a
  /// Recipe Save, select among multiple candidates, or download referenced images.
  func importRecipe(from url: URL) async throws -> RecipeImportResult
}
