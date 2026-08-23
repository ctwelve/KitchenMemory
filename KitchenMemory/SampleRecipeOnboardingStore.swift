// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryLogic

@MainActor
protocol SampleRecipeOnboardingStoring: AnyObject {
  var response: SampleRecipeOnboardingResponse { get set }
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
