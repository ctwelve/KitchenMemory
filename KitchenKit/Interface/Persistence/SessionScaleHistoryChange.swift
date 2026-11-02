// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Version-5 history retains absolute values, never inverse scale arithmetic.
struct SessionScaleHistoryChange: Codable, Equatable, Sendable {
  let sessionID: CookingSession.ID
  let recipeID: Recipe.ID
  let before: SessionWorkingScale
  let after: SessionWorkingScale
  let baseline: Data

  var inverse: Self {
    Self(sessionID: sessionID, recipeID: recipeID, before: after, after: before, baseline: baseline)
  }
}

extension RecipeOrganizationHistoryChange {
  init(sessionScale: SessionScaleHistoryChange) {
    self.init(anchorID: sessionScale.sessionID.rawValue, recipeID: sessionScale.recipeID,
      before: nil, after: nil, baseline: Data(), folderBaseline: Data(), sessionScale: sessionScale)
  }

  var sessionID: CookingSession.ID? { sessionProgress?.sessionID ?? sessionScale?.sessionID }
  var sessionBaseline: Data? { sessionProgress?.baseline ?? sessionScale?.baseline }
}
