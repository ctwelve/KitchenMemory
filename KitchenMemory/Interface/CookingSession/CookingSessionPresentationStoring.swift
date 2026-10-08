// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit

@MainActor
protocol CookingSessionPresentationStoring: AnyObject {
  var currentSessionID: CookingSession.ID? { get set }
  var pendingCommands: [PendingCookingSessionCommand] { get set }
  var entryDrafts: [CookingSessionEntryDraft] { get set }
  var sessionVisits: [CookingSessionVisit] { get set }
  var readingPreferences: [CookingSessionReadingPreference] { get set }
  func clear()
}

extension CookingSessionPresentationStoring {
  func clear() {
    currentSessionID = nil
    pendingCommands = []
    entryDrafts = []
    sessionVisits = []
    readingPreferences = []
  }
}
