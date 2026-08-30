// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit

/// Device-local, unsubmitted Session Entry text. A draft is presentation state,
/// not Cooking Session evidence, and therefore never enters the command outbox.
struct CookingSessionEntryDraft: Codable, Equatable {
  let sessionID: CookingSession.ID
  var text: String
  var target: SessionProgressTarget?

  var isMeaningful: Bool {
    !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

/// One presentation-accepted Session intention retained until Logic confirms
/// that its evidence is locally durable.
enum PendingCookingSessionCommand: Codable, Equatable {
  case start(
    sessionID: CookingSession.ID,
    recipeID: Recipe.ID,
    revisionID: RecipeRevision.ID,
    startedAt: Date
  )
  case stop(factID: SessionFact.ID, sessionID: CookingSession.ID, authoredAt: Date)
  case resume(factID: SessionFact.ID, sessionID: CookingSession.ID, authoredAt: Date)
  case progress(
    factID: SessionFact.ID,
    sessionID: CookingSession.ID,
    authoredAt: Date,
    progress: SessionProgress
  )
  case replaceWorkingScale(
    factID: SessionFact.ID,
    sessionID: CookingSession.ID,
    authoredAt: Date,
    scale: SessionWorkingScale
  )
  case submitEntry(
    factID: SessionFact.ID,
    sessionID: CookingSession.ID,
    authoredAt: Date,
    text: String,
    target: SessionProgressTarget?
  )
  case reviseEntry(
    factID: SessionFact.ID,
    sessionID: CookingSession.ID,
    authoredAt: Date,
    entryID: SessionEntry.ID,
    text: String,
    target: SessionProgressTarget?
  )
  case retargetEntry(
    factID: SessionFact.ID,
    sessionID: CookingSession.ID,
    authoredAt: Date,
    entryID: SessionEntry.ID,
    target: SessionProgressTarget?
  )
  case withdrawEntry(
    factID: SessionFact.ID,
    sessionID: CookingSession.ID,
    authoredAt: Date,
    entryID: SessionEntry.ID
  )
  case setOutcome(
    factID: SessionFact.ID,
    sessionID: CookingSession.ID,
    authoredAt: Date,
    outcome: SessionOutcome
  )
  case clearOutcome(factID: SessionFact.ID, sessionID: CookingSession.ID, authoredAt: Date)
  case finish(closureID: SessionClosure.ID, sessionID: CookingSession.ID, finishedAt: Date)
  case continueSession(
    sessionID: CookingSession.ID,
    sourceSessionID: CookingSession.ID,
    startedAt: Date
  )

  var sessionID: CookingSession.ID {
    switch self {
    case let .start(sessionID, _, _, _),
         let .stop(_, sessionID, _),
         let .resume(_, sessionID, _),
         let .progress(_, sessionID, _, _),
         let .replaceWorkingScale(_, sessionID, _, _),
         let .submitEntry(_, sessionID, _, _, _),
         let .reviseEntry(_, sessionID, _, _, _, _),
         let .retargetEntry(_, sessionID, _, _, _),
         let .withdrawEntry(_, sessionID, _, _),
         let .setOutcome(_, sessionID, _, _),
         let .clearOutcome(_, sessionID, _),
         let .finish(_, sessionID, _),
         let .continueSession(sessionID, _, _):
      sessionID
    }
  }

  func isIndependentActivity(for sessionID: CookingSession.ID) -> Bool {
    guard self.sessionID == sessionID else { return false }
    switch self {
    case .progress, .replaceWorkingScale:
      return true
    case .start, .stop, .resume, .submitEntry, .reviseEntry, .retargetEntry,
         .withdrawEntry, .setOutcome, .clearOutcome, .finish, .continueSession:
      return false
    }
  }
}

@MainActor
protocol CookingSessionPresentationStoring: AnyObject {
  var currentSessionID: CookingSession.ID? { get set }
  var pendingCommands: [PendingCookingSessionCommand] { get set }
  var entryDrafts: [CookingSessionEntryDraft] { get set }
}

/// Device-local presentation state. These values deliberately use ordinary
/// UserDefaults and never the personal iCloud preference transport.
@MainActor
final class DefaultsCookingSessionPresentationStore: CookingSessionPresentationStoring {
  static let currentSessionIDKey = "cookingSessions.currentSessionID"
  static let pendingCommandKey = "cookingSessions.pendingCommand"
  static let entryDraftsKey = "cookingSessions.entryDrafts"

  private let defaults: UserDefaults
  private let encoder = PropertyListEncoder()
  private let decoder = PropertyListDecoder()

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  var currentSessionID: CookingSession.ID? {
    get {
      guard let value = defaults.string(forKey: Self.currentSessionIDKey),
            let identifier = UUID(uuidString: value) else { return nil }
      return CookingSession.ID(rawValue: identifier)
    }
    set {
      defaults.set(newValue?.rawValue.uuidString, forKey: Self.currentSessionIDKey)
    }
  }

  var pendingCommands: [PendingCookingSessionCommand] {
    get {
      guard let data = defaults.data(forKey: Self.pendingCommandKey) else { return [] }
      if let commands = try? decoder.decode([PendingCookingSessionCommand].self, from: data) {
        return commands
      }
      // Slice 14 stored one enum value at this key. Decode it as a one-item
      // outbox so an accepted intention is not lost during the Slice 15 upgrade.
      return (try? decoder.decode(PendingCookingSessionCommand.self, from: data)).map {
        [$0]
      } ?? []
    }
    set {
      guard !newValue.isEmpty else {
        defaults.removeObject(forKey: Self.pendingCommandKey)
        return
      }
      guard let data = try? encoder.encode(newValue) else {
        preconditionFailure("Pending Cooking Session commands must remain encodable")
      }
      defaults.set(data, forKey: Self.pendingCommandKey)
    }
  }

  var entryDrafts: [CookingSessionEntryDraft] {
    get {
      guard let data = defaults.data(forKey: Self.entryDraftsKey) else { return [] }
      return (try? decoder.decode([CookingSessionEntryDraft].self, from: data)) ?? []
    }
    set {
      guard !newValue.isEmpty else {
        defaults.removeObject(forKey: Self.entryDraftsKey)
        return
      }
      guard let data = try? encoder.encode(newValue) else {
        preconditionFailure("Cooking Session Entry drafts must remain encodable")
      }
      defaults.set(data, forKey: Self.entryDraftsKey)
    }
  }
}

@MainActor
final class VolatileCookingSessionPresentationStore: CookingSessionPresentationStoring {
  var currentSessionID: CookingSession.ID?
  var pendingCommands: [PendingCookingSessionCommand] = []
  var entryDrafts: [CookingSessionEntryDraft] = []
}
