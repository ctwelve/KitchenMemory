// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// A Kitchen-owned location for Recipes, independent of their Revisions.
public struct Folder: Equatable, Identifiable, Sendable {
  /// A domain-typed stable UUID identity, independent of persistence record identity.
  public typealias ID = StableIdentifier<Folder>
  /// The organization identity preserved through Rename and Move, independent of the name.
  public let id: ID
  /// The retained display spelling; sibling comparison uses canonical Unicode and case folding.
  public let name: String
  /// The live projected parent, or nil for the implicit Kitchen root.
  ///
  /// Missing parents and rejected cycle-forming moves can place a Folder at the root.
  public let parentID: ID?
}

/// One deliberate organization change. Prepare against the library the person observed.
public enum FolderIntent: Equatable, Sendable {
  /// Creates a fresh identity with a validated sibling name and optional live parent.
  case create(id: Folder.ID, name: String, parentID: Folder.ID?)
  /// Changes a live Folder’s parent after validating sibling naming and hierarchy acyclicity.
  case move(id: Folder.ID, parentID: Folder.ID?)
  /// Changes display spelling while rejecting a colliding name among observed siblings.
  case rename(id: Folder.ID, name: String)
  /// Places a Folder after a live sibling, or first when the anchor is nil.
  case reorder(id: Folder.ID, afterID: Folder.ID?)
  /// Changes the shared presentation mode without erasing retained manual neighbor order.
  case ordering(FolderOrdering)
  /// Changes shared visibility of the computed Unfiled system view.
  case systemViewVisible(Bool)
  /// Sets a Recipe’s sole primary Folder, or clears it to computed Unfiled.
  case assign(recipeID: Recipe.ID, folderID: Folder.ID?)
  /// Deletes only the observed subtree captured during preparation, without deleting Recipes.
  case delete(id: Folder.ID)
  /// Merges distinct live siblings into an existing survivor, defaulting to the oldest creation.
  ///
  /// Aliases preserve prior identity references; newly colliding children require separate repair.
  case merge(ids: [Folder.ID], survivorID: Folder.ID?, name: String)
}

/// Immutable, retryable organization intent. Preserve this value across retries.
public struct FolderCommand: Codable, Equatable, Sendable {
  /// The immutable action identity bound to its payload and observed causal context.
  public var id: UUID { action.id }
  /// The Kitchen ownership boundary for this value; transport identity cannot substitute for it.
  public let kitchenID: Kitchen.ID
  let action: OrganizationAction<FolderChange>
}

enum FolderChange: OrganizationPayload {
  case create(id: Folder.ID, name: String, parentID: Folder.ID?)
  case move(id: Folder.ID, parentID: Folder.ID?)
  case rename(id: Folder.ID, name: String)
  case reorder(id: Folder.ID, afterID: Folder.ID?)
  case ordering(FolderOrdering)
  case systemViewVisible(Bool)
  case assign(recipeID: Recipe.ID, folderID: Folder.ID?)
  case delete(observedSubtree: [Folder.ID])
  case merge(ids: [Folder.ID], survivorID: Folder.ID, name: String)

  var folderID: Folder.ID? {
    switch self {
    case let .create(id, _, _), let .move(id, _), let .rename(id, _), let .reorder(id, _): return id
    case .assign, .delete, .ordering, .systemViewVisible: return nil
    case let .merge(_, survivorID, _): return survivorID
    }
  }

  var parentID: Folder.ID? {
    switch self {
    case let .create(_, _, parentID), let .move(_, parentID): return parentID
    case .assign, .delete, .rename, .merge, .ordering, .reorder, .systemViewVisible: return nil
    }
  }
}

