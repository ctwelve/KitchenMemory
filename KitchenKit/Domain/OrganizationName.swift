// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Shared Folder/Tag spelling policy; punctuation and system labels are ordinary names.
struct OrganizationName {
  let value: String
  var key: String { Self.comparisonKey(value) }

  init(_ entered: String) throws {
    guard !entered.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
      throw FolderError.invalidName
    }
    let trimmed = entered.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.count <= 256 else { throw FolderError.invalidName }
    value = trimmed
  }

  static func comparisonKey(_ value: String) -> String {
    value.precomposedStringWithCanonicalMapping.folding(options: .caseInsensitive,
                                                       locale: Locale(identifier: "en_US_POSIX"))
  }
}
