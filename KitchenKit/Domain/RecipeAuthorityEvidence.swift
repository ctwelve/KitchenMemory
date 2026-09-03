// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

public struct RecipeSaveEvidence: Equatable, Sendable {
  public let id: UUID
  public let kitchenID: Kitchen.ID
  public let recipeID: Recipe.ID
  public let revisionID: RecipeRevision.ID
  public let savedAt: Date
  public let ancestryFormatVersion: Int
  public let parentRevisionIDsData: Data
  public let payloadManifestFormatVersion: Int
  public let payloadManifestData: Data
  public let revisionFormatVersion: Int
  public let revisionDigest: Data

  public init(
    id: UUID, kitchenID: Kitchen.ID, recipeID: Recipe.ID,
    revisionID: RecipeRevision.ID, savedAt: Date,
    ancestryFormatVersion: Int, parentRevisionIDsData: Data,
    payloadManifestFormatVersion: Int, payloadManifestData: Data,
    revisionFormatVersion: Int, revisionDigest: Data
  ) {
    self.id = id
    self.kitchenID = kitchenID
    self.recipeID = recipeID
    self.revisionID = revisionID
    self.savedAt = savedAt
    self.ancestryFormatVersion = ancestryFormatVersion
    self.parentRevisionIDsData = parentRevisionIDsData
    self.payloadManifestFormatVersion = payloadManifestFormatVersion
    self.payloadManifestData = payloadManifestData
    self.revisionFormatVersion = revisionFormatVersion
    self.revisionDigest = revisionDigest
  }
}

public struct RecipeSelectionEvidence: Equatable, Sendable {
  public let id: UUID
  public let kitchenID: Kitchen.ID
  public let recipeID: Recipe.ID
  public let selectedRevisionID: RecipeRevision.ID
  public let selectedAt: Date
  public let frontierFormatVersion: Int
  public let observedSelectionIDsData: Data

  public init(
    id: UUID, kitchenID: Kitchen.ID, recipeID: Recipe.ID,
    selectedRevisionID: RecipeRevision.ID, selectedAt: Date,
    frontierFormatVersion: Int, observedSelectionIDsData: Data
  ) {
    self.id = id
    self.kitchenID = kitchenID
    self.recipeID = recipeID
    self.selectedRevisionID = selectedRevisionID
    self.selectedAt = selectedAt
    self.frontierFormatVersion = frontierFormatVersion
    self.observedSelectionIDsData = observedSelectionIDsData
  }
}

public struct RecipeDeletionEvidence: Equatable, Sendable {
  public let id: UUID
  public let kitchenID: Kitchen.ID
  public let recipeID: Recipe.ID
  public let deletedAt: Date?

  public init(
    id: UUID, kitchenID: Kitchen.ID, recipeID: Recipe.ID, deletedAt: Date?
  ) {
    self.id = id
    self.kitchenID = kitchenID
    self.recipeID = recipeID
    self.deletedAt = deletedAt
  }
}

public struct RecipeRestorationEvidence: Equatable, Sendable {
  public let id: UUID
  public let deletionID: UUID
  public let kitchenID: Kitchen.ID?
  public let recipeID: Recipe.ID
  public let restoredAt: Date?

  public init(
    id: UUID, deletionID: UUID, kitchenID: Kitchen.ID?,
    recipeID: Recipe.ID, restoredAt: Date?
  ) {
    self.id = id
    self.deletionID = deletionID
    self.kitchenID = kitchenID
    self.recipeID = recipeID
    self.restoredAt = restoredAt
  }
}

public struct RecipePruneEvidence: Equatable, Sendable {
  public let id: UUID
  public let kitchenID: Kitchen.ID
  public let recipeID: Recipe.ID
  public let prunedAt: Date
  public let antiResurrectionUntil: Date
  public let frontierFormatVersion: Int
  public let frontierData: Data
  public let frontierDigest: Data

  public init(
    id: UUID, kitchenID: Kitchen.ID, recipeID: Recipe.ID,
    prunedAt: Date, antiResurrectionUntil: Date,
    frontierFormatVersion: Int, frontierData: Data, frontierDigest: Data
  ) {
    self.id = id
    self.kitchenID = kitchenID
    self.recipeID = recipeID
    self.prunedAt = prunedAt
    self.antiResurrectionUntil = antiResurrectionUntil
    self.frontierFormatVersion = frontierFormatVersion
    self.frontierData = frontierData
    self.frontierDigest = frontierDigest
  }
}

public struct RecipeAuthorityEvidence: Equatable, Sendable {
  public let kitchenID: Kitchen.ID
  public let recipeID: Recipe.ID
  public let saves: [RecipeSaveEvidence]
  public let selections: [RecipeSelectionEvidence]
  public let revisions: [RecipeRevision]
  public let deletions: [RecipeDeletionEvidence]
  public let restorations: [RecipeRestorationEvidence]
  public let prunes: [RecipePruneEvidence]

  public init(
    kitchenID: Kitchen.ID,
    recipeID: Recipe.ID,
    saves: [RecipeSaveEvidence],
    selections: [RecipeSelectionEvidence],
    revisions: [RecipeRevision],
    deletions: [RecipeDeletionEvidence] = [],
    restorations: [RecipeRestorationEvidence] = [],
    prunes: [RecipePruneEvidence] = []
  ) {
    self.kitchenID = kitchenID
    self.recipeID = recipeID
    self.saves = saves
    self.selections = selections
    self.revisions = revisions
    self.deletions = deletions
    self.restorations = restorations
    self.prunes = prunes
  }
}

public struct ProjectedRecipeRevision: Equatable, Sendable {
  public enum State: Equatable, Sendable {
    case current
    case previous
    case competing
    case reconciled
  }

  public let revision: RecipeRevision
  public let state: State
}

public struct AvailableRecipeAuthority: Equatable, Sendable {
  public let recipe: Recipe
  public let revisions: [ProjectedRecipeRevision]

  public var current: RecipeRevision {
    // Construction always includes exactly one current projection.
    // swiftlint:disable:next force_unwrapping
    revisions.first { $0.state == .current }!.revision
  }
}

public enum RecipeAuthorityUnavailableReason: Equatable, Sendable {
  case noSaveEvidence
  case noSelectionEvidence
  case unsupportedFormat(Int)
  case missingSave(RecipeRevision.ID)
  case missingRevision(RecipeRevision.ID)
  case missingParent(RecipeRevision.ID)
  case missingSelection(UUID)
  case incompleteManifest(RecipeRevision.ID)
  case missingDeletion(UUID)
}

public enum RecipeAuthorityRecoveryReason: Equatable, Sendable {
  case commandCollision(UUID)
  case payloadCollision(RecipeRevision.ID)
  case crossOwnership
  case malformedEncoding
  case manifestMismatch(RecipeRevision.ID)
  case digestMismatch(RecipeRevision.ID)
  case revisionCycle
  case selectionCycle
  case selectedRevisionIsNotAccepted(RecipeRevision.ID)
  case competingSelections([RecipeRevision.ID])
  case lateEvidenceAfterPrune
}

public enum RecipeAuthorityProjection: Equatable, Sendable {
  case available(AvailableRecipeAuthority)
  case deleted(AvailableRecipeAuthority)
  case pruned
  case unavailable(RecipeAuthorityUnavailableReason)
  case recovery(RecipeAuthorityRecoveryReason)
}
