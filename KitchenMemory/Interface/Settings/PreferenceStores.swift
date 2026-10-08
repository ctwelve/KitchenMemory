// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit

/// The onboarding capability consumed by the recipe-library state machine.
@MainActor
protocol SampleRecipeOnboardingStoring: AnyObject {
  var sampleRecipeOnboardingResponse: SampleRecipeOnboardingResponse { get set }
  func startObservingSampleRecipeOnboardingResponse(
    _ onChange: @escaping @MainActor (SampleRecipeOnboardingResponse) -> Void
  )
}

extension SampleRecipeOnboardingStoring {
  func startObservingSampleRecipeOnboardingResponse(
    _ onChange: @escaping @MainActor (SampleRecipeOnboardingResponse) -> Void
  ) {}
}

/// The device-local capability consumed while selecting the recipe store.
@MainActor
protocol CloudSyncPreferenceStoring: AnyObject {
  var personalCloudSynchronizationEnabled: Bool { get set }
}

/// The application preference boundary composed once at startup.
///
/// Consumers depend on the narrower capabilities above. This aggregate owns
/// key names, defaults, synchronization scope, and observation so future app
/// preferences do not grow another independent storage wrapper.
@MainActor
protocol KitchenPreferencesStoring:
  SampleRecipeOnboardingStoring,
  CloudSyncPreferenceStoring {
  /// Bind only after the owner/store scope and Kitchen identity are resolved.
  func organizationPreferences(scope: String, kitchenID: Kitchen.ID) -> any OrganizationPreferencesStoring
}

/// Observable local organization preferences, bound to one owner/store and Kitchen.
///
/// Feature visibility belongs to the device; expansion belongs to the bound scope.
/// Pending commands and synchronized organization policy are not preferences.
@MainActor
protocol OrganizationPreferencesStoring: AnyObject {
  var foldersEnabled: Bool { get set }
  var tagsEnabled: Bool { get set }
  var tagsExpanded: Bool { get set }
  var expanded: Set<Folder.ID> { get set }
  func resetExpansion()
}

extension OrganizationPreferencesStoring {
  /// Reset disclosure state while retaining the person's device-local feature choices.
  func resetExpansion() {
    expanded = []
    tagsExpanded = true
  }
}
