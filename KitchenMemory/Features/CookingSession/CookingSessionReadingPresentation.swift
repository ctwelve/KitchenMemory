// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit

/// Reading choices belong to one Session on this device, never to its cooking evidence.
struct CookingSessionReadingPreference: Codable, Equatable {
  let sessionID: CookingSession.ID
  var emphasizedInstructionID: SessionInstruction.ID?
  var position: CookingSessionReadingPosition?
  var keepsScreenAwake = true
}

/// Offset from a retained snapshot instruction; nil instruction means the document top.
struct CookingSessionReadingPosition: Codable, Equatable {
  var instructionID: SessionInstruction.ID?
  var offset: Double
}

/// Ephemeral consent to announce/reveal after this deliberate completion; never stored or replayed.
struct CookingSessionReadingCompletion: Equatable {
  let id = UUID()
  let sessionID: CookingSession.ID
  let completedNumber: Int
  let nextInstructionID: SessionInstruction.ID?
  let nextNumber: Int?
}

extension CookingSessionPresentationModel {
  func readingPreference(for session: CookingSessionProjection) -> CookingSessionReadingPreference {
    let steps = session.snapshot.instructionSections.flatMap(\.steps)
    if var saved = readingPreferences.first(where: { $0.sessionID == session.id }) {
      if let id = saved.emphasizedInstructionID, !steps.contains(where: { $0.id == id }) {
        saved.emphasizedInstructionID = steps.first { session.instructionProgress(for: $0.id) == .open }?.id
      }
      if let position = saved.position,
         !position.offset.isFinite || (position.instructionID != nil
           && !steps.contains(where: { $0.id == position.instructionID })) {
        saved.position = nil
      }
      return saved
    }
    return CookingSessionReadingPreference(sessionID: session.id,
      emphasizedInstructionID: steps.first { session.instructionProgress(for: $0.id) == .open }?.id)
  }

  func prepareReadingPreference(for session: CookingSessionProjection) {
    saveReadingPreference(readingPreference(for: session))
  }

  func chooseReadingInstruction(_ id: SessionInstruction.ID, in session: CookingSessionProjection) {
    guard session.snapshot.instructionSections.flatMap(\.steps).contains(where: { $0.id == id }) else { return }
    var preference = readingPreference(for: session)
    preference.emphasizedInstructionID = id
    readingCompletion = nil
    saveReadingPreference(preference)
  }

  func advanceReadingAfterCompletion(_ id: SessionInstruction.ID, in session: CookingSessionProjection) {
    let steps = session.snapshot.instructionSections.flatMap(\.steps)
    guard let index = steps.firstIndex(where: { $0.id == id }) else { return }
    let nextIndex = steps.indices.first { $0 > index && session.instructionProgress(for: steps[$0].id) == .open }
    var preference = readingPreference(for: session)
    preference.emphasizedInstructionID = nextIndex.map { steps[$0].id }
    saveReadingPreference(preference)
    readingCompletion = CookingSessionReadingCompletion(sessionID: session.id,
      completedNumber: index + 1, nextInstructionID: preference.emphasizedInstructionID,
      nextNumber: nextIndex.map { $0 + 1 })
  }

  func rememberReadingPosition(_ position: CookingSessionReadingPosition, in session: CookingSessionProjection) {
    guard position.offset.isFinite else { return }
    var preference = readingPreference(for: session)
    preference.position = position
    saveReadingPreference(preference)
  }

  func setKeepsScreenAwake(_ value: Bool, in session: CookingSessionProjection) {
    var preference = readingPreference(for: session)
    preference.keepsScreenAwake = value
    saveReadingPreference(preference)
  }

  func saveReadingPreference(_ preference: CookingSessionReadingPreference) {
    guard readingPreferences.first(where: { $0.sessionID == preference.sessionID }) != preference else { return }
    readingPreferences.removeAll { $0.sessionID == preference.sessionID }
    readingPreferences.append(preference)
    store.readingPreferences = readingPreferences
  }
}
