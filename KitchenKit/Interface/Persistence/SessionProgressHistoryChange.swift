// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Version-4 history meaning. Original Facts remain authoritative and immutable.
struct SessionProgressHistoryChange: Codable, Equatable, Sendable {
  let sessionID: CookingSession.ID
  let recipeID: Recipe.ID
  let before: SessionProgress
  let after: SessionProgress
  let baseline: Data

  var inverse: Self {
    Self(sessionID: sessionID, recipeID: recipeID, before: after, after: before, baseline: baseline)
  }
}

/// The exact identity, time and causal frontier frozen before acceptance.
struct SessionProgressHistoryFact: Codable, Equatable, Sendable {
  let id: SessionFact.ID
  let authoredAt: Date
  let heads: Data
}

extension RecipeOrganizationHistoryChange {
  init(sessionProgress: SessionProgressHistoryChange) {
    self.init(anchorID: sessionProgress.sessionID.rawValue, recipeID: sessionProgress.recipeID,
      before: nil, after: nil, baseline: Data(), folderBaseline: Data(), sessionProgress: sessionProgress)
  }
}
