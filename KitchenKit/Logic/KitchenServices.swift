// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Supplies localized bundled recipes for a specified Kitchen on the main actor.
@MainActor
public protocol SampleRecipeProviding {
  /// Decodes the selected sample collection scoped to the Kitchen.
  /// Throws when sample content is unavailable; supplying content does not authorize installation.
  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe]
}

/// The durable record of how the first-run sample question was answered.
///
/// Acceptance authorizes that one requested installation, not automatic repair
/// or future transfers. ``SampleRecipePresence`` describes current content.
public enum SampleRecipeOnboardingResponse: String, Equatable, Sendable {
  /// The first-run question has not received an explicit answer.
  case undecided
  /// The person authorized the requested installation, without authorizing future repair.
  case accepted
  /// The person declined the requested first-run installation.
  case declined
}

/// How much of the current localized sample pack is present in one Kitchen.
public enum SampleRecipePresence: Equatable, Sendable {
  /// No stable identity from the current sample pack is present.
  case none
  /// Some, but not all, stable sample identities are present.
  case partial
  /// Every stable identity from the current sample pack is present.
  case complete
  /// Bundled sample content could not be read to establish presence.
  case unavailable
}

/// The personal Kitchen plus whether this launch had to create it locally.
public struct PreparedKitchen: Equatable, Sendable {
  /// Kitchen selected or created by local bootstrap.
  public let kitchen: Kitchen
  /// Whether bootstrap found no Kitchen and had to establish one locally.
  public let wasCreated: Bool

  /// Creates a bootstrap result without performing storage work.
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

  /// Binds bootstrap to the main-actor repository that owns durable Kitchen identity.
  public init(repository: any RecipeRepository) {
    self.repository = repository
  }

  /// Returns an existing personal or legacy Kitchen, or atomically creates an empty one.
  /// Repository failures propagate; absence of Recipe content never authorizes sample installation.
  public func prepareInitialKitchen(named name: String) throws -> Kitchen {
    try prepareInitialKitchenWithStatus(named: name).kitchen
  }

  /// Distinguishes a truly new local Kitchen from one already present in the store.
  public func prepareInitialKitchenWithStatus(
    named name: String,
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

  /// Binds Recipe storage and bundled sample decoding for the service.
  public init(repository: any RecipeRepository, samples: any SampleRecipeProviding) {
    self.repository = repository
    self.samples = samples
  }

  /// Installs sample content through the repository's compatibility authority writer.
  /// Visible Recipes are preserved; compatible retained sample content can be restored
  /// by resolving known deletions. Decoding and repository failures propagate.
  public func install(in kitchenID: Kitchen.ID) throws {
    let sampleRecipes = try samples.recipes(in: kitchenID)
    try repository.addRecipes(sampleRecipes, to: kitchenID)
  }

  /// Derives current state from stable UUIDs rather than the onboarding response.
  public func presence(in kitchenID: Kitchen.ID) throws -> SampleRecipePresence {
    let sampleIDs = Set(try samples.recipes(in: kitchenID).map(\.id))
    let installedIDs = Set(try repository.recipes(in: kitchenID).map(\.id))
    return Self.presence(sampleIDs: sampleIDs, installedIDs: installedIDs)
  }

  /// Derives presence from the same content snapshot a library has already loaded.
  public func presence(in kitchenID: Kitchen.ID, installedRecipeIDs: Set<Recipe.ID>) throws -> SampleRecipePresence {
    let sampleIDs = Set(try samples.recipes(in: kitchenID).map(\.id))
    return Self.presence(sampleIDs: sampleIDs, installedIDs: installedRecipeIDs)
  }

  private static func presence(sampleIDs: Set<Recipe.ID>, installedIDs: Set<Recipe.ID>) -> SampleRecipePresence {
    let installedCount = sampleIDs.intersection(installedIDs).count

    if installedCount == sampleIDs.count { return .complete }
    if installedCount == 0 { return .none }
    return .partial
  }
}

/// Replaces one Kitchen, decoding bundled samples only when installation is requested.
@MainActor
public struct KitchenResetService {
  private let repository: any KitchenResetRepository
  private let samples: any SampleRecipeProviding

  /// Uses a reset repository that owns the complete durable reset boundary.
  public init(repository: any KitchenResetRepository, samples: any SampleRecipeProviding) {
    self.repository = repository
    self.samples = samples
  }

  /// Binds Recipe storage and bundled sample decoding for the service.
  public init(repository: any RecipeRepository, samples: any SampleRecipeProviding) {
    self.init(
      repository: RecipeOnlyKitchenResetRepository(repository: repository),
      samples: samples
    )
  }

  /// Replaces the Kitchen through its reset repository, optionally decoding and installing samples.
  /// Throws on sample or repository failure. Callers must purge device-local editing
  /// and delivery state separately before an explicit reset.
  public func reset(kitchenID: Kitchen.ID, installSamples: Bool = true) throws {
    let sampleRecipes = try installSamples ? samples.recipes(in: kitchenID) : []
    try repository.reset(kitchenID: kitchenID, to: sampleRecipes)
  }
}
