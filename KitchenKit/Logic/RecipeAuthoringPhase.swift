// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CryptoKit
import Foundation

/// Local workflow meaning, independent of observation and file persistence.
public enum RecipeAuthoringPhase: Codable, Equatable, Sendable {
  case importCandidate
  case editing
  case saving(RecipeSaveCommand)

  /// Repeated acceptance never restarts editing or replaces a frozen save.
  public func acceptingImport() -> Self {
    self == .importCandidate ? .editing : self
  }
}

extension RecipeImportOption {
  /// Identity for retaining the same delivered candidate once, including provenance.
  public func retentionIdentifier() throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return SHA256.hash(data: try encoder.encode(self)).map { String(format: "%02x", $0) }.joined()
  }
}
