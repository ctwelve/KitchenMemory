// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

#if TESTING
import Foundation
import KitchenKit

extension PreparedApp {
  /// Only invoked by the explicit UI-test flag after selecting disposable storage.
  /// Two valid, conflicting roots exercise real Recovery classification and routing.
  func installRecoveryNavigationFixture() throws {
    libraryModel.loadIfNeeded()
    guard let recipe = libraryModel.recipes.first else { return }
    let id = CookingSession.ID()
    _ = try cookingSessions.start(StartCookingSessionIntention(
      sessionID: id, recipeID: recipe.id, recipeRevisionID: recipe.revision.id,
      startedAt: Date(timeIntervalSince1970: 1_800_000_000)
    ))
    guard let root = try cookingSessionRepository.evidence(id: id)?.roots.first else { return }
    try cookingSessionRepository.append(.start(CookingSessionRootEvidence(
      id: root.id, kitchenID: root.kitchenID, recipeID: root.recipeID,
      recipeRevisionID: root.recipeRevisionID, startedAt: root.startedAt.addingTimeInterval(1),
      snapshotFormatVersion: root.snapshotFormatVersion,
      snapshotData: root.snapshotData, snapshotDigest: root.snapshotDigest
    )))
  }
}
#endif
