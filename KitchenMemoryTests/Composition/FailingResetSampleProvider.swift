// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit

@MainActor
final class FailingResetSampleProvider: SampleRecipeProviding {
  var shouldFail = false
  struct Failure: Error {}

  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] {
    if shouldFail { throw Failure() }
    return []
  }
}
