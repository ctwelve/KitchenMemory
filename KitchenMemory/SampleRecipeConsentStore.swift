// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryLogic

@MainActor
protocol SampleRecipeConsentStoring: AnyObject {
  var consent: SampleRecipeConsent { get set }
}

/// Keeps the person's answer outside recipe storage so a future downloadable
/// pack can honor the decision before it opens or migrates the Kitchen.
@MainActor
final class UserDefaultsSampleRecipeConsentStore: SampleRecipeConsentStoring {
  static let key = "sampleRecipes.consent"

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  var consent: SampleRecipeConsent {
    get {
      guard let rawValue = defaults.string(forKey: Self.key) else { return .undecided }
      return SampleRecipeConsent(rawValue: rawValue) ?? .undecided
    }
    set {
      defaults.set(newValue.rawValue, forKey: Self.key)
    }
  }
}

/// Disposable preferences keep previews and UI automation deterministic while
/// exercising the same startup decisions as a durable installation.
@MainActor
final class VolatileSampleRecipeConsentStore: SampleRecipeConsentStoring {
  var consent: SampleRecipeConsent

  init(consent: SampleRecipeConsent = .undecided) {
    self.consent = consent
  }
}
