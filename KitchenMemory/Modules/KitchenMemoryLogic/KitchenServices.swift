// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import KitchenMemoryPersistence

@MainActor
public protocol SampleRecipeProviding {
  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe]
}

/// The durable record of how the first-run sample question was answered.
///
/// Acceptance authorizes that one requested installation, not automatic repair
/// or future transfers. ``SampleRecipePresence`` describes current content.
public enum SampleRecipeOnboardingResponse: String, Equatable, Sendable {
  case undecided
  case accepted
  case declined
}

/// How much of the current localized sample pack is present in one Kitchen.
public enum SampleRecipePresence: Equatable, Sendable {
  case none
  case partial
  case complete
  case unavailable
}

/// Creates the first empty Kitchen without treating absence of recipes as permission.
@MainActor
public struct KitchenBootstrapService {
  private let repository: any RecipeRepository

  public init(repository: any RecipeRepository) {
    self.repository = repository
  }

  public func prepareInitialKitchen(named name: String = "Home Kitchen") throws -> Kitchen {
    if let existingKitchen = try repository.kitchens().first { return existingKitchen }
    let kitchen = Kitchen(name: name)
    try repository.create(kitchen, with: [])
    return kitchen
  }
}

/// Installs a sample collection without replacing user recipes or matching UUIDs.
@MainActor
public struct SampleRecipeInstallService {
  private let repository: any RecipeRepository
  private let samples: any SampleRecipeProviding

  public init(repository: any RecipeRepository, samples: any SampleRecipeProviding) {
    self.repository = repository
    self.samples = samples
  }

  public func install(in kitchenID: Kitchen.ID) throws {
    let sampleRecipes = try samples.recipes(in: kitchenID)
    try repository.addRecipes(sampleRecipes, to: kitchenID)
  }

  /// Derives current state from stable UUIDs rather than the onboarding response.
  public func presence(in kitchenID: Kitchen.ID) throws -> SampleRecipePresence {
    let sampleIDs = Set(try samples.recipes(in: kitchenID).map(\.id))
    let installedIDs = Set(try repository.recipes(in: kitchenID).map(\.id))
    let installedCount = sampleIDs.intersection(installedIDs).count

    if installedCount == sampleIDs.count { return .complete }
    if installedCount == 0 { return .none }
    return .partial
  }
}

/// Replaces one Kitchen only after every bundled sample has been decoded.
@MainActor
public struct KitchenResetService {
  private let repository: any RecipeRepository
  private let samples: any SampleRecipeProviding

  public init(repository: any RecipeRepository, samples: any SampleRecipeProviding) {
    self.repository = repository
    self.samples = samples
  }

  public func reset(kitchenID: Kitchen.ID) throws {
    let sampleRecipes = try samples.recipes(in: kitchenID)
    try repository.replaceRecipes(in: kitchenID, with: sampleRecipes)
  }
}
