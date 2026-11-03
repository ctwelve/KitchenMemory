// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Version-6 history preserves both optional assessments, including absence.
struct SessionOutcomeHistoryChange: Codable, Equatable, Sendable {
  let sessionID: CookingSession.ID
  let recipeID: Recipe.ID
  let before: SessionOutcome?
  let after: SessionOutcome?
  let baseline: Data

  var inverse: Self {
    Self(sessionID: sessionID, recipeID: recipeID, before: after, after: before, baseline: baseline)
  }
}

extension RecipeOrganizationHistoryChange {
  init(sessionOutcome: SessionOutcomeHistoryChange) {
    self.init(anchorID: sessionOutcome.sessionID.rawValue, recipeID: sessionOutcome.recipeID,
      before: nil, after: nil, baseline: Data(), folderBaseline: Data(), sessionOutcome: sessionOutcome)
  }
}
