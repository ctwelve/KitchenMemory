// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Algorithms
import Foundation
import SwiftData

// Persistence reconstruction is deliberately kept beside its inverse mapping
// so schema changes can be reviewed in both directions.
// swiftlint:disable file_length type_body_length

/// A recipe together with the revision selected as its current content.
public struct StoredRecipe: Codable, Equatable, Identifiable, Sendable {
  /// Stable Recipe identity, independent of which Revision is selected.
  public var id: Recipe.ID { recipe.id }
  /// Durable Recipe identity and the selected current-revision reference.
  public let recipe: Recipe
  /// Immutable revision presented as current content for the paired Recipe.
  public let revision: RecipeRevision

  /// Pairs domain values without validation or storage; repository writes validate their identities.
  public init(recipe: Recipe, revision: RecipeRevision) {
    self.recipe = recipe
    self.revision = revision
  }
}

/// Domain-facing Recipe storage and immutable authority operations.
///
/// The protocol mentions no SwiftData types, so application use cases and test
/// doubles can depend on it without adopting the persistence framework.
/// Every adapter must implement authority guarantees or explicitly reject the
/// operation; no default fabricates evidence or weakens a Save command.
@MainActor
public protocol RecipeRepository: AnyObject {
  /// Persists Kitchen identity and name without authorizing Recipe or sample installation.
  func save(_ kitchen: Kitchen) throws
  /// Atomically creates a previously absent Kitchen and its initial Recipe authority.
  /// Existing Kitchen, invalid ownership, and inconsistent supplied identities throw.
  func create(_ kitchen: Kitchen, with recipes: [StoredRecipe]) throws
  /// Accepts a compatibility Recipe/revision pair through the immutable authority writer.
  /// Callers needing explicit retry control should retain a ``RecipeSaveCommand`` instead.
  func save(recipe: Recipe, revision: RecipeRevision) throws
  /// Atomically accepts one caller-identified immutable Save and Selection.
  /// Identical retry coalesces; changed identity reuse throws. Success proves local
  /// durability only, and retries must retain the same complete command envelope.
  func save(_ command: RecipeSaveCommand) throws
  /// Accepts deletion evidence while retaining Recipe history; exact retry is idempotent.
  func delete(_ command: RecipeDeleteCommand) throws
  /// Atomically resolves the deletion markers named by an explicit Restore.
  /// Unobserved deletions remain effective; invalid markers and changed retry identity throw.
  func restore(_ command: RecipeRestoreCommand) throws
  /// Reads retained Deleted Items, including incomplete or invalid authority requiring attention.
  /// Pruned Recipes and late-evidence-after-prune Recovery are not restorable Deleted Items.
  func deletedRecipes(in kitchenID: Kitchen.ID) throws -> [DeletedRecipe]
  /// Accepts an immutable choice of an existing accepted Revision.
  /// Its observed Selection frontier preserves concurrent unseen choices rather than using timestamps.
  func select(_ command: RecipeSelectionCommand) throws
  /// Returns the locally observed maximal Selection identities for a Recipe.
  /// Retain this frontier with an edit or choice; it is not evidence of global synchronization.
  func selectionHeads(for recipeID: Recipe.ID) throws -> [RecipeSelectionCommand.ID]
  /// Reads locally retained Kitchens as domain values without exposing managed records.
  func kitchens() throws -> [Kitchen]
  /// Reads one Kitchen identity, or nil when absent; ownership decoding errors propagate.
  func kitchen(id: Kitchen.ID) throws -> Kitchen?
  /// Atomically claims eligible unowned Kitchens and converges matching owner scope.
  /// Explicit evidence of another owner rejects the operation without moving their content.
  func convergeKitchens(into kitchen: Kitchen, ownedBy ownerID: KitchenOwner.ID) throws
  /// Reads ordinary current Recipe content, or nil for absent, deleted, pruned, or withheld content.
  /// Use ``recipeAuthority(id:)`` to distinguish withheld classifications; missing required
  /// revision or invalid stored authority may throw rather than supply partial content.
  func recipe(id: Recipe.ID) throws -> StoredRecipe?
  /// Classifies locally retained authority and payload as available, deleted, pruned, Unavailable, or Recovery.
  /// V5 currentness comes from Selection evidence; the retained pre-V5 compatibility
  /// path still supports legacy Recipe graphs. No managed records cross this boundary.
  func recipeAuthority(id: Recipe.ID) throws -> RecipeAuthorityProjection?
  /// Reads unavailable or invalid authority and independently decodable recovery payloads.
  /// Competing Selections use reconciliation; malformed payloads are not offered as recovered content.
  func recoveryRecipes(in kitchenID: Kitchen.ID) throws -> [RecipeRecovery]
  /// Rechecks retention eligibility and dependencies before atomically pruning payload with tombstones.
  /// Age alone does not permit pruning; retained Session media and unreadable dependency evidence block it.
  func maintainDeletedRecipes(in kitchenID: Kitchen.ID, at now: Date) throws -> RecipeRetentionResult
  /// Returns explicit comparisons for surviving revision branches or competing Selections.
  /// The compared parent set and observed Selection frontier are retained without choosing a winner.
  func reconciliations(in kitchenID: Kitchen.ID) throws -> [RecipeReconciliation]
  /// Reads ordinary visible Recipes with selected current content.
  /// Deleted, pruned, and Recovery items are withheld; missing required payload or decode failures may throw.
  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe]
  /// Atomically installs supplied content through the compatibility authority writer.
  /// Visible Recipes are preserved; compatible retained content can be made visible
  /// by resolving known deletion evidence. Conflicting authority or ownership throws.
  func addRecipes(_ recipes: [StoredRecipe], to kitchenID: Kitchen.ID) throws
  /// Returns retained revisions in descending revision-number order.
  /// The descriptive ordering does not select current content or resolve concurrent authority.
  func revisions(for recipeID: Recipe.ID) throws -> [RecipeRevision]
  /// Atomically replaces Recipe content for an explicit Kitchen reset.
  /// This Recipe-only compatibility operation does not erase Session or organization
  /// evidence; production reset uses ``KitchenResetRepository``.
  func replaceRecipes(in kitchenID: Kitchen.ID, with recipes: [StoredRecipe]) throws
}

