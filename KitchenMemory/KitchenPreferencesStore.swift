// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Defaults
import Foundation
import KitchenMemoryLogic

private enum StoredSampleRecipeOnboardingResponse: String, Defaults.Serializable {
  case undecided
  case accepted
  case declined

  init(_ response: SampleRecipeOnboardingResponse) {
    switch response {
    case .undecided: self = .undecided
    case .accepted: self = .accepted
    case .declined: self = .declined
    }
  }

  var response: SampleRecipeOnboardingResponse {
    switch self {
    case .undecided: .undecided
    case .accepted: .accepted
    case .declined: .declined
    }
  }
}

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
  CloudSyncPreferenceStoring {}

/// Stores typed application preferences while preserving each key's scope.
///
/// The onboarding answer may follow the person through iCloud key-value
/// storage. Recipe synchronization remains local to this device so one device
/// can never silently change another device's transport choice.
@MainActor
final class DefaultsKitchenPreferencesStore: NSObject, KitchenPreferencesStoring {
  static let sampleRecipeOnboardingResponseKey = "sampleRecipesConsent"
  static let personalCloudSynchronizationEnabledKey =
    "personalCloudSynchronizationEnabled"

  private let sampleRecipeOnboardingKey: Defaults.Key<StoredSampleRecipeOnboardingResponse>
  private let cloudSynchronizationKey: Defaults.Key<Bool>
  private let notificationCenter: NotificationCenter
  private var sampleRecipeObservation: (any Defaults.Observation)?
  private var onSampleRecipeChange: (@MainActor (SampleRecipeOnboardingResponse) -> Void)?

  init(
    defaults: UserDefaults = .standard,
    notificationCenter: NotificationCenter = .default,
    permitsPersonalPreferencesICloud: Bool = false
  ) {
    let cloudSynchronizationKey = Defaults.Key(
      Self.personalCloudSynchronizationEnabledKey,
      default: true,
      suite: defaults,
      iCloud: false
    )
    self.cloudSynchronizationKey = cloudSynchronizationKey
    sampleRecipeOnboardingKey = Defaults.Key(
      Self.sampleRecipeOnboardingResponseKey,
      default: .undecided,
      suite: defaults,
      iCloud: permitsPersonalPreferencesICloud && Defaults[cloudSynchronizationKey]
    )
    self.notificationCenter = notificationCenter
    super.init()
  }

  deinit {
    notificationCenter.removeObserver(self)
  }

  var sampleRecipeOnboardingResponse: SampleRecipeOnboardingResponse {
    get { Defaults[sampleRecipeOnboardingKey].response }
    set {
      Defaults[sampleRecipeOnboardingKey] = StoredSampleRecipeOnboardingResponse(newValue)
    }
  }

  var personalCloudSynchronizationEnabled: Bool {
    get { Defaults[cloudSynchronizationKey] }
    set { Defaults[cloudSynchronizationKey] = newValue }
  }

  func startObservingSampleRecipeOnboardingResponse(
    _ onChange: @escaping @MainActor (SampleRecipeOnboardingResponse) -> Void
  ) {
    onSampleRecipeChange = onChange
    sampleRecipeObservation = Defaults.observe(sampleRecipeOnboardingKey, options: []) { change in
      let response = change.newValue.response
      Task { @MainActor in onChange(response) }
    }
    notificationCenter.addObserver(
      self,
      selector: #selector(ubiquitousStoreDidChange),
      name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
      object: NSUbiquitousKeyValueStore.default
    )
  }

  @objc nonisolated private func ubiquitousStoreDidChange(_ notification: Notification) {
    let reason = (notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey]
      as? NSNumber)?.intValue
    Task { @MainActor [weak self] in
      self?.receiveExternalChange(reason: reason)
    }
  }

  func receiveExternalChange(reason: Int?) {
    guard reason == NSUbiquitousKeyValueStoreAccountChange else { return }
    // A preference from a previous Apple account must not follow the person
    // into a different private account. Defaults owns ordinary remote changes;
    // this product-specific account boundary remains ours.
    let wasUndecided = sampleRecipeOnboardingResponse == .undecided
    sampleRecipeOnboardingResponse = .undecided
    if wasUndecided {
      onSampleRecipeChange?(.undecided)
    }
  }
}

/// Disposable preferences exercise the same decisions as a durable install.
@MainActor
final class VolatileKitchenPreferencesStore: KitchenPreferencesStoring {
  var sampleRecipeOnboardingResponse: SampleRecipeOnboardingResponse
  var personalCloudSynchronizationEnabled: Bool

  init(
    sampleRecipeOnboardingResponse: SampleRecipeOnboardingResponse = .undecided,
    personalCloudSynchronizationEnabled: Bool = true
  ) {
    self.sampleRecipeOnboardingResponse = sampleRecipeOnboardingResponse
    self.personalCloudSynchronizationEnabled = personalCloudSynchronizationEnabled
  }
}
