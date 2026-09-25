// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit

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