/// A Folder preparation or evidence-integrity failure, independent of Recipe payload access.
public enum FolderError: Error, Equatable {
  /// Retained organization payload or checkpoint evidence violates a positive integrity invariant.
  case invalidEvidence
  /// The requested neighbor is invalid for the selected item’s ordering scope.
  case invalidOrder
  /// The selected identities cannot form one explicit Merge under this policy.
  case invalidMerge
  /// The entered name is empty, too long, or contains controls or line breaks.
  case invalidName
  /// Another observed live identity already uses the normalized name in this naming scope.
  case duplicateName
  /// An existing creation identity is reused by a different organization intention.
  case identityCollision(Folder.ID)
  /// A required live Folder identity is absent from the observed library.
  case missingFolder(Folder.ID)
  /// The repository cannot accept a fresh assignment to the referenced Recipe.
  case missingRecipe(Recipe.ID)
  /// The requested parent is the Folder itself or lies in its observed subtree.
  case hierarchyCycle
  /// Observed organization predecessor edges form a causal cycle.
  case causalCycle
  /// Commands, checkpoints, or participating libraries disagree on Kitchen ownership.
  case wrongKitchen
  /// One immutable action or receipt identity binds contradictory content.
  case actionCollision(UUID)
}

/// A persistence-independent view of the organization evidence currently available.
public struct FolderLibrary: Equatable, Sendable {
  /// The Kitchen ownership boundary for this value; transport identity cannot substitute for it.
  public let kitchenID: Kitchen.ID
  /// Live projected identities in canonical UUID order; use `children` for presentation ordering.
  public let folders: [Folder]
  /// Distinct live sibling identities sharing a normalized name, retained for explicit repair.
  public let collisions: [FolderCollision]
  /// The causally selected shared ordering mode, defaulting to alphabetical.
  public let ordering: FolderOrdering
  let manualIDs: [Folder.ID]
  let aliases: [Folder.ID: Folder.ID]
  let memberships: [Recipe.ID: Folder.ID]
  let checkpointEvidence: [OrganizationCheckpoint<FolderChange>]
  let rawActionIDs: Set<UUID>
  let actions: [OrganizationAction<FolderChange>]

  /// Reconstructs the available Folder evidence, including compacted receipts.
  ///
  /// Exact retries coalesce; conflicting IDs, malformed payloads, causal cycles, or
  /// wrong ownership throw `FolderError`. Missing parents are not manufactured.
  public init(kitchenID: Kitchen.ID, commands: [FolderCommand], checkpoints: [FolderCheckpoint] = []) throws {
    guard commands.allSatisfy({ $0.kitchenID == kitchenID }) else { throw FolderError.wrongKitchen }
    guard checkpoints.allSatisfy({ $0.kitchenID == kitchenID }) else { throw FolderError.wrongKitchen }
    var retained: [UUID: FolderCheckpoint] = [:]
    for checkpoint in checkpoints {
      guard checkpoint.antiResurrectionUntil >= checkpoint.createdAt.addingTimeInterval(1_827 * 86_400) else {
        throw FolderError.invalidEvidence
      }
      if let prior = retained[checkpoint.id], prior != checkpoint { throw FolderError.actionCollision(checkpoint.id) }
      retained[checkpoint.id] = checkpoint
    }
    checkpointEvidence = retained.values.sorted { $0.id.uuidString < $1.id.uuidString }.map(\.evidence)
    rawActionIDs = Set(commands.map(\.id)).subtracting(checkpointEvidence.flatMap(\.receipts).map(\.id))
    let evidence = try OrganizationEvidence(commands.map(\.action), checkpoints: checkpointEvidence)
    try FolderEvidenceValidation.validate(evidence.actions)
    self.kitchenID = kitchenID
    actions = evidence.actions
    let projection = FolderProjection(evidence: evidence)
    folders = projection.folders
    memberships = projection.memberships
    collisions = FolderCollision.detect(in: folders)
    aliases = projection.aliases
    let order = FolderOrder(evidence: evidence, folders: folders)
    ordering = order.mode
    manualIDs = order.manualIDs
  }

  /// Resolves Merge aliases to a live survivor, returning nil for disposed or missing identities.
  public func canonicalFolderID(for id: Folder.ID) -> Folder.ID? {
    let canonical = aliases[id] ?? id
    return folders.contains(where: { $0.id == canonical }) ? canonical : nil
  }

