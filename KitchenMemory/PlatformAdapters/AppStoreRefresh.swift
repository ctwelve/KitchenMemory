// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit

/// Connects managed-store invalidation to the prepared graph for personal-cloud launches.
///
/// KitchenKit's observer receives Core Data remote-change notifications and
/// hops to the main actor before invoking this closure. A notification means
/// reads may be stale, not that a specific intention was accepted or that cloud
/// synchronization completed. ``PreparedApp`` retains the observer and its graph.
@MainActor
func makePersistentStoreChangeObserver(
  plan: AppLaunchPlan,
  core: PreparedCore,
  sessionModel: CookingSessionPresentationModel,
  afterRefresh: @escaping () -> Void = {}
) -> PersistentStoreChangeObserver? {
  guard plan.store.personalCloudContainerIdentifier != nil else { return nil }
  return PersistentStoreChangeObserver {
    guard (try? reconcileKitchenOwnership(
      repository: core.recipeRepository,
      ownerID: core.ownerID,
      locale: core.locale
    )) != nil else { return }
    performExternalStoreRefresh(
      libraryModel: core.libraryModel,
      sessionRepository: core.cookingSessionRepository,
      sessionModel: sessionModel
    )
    afterRefresh()
  }
}

@MainActor
func reconcileKitchenOwnership(
  repository: SwiftDataRecipeRepository,
  ownerID: KitchenOwner.ID,
  locale: Locale = .current
) throws {
  _ = try KitchenBootstrapService(repository: repository).prepareInitialKitchenWithStatus(
    named: LocalizedStringResource.kitchenDefaultName.localized(for: locale), ownerID: ownerID)
}

/// Refreshes feature read models after the caller reconciles Kitchen ownership.
///
/// Session queries use a repository-owned SwiftData context, so replace that
/// read context before retrying commands and rebuilding Session presentation.
/// Early notifications leave feature initialization to the shell's first load.
@MainActor
func performExternalStoreRefresh(
  libraryModel: RecipeLibraryModel,
  sessionRepository: SwiftDataCookingSessionRepository,
  sessionModel: CookingSessionPresentationModel
) {
  libraryModel.reloadAfterExternalStoreChange()
  sessionRepository.refreshFromPersistentStore()
  sessionModel.reloadAfterExternalStoreChange()
}
