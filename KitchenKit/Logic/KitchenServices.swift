// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

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

/// The personal Kitchen plus whether this launch had to create it locally.
public struct PreparedKitchen: Equatable, Sendable {
  public let kitchen: Kitchen
  public let wasCreated: Bool

  public init(kitchen: Kitchen, wasCreated: Bool) {
    self.kitchen = kitchen
    self.wasCreated = wasCreated
  }
}

/// Creates the first empty Kitchen without treating absence of recipes as permission.
@MainActor
public struct KitchenBootstrapService {
  /// The stable identity used for a person's default Kitchen across installations.
  ///
  /// Reusing this identity lets independently launched installations converge.
  /// Account isolation and transport remain persistence-adapter responsibilities.
  public static var personalKitchenID: Kitchen.ID {
    Kitchen.ID(rawValue: UUID(uuidString: "5D4167A0-7027-4A3D-A170-0B73E86DCE8D")!)
  }

  private let repository: any RecipeRepository

  public init(repository: any RecipeRepository) {
    self.repository = repository
  }

  public func prepareInitialKitchen(named name: String = "Home Kitchen") throws -> Kitchen {
    try prepareInitialKitchenWithStatus(named: name).kitchen
  }

  /// Distinguishes a truly new local Kitchen from one already present in the store.
  public func prepareInitialKitchenWithStatus(
    named name: String = "Home Kitchen",
    ownerID: KitchenOwner.ID? = nil
  ) throws -> PreparedKitchen {
    if let ownerID {
      let kitchens = try repository.kitchens()
      let wasCreated = kitchens.isEmpty
      let resolvedName = kitchens.first(where: { $0.id == Self.personalKitchenID })?.name
        ?? kitchens.first?.name
        ?? name
      let personalKitchen = Kitchen(
        id: Self.personalKitchenID,
        ownerID: ownerID,
        name: resolvedName
      )
      try repository.convergeKitchens(into: personalKitchen, ownedBy: ownerID)
      return PreparedKitchen(kitchen: personalKitchen, wasCreated: wasCreated)
    }
    if let personalKitchen = try repository.kitchen(id: Self.personalKitchenID) {
      return PreparedKitchen(kitchen: personalKitchen, wasCreated: false)
    }
    // Preserve a pre-sync development Kitchen rather than orphaning its recipes.
    // Development data is reset before release, so fresh 1.0 installations all
    // use the deterministic personal identity above.
    if let legacyKitchen = try repository.kitchens().first {
      return PreparedKitchen(kitchen: legacyKitchen, wasCreated: false)
    }
    let kitchen = Kitchen(id: Self.personalKitchenID, name: name)
    try repository.create(kitchen, with: [])
    return PreparedKitchen(kitchen: kitchen, wasCreated: true)
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
