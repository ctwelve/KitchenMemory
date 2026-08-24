// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryLogic

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
  // Preserve the released development key while giving its Swift API the more
  // precise onboarding name.
  static let key = "sampleRecipes.consent"

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  var response: SampleRecipeOnboardingResponse {
    get {
      guard let rawValue = defaults.string(forKey: Self.key) else { return .undecided }
      return SampleRecipeOnboardingResponse(rawValue: rawValue) ?? .undecided
    }
    set {
      defaults.set(newValue.rawValue, forKey: Self.key)
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

@MainActor
protocol UbiquitousKeyValueStoring: AnyObject {
  var notificationObject: AnyObject { get }
  func onboardingString(forKey key: String) -> String?
  func setOnboardingString(_ value: String, forKey key: String)
  @discardableResult func synchronizeOnboardingStore() -> Bool
}

extension NSUbiquitousKeyValueStore: UbiquitousKeyValueStoring {
  var notificationObject: AnyObject { self }

  func onboardingString(forKey key: String) -> String? {
    string(forKey: key)
  }

  func setOnboardingString(_ value: String, forKey key: String) {
    set(value, forKey: key)
  }

  func synchronizeOnboardingStore() -> Bool {
    synchronize()
  }
}

/// Mirrors one small preference locally while iCloud carries it between devices.
///
/// Recipe content remains the stronger signal that a Kitchen is established:
/// iCloud key-value delivery is eventual and must never hold the library hostage.
@MainActor
final class UbiquitousSampleRecipeOnboardingStore: NSObject,
  SampleRecipeOnboardingStoring {
  private let localStore: UserDefaultsSampleRecipeOnboardingStore
  private let ubiquitousStore: any UbiquitousKeyValueStoring
  private let notificationCenter: NotificationCenter
  private var onChange: (@MainActor (SampleRecipeOnboardingResponse) -> Void)?

  init(
    defaults: UserDefaults = .standard,
    ubiquitousStore: any UbiquitousKeyValueStoring = NSUbiquitousKeyValueStore.default,
    notificationCenter: NotificationCenter = .default
  ) {
    localStore = UserDefaultsSampleRecipeOnboardingStore(defaults: defaults)
    self.ubiquitousStore = ubiquitousStore
    self.notificationCenter = notificationCenter
    super.init()
  }

  deinit {
    notificationCenter.removeObserver(self)
  }

  var response: SampleRecipeOnboardingResponse {
    get {
      guard let remoteResponse else { return localStore.response }
      localStore.response = remoteResponse
      return remoteResponse
    }
    set {
      localStore.response = newValue
      ubiquitousStore.setOnboardingString(newValue.rawValue, forKey: Self.key)
    }
  }

  func startObservingChanges(
    _ onChange: @escaping @MainActor (SampleRecipeOnboardingResponse) -> Void
  ) {
    self.onChange = onChange
    notificationCenter.addObserver(
      self,
      selector: #selector(ubiquitousStoreDidChange),
      name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
      object: ubiquitousStore.notificationObject
    )
    let synchronized = ubiquitousStore.synchronizeOnboardingStore()
    migrateLocalResponseIfNeeded(afterSuccessfulSynchronization: synchronized)
  }

  private static let key = UserDefaultsSampleRecipeOnboardingStore.key

  private var remoteResponse: SampleRecipeOnboardingResponse? {
    guard let rawValue = ubiquitousStore.onboardingString(forKey: Self.key) else {
      return nil
    }
    return SampleRecipeOnboardingResponse(rawValue: rawValue)
  }

  private func migrateLocalResponseIfNeeded(afterSuccessfulSynchronization: Bool) {
    guard afterSuccessfulSynchronization,
          remoteResponse == nil,
          localStore.response != .undecided else { return }
    ubiquitousStore.setOnboardingString(localStore.response.rawValue, forKey: Self.key)
  }

  @objc nonisolated private func ubiquitousStoreDidChange(_ notification: Notification) {
    let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey]
      as? [String]
    let reason = (notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey]
      as? NSNumber)?.intValue
    Task { @MainActor [weak self] in
      self?.receiveExternalChange(changedKeys: changedKeys, reason: reason)
    }
  }

  func receiveExternalChange(changedKeys: [String]?, reason: Int?) {
    let accountChanged = reason == NSUbiquitousKeyValueStoreAccountChange
    guard accountChanged || changedKeys?.contains(Self.key) != false else { return }

    if let remoteResponse {
      localStore.response = remoteResponse
      onChange?(remoteResponse)
    } else if accountChanged {
      // A preference from a previous Apple account must not follow the person
      // into a different private CloudKit account.
      localStore.response = .undecided
      onChange?(.undecided)
    }
  }
}
