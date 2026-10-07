// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

extension DefaultsCookingSessionPresentationStore {
  static let readingPreferencesKey = "cookingSessions.readingPreferences"

  /// A separate local key leaves all existing draft/outbox formats and identities untouched.
  var readingPreferences: [CookingSessionReadingPreference] {
    get {
      guard let data = defaults.data(forKey: Self.readingPreferencesKey) else { return [] }
      return (try? PropertyListDecoder().decode([CookingSessionReadingPreference].self, from: data)) ?? []
    }
    set {
      guard !newValue.isEmpty else {
        defaults.removeObject(forKey: Self.readingPreferencesKey)
        return
      }
      guard let data = try? PropertyListEncoder().encode(newValue) else {
        preconditionFailure("Cooking Session reading preferences must remain encodable")
      }
      defaults.set(data, forKey: Self.readingPreferencesKey)
    }
  }
}
