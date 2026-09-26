// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import SwiftData

/// The complete dependency graph consumed by the prepared application shell.
///
/// It retains the model container and adapters for their required lifetimes and
/// exposes the recipe-library and Cooking Session presentation models used by
/// feature views. External-store notifications re-enter the graph here so both
/// projections refresh from one ownership-reconciled boundary.
@MainActor
struct PreparedApp {
  let modelContainer: ModelContainer
  let libraryModel: RecipeLibraryModel
  let cookingSessionRepository: SwiftDataCookingSessionRepository
  let cookingSessions: CookingSessions
  let recipeRepository: SwiftDataRecipeRepository
  let ownerID: KitchenOwner.ID
  let locale: Locale
  let sessionModel: CookingSessionPresentationModel
  let persistentStoreChangeObserver: PersistentStoreChangeObserver?
  let personalCloudStatusMonitor: PersonalCloudStatusMonitor?
  let cloudSyncSettings: CloudSyncSettings?
  let recordsMaintenance: AppRecordsMaintenance

  init(
    plan: AppLaunchPlan,
    ownerID: KitchenOwner.ID,
    preferences: any KitchenPreferencesStoring,
    samples: any SampleRecipeProviding,
    locale: Locale = .current,
    initialKitchenWasCreatedOverride: Bool? = nil,
    sessionPresentationStore: any CookingSessionPresentationStoring
  ) throws {
    let core = try PreparedCore(
      plan: plan,
      ownerID: ownerID,
      preferences: preferences,
      samples: samples,
      locale: locale,
      initialKitchenWasCreatedOverride: initialKitchenWasCreatedOverride
    )
    let sessionModel = CookingSessionPresentationModel(
      sessions: core.cookingSessions,
      store: sessionPresentationStore,
      navigation: core.libraryModel.navigation
    )
    let sessionRepository = core.cookingSessionRepository
    core.libraryModel.installResetPresentationHandler {
      sessionRepository.refreshFromPersistentStore()
      sessionModel.resetAfterKitchenReset()
    }
    modelContainer = core.modelContainer
    libraryModel = core.libraryModel
    cookingSessionRepository = core.cookingSessionRepository
    cookingSessions = core.cookingSessions
    recipeRepository = core.recipeRepository
    self.ownerID = core.ownerID
    self.locale = core.locale
    self.sessionModel = sessionModel
    cloudSyncSettings = plan.offersCloudSyncSetting
      ? CloudSyncSettings(
        preference: preferences,
        isEnabledAtLaunch: plan.cloudSyncIsEnabledAtLaunch
      )
      : nil
    let recordsMaintenance = makeRecordsMaintenance(plan: plan, core: core, sessionModel: sessionModel)
    self.recordsMaintenance = recordsMaintenance
    persistentStoreChangeObserver = makePersistentStoreChangeObserver(
      plan: plan,
      core: core,
      sessionModel: sessionModel,
      afterRefresh: { recordsMaintenance.opportunity() }
    )
    let personalCloudStatusMonitor = makePersonalCloudStatusMonitor(
      plan: plan, core: core, recordsMaintenance: recordsMaintenance
    )
    self.personalCloudStatusMonitor = personalCloudStatusMonitor
    personalCloudStatusMonitor?.start()
  }

  func reloadAfterExternalStoreChange() {
    guard (try? reconcileKitchenOwnership(repository: recipeRepository, ownerID: ownerID, locale: locale)) != nil else {
      return
    }
    performExternalStoreRefresh(
      libraryModel: libraryModel,
      sessionRepository: cookingSessionRepository,
      sessionModel: sessionModel
    )
  }

  static var preview: PreparedApp {
    do {
      return try AppRuntime.testing()
    } catch {
      fatalError("Could not prepare the Kitchen Memory preview: \(error)")
    }
  }
}

@MainActor
private func makePersonalCloudStatusMonitor(
  plan: AppLaunchPlan,
  core: PreparedCore,
  recordsMaintenance: AppRecordsMaintenance
) -> PersonalCloudStatusMonitor? {
  return plan.store.personalCloudContainerIdentifier.map { containerIdentifier in
    PersonalCloudStatusMonitor(
      accountChecker: CloudKitAccountChecker(
        containerIdentifier: containerIdentifier
      ),
      relevantStoreIdentifiers: recordsMaintenance.storeIdentifiers,
      onSuccessfulTransfer: { recordsMaintenance.observedSuccessfulTransfer(at: $0) },
      onStatusChange: { core.libraryModel.updatePersonalCloudStatus($0) }
    )
  }
}