  /// Returns the Recipe’s live projected primary Folder, or nil for computed Unfiled.
  public func primaryFolder(for recipeID: Recipe.ID) -> Folder.ID? { memberships[recipeID] }

  /// Includes the selected Folder. Uses iterative traversal regardless of tree depth.
  public func subtree(of id: Folder.ID) -> Set<Folder.ID> {
    guard folders.contains(where: { $0.id == id }) else { return [] }
    let children = Dictionary(grouping: folders, by: \.parentID)
    var result: Set<Folder.ID> = []
    var pending = [id]
    while let next = pending.popLast() {
      guard result.insert(next).inserted else { continue }
      pending.append(contentsOf: (children[next] ?? []).map(\.id))
    }
    return result
  }

  /// Validates an intention against this observed library and captures its causal heads.
  ///
  /// Deletion captures the observed subtree; later arrivals are not silently added.
  /// Retain the returned command for exact retry. Recipe existence is checked at the
  /// repository boundary, since this library has no Recipe payload dependency.
  public func prepare(
    _ intent: FolderIntent, id: UUID = UUID(), at date: Date = Date()
  ) throws -> FolderCommand {
    let change: FolderChange
    switch intent {
    case let .create(folderID, name, parentID):
      let displayName = try prepareCreation(id: folderID, name: name, parentID: parentID)
      change = .create(id: folderID, name: displayName, parentID: parentID)
    case let .move(folderID, parentID):
      let folder = try requireFolder(folderID)
      try validateMove(folder, to: parentID)
      change = .move(id: folderID, parentID: parentID)
    case let .rename(folderID, name):
      let folder = try requireFolder(folderID)
      let displayName = try OrganizationName(name)
      try validateName(displayName.value, parentID: folder.parentID, excluding: folderID)
      change = .rename(id: folderID, name: displayName.value)
    case let .assign(recipeID, folderID):
      try validateParent(folderID)
      change = .assign(recipeID: recipeID, folderID: folderID)
    case let .delete(folderID):
      try validateParent(folderID)
      change = .delete(observedSubtree: subtree(of: folderID).sorted {
        $0.rawValue.uuidString < $1.rawValue.uuidString
      })
    case let .merge(ids, survivorID, name):
      change = try prepareMerge(ids: ids, survivorID: survivorID, name: name)
    case let .reorder(folderID, afterID):
      change = try prepareOrder(id: folderID, afterID: afterID)
    case let .ordering(mode): change = .ordering(mode)
    case let .systemViewVisible(visible): change = .systemViewVisible(visible)
    }
    let evidence = try OrganizationEvidence(actions, checkpoints: checkpointEvidence)
    return FolderCommand(kitchenID: kitchenID,
                         action: OrganizationAction(id: id, authoredAt: date,
                                                    observed: evidence.heads, payload: change))
  }

  private func requireFolder(_ id: Folder.ID) throws -> Folder {
    guard let folder = folders.first(where: { $0.id == id }) else { throw FolderError.missingFolder(id) }
    return folder
  }

  private func validateMove(_ folder: Folder, to parentID: Folder.ID?) throws {
    try validateParent(parentID)
    if let parentID, subtree(of: folder.id).contains(parentID) { throw FolderError.hierarchyCycle }
    try validateName(folder.name, parentID: parentID, excluding: folder.id)
  }

  func validateParent(_ parentID: Folder.ID?) throws {
    if let parentID, !folders.contains(where: { $0.id == parentID }) {
      throw FolderError.missingFolder(parentID)
    }
  }

  func validateName(_ name: String, parentID: Folder.ID?, excluding id: Folder.ID? = nil) throws {
    guard !folders.contains(where: {
      $0.id != id && $0.parentID == parentID
        && OrganizationName.comparisonKey($0.name) == OrganizationName.comparisonKey(name)
    }) else { throw FolderError.duplicateName }
  }
}