/// Failures detected while translating between domain values and stored rows.
public enum KitchenMemoryPersistenceError: Error, Equatable {
  /// The recipe and revision do not refer to each other as current content.
  case inconsistentRecipeIdentity

  /// A recipe cannot be saved before its owning Kitchen exists.
  case missingKitchen

  /// Bootstrap cannot replace an already-created Kitchen implicitly.
  case kitchenAlreadyExists(kitchenID: Kitchen.ID)

  /// Kitchens with explicit different owners must never be merged.
  case kitchenOwnedByAnotherOwner(kitchenID: Kitchen.ID)

  /// A repository adapter has not implemented the V4 ownership operation.
  case ownershipConvergenceUnsupported

  /// A recipe row refers to a revision that is absent from the store.
  case missingCurrentRevision

  /// A stable recipe identity cannot move between Kitchens through an upsert.
  case recipeAlreadyOwnedByAnotherKitchen(recipeID: Recipe.ID)

  /// A stable revision identity cannot move between recipes through an upsert.
  case revisionAlreadyOwnedByAnotherRecipe(revisionID: RecipeRevision.ID)

  /// A bulk replacement must describe each durable recipe identity once.
  case duplicateRecipeID(recipeID: Recipe.ID)

  /// A bulk replacement must describe each durable revision identity once.
  case duplicateRevisionID(revisionID: RecipeRevision.ID)

  /// A stored current revision points back to a different recipe identity.
  case inconsistentStoredRecipeIdentity(
    recipeID: Recipe.ID,
    revisionID: RecipeRevision.ID
  )

  /// Persisted encoded data or an enum raw value cannot be decoded safely.
  case invalidStoredValue(field: String)

  /// One logical Save identity described two different command envelopes.
  case recipeSaveCommandCollision(commandID: RecipeSaveCommand.ID)

  /// One logical Selection identity described two different command envelopes.
  case recipeSelectionCommandCollision(commandID: RecipeSelectionCommand.ID)

  /// A Save command's redundant identities or causal sets are inconsistent.
  case invalidRecipeSaveCommand

  /// A repository adapter has not implemented immutable Recipe Selection.
  case recipeSelectionUnsupported

  /// A narrow adapter does not implement immutable Save or authority reads.
  case recipeSaveUnsupported
  /// The adapter does not implement classified immutable Recipe authority reads.
  case recipeAuthorityUnsupported
  /// The adapter does not implement reads of the observed Selection frontier.
  case recipeSelectionHeadsUnsupported
}
