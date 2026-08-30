// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit

/// One presentation-accepted lifecycle intention retained until Logic confirms
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
  case finish(closureID: SessionClosure.ID, sessionID: CookingSession.ID, finishedAt: Date)

  var sessionID: CookingSession.ID {
    switch self {
    case let .start(sessionID, _, _, _),
         let .stop(_, sessionID, _),
         let .resume(_, sessionID, _),
         let .finish(_, sessionID, _):
      sessionID
    }
  }
}

@MainActor
protocol CookingSessionPresentationStoring: AnyObject {
  var currentSessionID: CookingSession.ID? { get set }
  var pendingCommand: PendingCookingSessionCommand? { get set }
}

/// Device-local presentation state. These values deliberately use ordinary
/// UserDefaults and never the personal iCloud preference transport.
@MainActor
final class DefaultsCookingSessionPresentationStore: CookingSessionPresentationStoring {
  static let currentSessionIDKey = "cookingSessions.currentSessionID"
  static let pendingCommandKey = "cookingSessions.pendingCommand"

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

  var pendingCommand: PendingCookingSessionCommand? {
    get {
      guard let data = defaults.data(forKey: Self.pendingCommandKey) else { return nil }
      return try? decoder.decode(PendingCookingSessionCommand.self, from: data)
    }
    set {
      guard let newValue else {
        defaults.removeObject(forKey: Self.pendingCommandKey)
        return
      }
      guard let data = try? encoder.encode(newValue) else {
        preconditionFailure("Pending Cooking Session commands must remain encodable")
      }
      defaults.set(data, forKey: Self.pendingCommandKey)
    }
  }
}

@MainActor
final class VolatileCookingSessionPresentationStore: CookingSessionPresentationStoring {
  var currentSessionID: CookingSession.ID?
  var pendingCommand: PendingCookingSessionCommand?
}
