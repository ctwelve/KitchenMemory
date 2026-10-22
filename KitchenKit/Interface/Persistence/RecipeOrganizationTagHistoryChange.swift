// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Version-3 Tag intent retains logical assignments, never mutable pair membership.
struct RecipeOrganizationTagHistoryChange: Codable, Equatable, Sendable {
  let tagID: Tag.ID
  let adding: Bool
  let members: [RecipeOrganizationTagHistoryMember]

  var inverse: Self { Self(tagID: tagID, adding: !adding, members: members) }
}

struct RecipeOrganizationTagHistoryMember: Codable, Equatable, Sendable {
  let anchorID: UUID
  let recipeID: Recipe.ID
  let logicalDots: [UUID]
  let baseline: Data
}

extension RecipeOrganizationHistoryChange {
  init(tagChange: RecipeOrganizationTagHistoryChange) {
    // Preparation and version-3 decoding both require a nonempty member set.
    let first = tagChange.members[0]
    self.init(anchorID: first.anchorID, recipeID: first.recipeID,
      before: nil, after: nil, baseline: Data(), folderBaseline: Data(), tagChange: tagChange)
  }
}
