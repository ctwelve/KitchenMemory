// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit

@MainActor
func makePersistentStoreChangeObserver(
  plan: AppLaunchPlan,
  core: PreparedCore,
  sessionModel: CookingSessionPresentationModel
) -> PersistentStoreChangeObserver? {
  guard plan.store.personalCloudContainerIdentifier != nil else { return nil }
  return PersistentStoreChangeObserver {
    guard (try? reconcileKitchenOwnership(
      repository: core.recipeRepository,
      ownerID: core.ownerID
    )) != nil else { return }
    performExternalStoreRefresh(
      libraryModel: core.libraryModel,
      sessionRepository: core.cookingSessionRepository,
      sessionModel: sessionModel
    )
  }
}

@MainActor
func reconcileKitchenOwnership(
  repository: SwiftDataRecipeRepository,
  ownerID: KitchenOwner.ID
) throws {
  let personalKitchenID = KitchenBootstrapService.personalKitchenID
  let name = try repository.kitchen(id: personalKitchenID)?.name ?? "Home Kitchen"
  try repository.convergeKitchens(
    into: Kitchen(id: personalKitchenID, ownerID: ownerID, name: name),
    ownedBy: ownerID
  )
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
