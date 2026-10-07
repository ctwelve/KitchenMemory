// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

struct TagName {
  let value: String
  init(_ entered: String) throws {
    value = try tagBoundary {
      guard !entered.unicodeScalars.contains(where: {
        CharacterSet.controlCharacters.contains($0) || CharacterSet.newlines.contains($0)
      }) else { throw TagError.invalidName }
      let checked = entered.trimmingCharacters(in: .whitespacesAndNewlines)
      let unprefixed = String(checked.drop(while: { $0 == "#" }))
      return try OrganizationName(unprefixed).value
    }
  }
}
