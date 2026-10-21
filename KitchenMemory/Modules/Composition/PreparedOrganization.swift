// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import SwiftData

@MainActor
struct PreparedOrganization {
  let model: RecipeOrganizationModel
  let history: OrganizationHistoryRegistry

  init(plan: AppLaunchPlan, ownerID: KitchenOwner.ID, preferences: any KitchenPreferencesStoring,
       kitchenID: Kitchen.ID, container: ModelContainer) throws {
    let scope = ownerID.rawValue + "." + (plan.store.personalCloudContainerIdentifier ?? "local")
    let defaults: UserDefaults
    if plan.store.isInMemory {
      guard let isolated = UserDefaults(suiteName: "organization-testing." + UUID().uuidString) else {
        throw CocoaError(.fileWriteUnknown)
      }
      defaults = isolated
    } else { defaults = .standard }
    let repository = SwiftDataRecipeOrganizationRepository(modelContainer: container)
    model = RecipeOrganizationModel(repository: repository, kitchenID: kitchenID, scope: scope,
      preferences: preferences.organizationPreferences(scope: scope, kitchenID: kitchenID), defaults: defaults)
    history = try OrganizationHistoryRegistry(repository: repository, organization: model, ownerID: ownerID,
      storeID: scope, kitchenID: kitchenID,
      directory: OrganizationHistoryRegistry.directory(ownerID: ownerID, storeID: scope,
        kitchenID: kitchenID, inMemory: plan.store.isInMemory))
  }
}
