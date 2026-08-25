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

@MainActor
protocol SampleRecipeOnboardingStoring: AnyObject {
  var response: SampleRecipeOnboardingResponse { get set }
  func startObservingChanges(
    _ onChange: @escaping @MainActor (SampleRecipeOnboardingResponse) -> Void
  )
}

extension SampleRecipeOnboardingStoring {
  func startObservingChanges(
    _ onChange: @escaping @MainActor (SampleRecipeOnboardingResponse) -> Void
  ) {}
}

/// Keeps the first-run answer outside recipe storage without turning it into
/// standing authority to restore or download sample content later.
@MainActor
final class UserDefaultsSampleRecipeOnboardingStore: SampleRecipeOnboardingStoring {
  static let key = "sampleRecipesConsent"

  private let defaultsKey: Defaults.Key<StoredSampleRecipeOnboardingResponse>
  private var observation: (any Defaults.Observation)?

  init(
    defaults: UserDefaults = .standard,
    synchronizesWithPersonalCloud: Bool = false
  ) {
    defaultsKey = Defaults.Key(
      Self.key,
      default: .undecided,
      suite: defaults,
      iCloud: synchronizesWithPersonalCloud
    )
  }

  var response: SampleRecipeOnboardingResponse {
    get { Defaults[defaultsKey].response }
    set { Defaults[defaultsKey] = StoredSampleRecipeOnboardingResponse(newValue) }
  }

  func startObservingChanges(
    _ onChange: @escaping @MainActor (SampleRecipeOnboardingResponse) -> Void
  ) {
    observation = Defaults.observe(defaultsKey, options: []) { change in
      let response = change.newValue.response
      Task { @MainActor in onChange(response) }
    }
  }
}

/// Disposable preferences exercise the same onboarding decisions as a durable
/// installation; application composition separately provides preview fixtures.
@MainActor
final class VolatileSampleRecipeOnboardingStore: SampleRecipeOnboardingStoring {
  var response: SampleRecipeOnboardingResponse

  init(response: SampleRecipeOnboardingResponse = .undecided) {
    self.response = response
  }
}

/// Lets Defaults mirror one small preference through iCloud between devices.
///
/// Recipe content remains the stronger signal that a Kitchen is established:
/// iCloud key-value delivery is eventual and must never hold the library hostage.
@MainActor
final class UbiquitousSampleRecipeOnboardingStore: NSObject,
  SampleRecipeOnboardingStoring {
  private let localStore: UserDefaultsSampleRecipeOnboardingStore
  private let notificationCenter: NotificationCenter
  private var onChange: (@MainActor (SampleRecipeOnboardingResponse) -> Void)?

  init(
    defaults: UserDefaults = .standard,
    notificationCenter: NotificationCenter = .default,
    synchronizesWithPersonalCloud: Bool = true
  ) {
    localStore = UserDefaultsSampleRecipeOnboardingStore(
      defaults: defaults,
      synchronizesWithPersonalCloud: synchronizesWithPersonalCloud
    )
    self.notificationCenter = notificationCenter
    super.init()
  }

  deinit {
    notificationCenter.removeObserver(self)
  }

  var response: SampleRecipeOnboardingResponse {
    get { localStore.response }
    set { localStore.response = newValue }
  }

  func startObservingChanges(
    _ onChange: @escaping @MainActor (SampleRecipeOnboardingResponse) -> Void
  ) {
    self.onChange = onChange
    localStore.startObservingChanges { [weak self] response in
      self?.onChange?(response)
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
    // into a different private CloudKit account. Defaults owns ordinary remote
    // changes; this product-specific account boundary remains ours.
    let wasUndecided = localStore.response == .undecided
    localStore.response = .undecided
    if wasUndecided {
      onChange?(.undecided)
    }
  }
}
