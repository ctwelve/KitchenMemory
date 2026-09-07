// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

@MainActor
public protocol SamplePackRepository {
  func status(in kitchenID: Kitchen.ID, samples: [StoredRecipe]) throws -> SamplePackStatus
  func accept(_ command: SamplePackCommand) throws
}

/// One local transaction uses ordinary Recipe Save, Delete, Restore, Folder and Tag acceptance.
@MainActor
public final class SwiftDataSamplePackRepository: SamplePackRepository {
  private let container: ModelContainer
  private var receipts: OrganizationStore<SamplePackReceipt> {
    OrganizationStore(modelContainer: container, namespace: "sample-pack", recipeID: { _ in nil })
  }

  public init(modelContainer: ModelContainer) { container = modelContainer }

  public func status(in kitchenID: Kitchen.ID, samples: [StoredRecipe]) throws -> SamplePackStatus {
    let context = ModelContext(container)
    return try status(in: kitchenID, samples: samples, context: context)
  }

  private func evidence(in kitchenID: Kitchen.ID, context: ModelContext) throws
    -> OrganizationEvidence<SamplePackReceipt> {
    let snapshot = try receipts.load(in: kitchenID, context: context)
    guard snapshot.checkpoints.isEmpty else { throw FolderError.invalidEvidence }
    return try OrganizationEvidence(snapshot.actions)
  }

  private func status(in kitchenID: Kitchen.ID, samples: [StoredRecipe], context: ModelContext) throws
    -> SamplePackStatus {
    try validate(samples, in: kitchenID)
    let writer = SwiftDataRecipeRepository(context: context)
    let evidence = try evidence(in: kitchenID, context: context)
    let last = evidence.winner(in: evidence.actions)?.payload
    var installed = 0
    var edited = 0
    var deleted = 0
    var unavailable = 0
    var removable: Set<Recipe.ID> = []
    for sample in samples {
      switch try writer.recipeAuthority(id: sample.id) {
      case .available(let value):
        guard value.recipe.kitchenID == kitchenID else { throw FolderError.wrongKitchen }
        installed += 1
        if try untouched(value, sample: sample) { removable.insert(sample.id) } else { edited += 1 }
      case .deleted(let value):
        guard value.recipe.kitchenID == kitchenID else { throw FolderError.wrongKitchen }
        deleted += 1
        if try !untouched(value, sample: sample) { edited += 1 }
      case .pruned, .unavailable, .recovery: unavailable += 1
      case .none: break
      }
    }
    return SamplePackStatus(
      isEnabled: last?.enabled ?? false, total: samples.count,
      installed: installed, edited: edited, deleted: deleted, unavailable: unavailable,
      removableIDs: removable, folderID: last?.folderID, tagID: last?.tagID)
  }

  private func untouched(_ value: AvailableRecipeAuthority, sample: StoredRecipe) throws -> Bool {
    guard value.revisions.count == 1 else { return false }
    return try RecipeRevisionCodec.encode(value.current).digest == RecipeRevisionCodec.encode(sample.revision).digest
  }

  private func validate(_ samples: [StoredRecipe], in kitchenID: Kitchen.ID) throws {
    guard Set(samples.map(\.id)).count == samples.count,
      samples.allSatisfy({ $0.recipe.kitchenID == kitchenID && $0.revision.recipeID == $0.id })
    else {
      throw KitchenMemoryPersistenceError.inconsistentRecipeIdentity
    }
  }

  public func accept(_ command: SamplePackCommand) throws {
    try validate(command.samples, in: command.kitchenID)
    guard command.removalIDs.isSubset(of: Set(command.samples.map(\.id))) else {
      throw RecipeDispositionError.invalidCommand
    }
    let digest = try OrganizationCoding.digest(command)
    let context = ModelContext(container)
    try context.transaction {
      let evidence = try evidence(in: command.kitchenID, context: context)
      if let accepted = evidence.actions.first(where: { $0.id == command.id }) {
        guard accepted.payload.digest == digest else { throw FolderError.actionCollision(command.id) }
        return
      }
      let prior = evidence.winner(in: evidence.actions)?.payload
      var folderID = prior?.folderID
      var tagID = prior?.tagID
      if command.enabled {
        (folderID, tagID) = try install(command, prior: prior, context: context)
      } else {
        let current = try status(in: command.kitchenID, samples: command.samples, context: context)
        let writer = SwiftDataRecipeRepository(context: context)
        for id in command.removalIDs.intersection(current.removableIDs).sorted(by: order) {
          try writer.acceptDeletion(
            RecipeDeleteCommand(
              id: child(command, "delete", id.rawValue), kitchenID: command.kitchenID,
              recipeID: id, deletedAt: command.authoredAt))
        }
      }
      let receipt = OrganizationAction(
        id: command.id, authoredAt: command.authoredAt, observed: evidence.heads,
        payload: SamplePackReceipt(digest: digest, enabled: command.enabled, folderID: folderID, tagID: tagID))
      try receipts.append(receipt, in: command.kitchenID, context: context) { snapshot in
        _ = try OrganizationEvidence(snapshot.actions)
      }
    }
  }

  private func install(_ command: SamplePackCommand, prior: SamplePackReceipt?, context: ModelContext) throws
    -> (Folder.ID?, Tag.ID?) {
    let folders = SwiftDataFolderRepository(modelContainer: container)
    let tags = SwiftDataTagRepository(modelContainer: container)
    let folderID = try folderTarget(command, prior: prior, context: context)
    let tagID = try tagTarget(command, prior: prior, context: context)
    let folderState = try folders.library(in: command.kitchenID, context: context)
    let tagState = try tags.library(in: command.kitchenID, context: context)
    let assigned = try installRecipes(command, explicitTransition: prior?.enabled != true, context: context)
    let moved = try assigned.sorted(by: order).compactMap { id in
      try folderID.map { folder in
        try folderState.prepare(
          .assign(recipeID: id, folderID: folder),
          id: child(command, "assign-folder", id.rawValue), at: command.authoredAt)
      }
    }
    let classified = try assigned.sorted(by: order).compactMap { id in
      try tagID.map { tag in
        try tagState.prepare(
          .assign(recipeID: id, tagID: tag),
          id: child(command, "assign-tag", id.rawValue), at: command.authoredAt)
      }
    }
    try folders.append(moved, in: command.kitchenID, context: context)
    try tags.append(classified, in: command.kitchenID, context: context)
    return (folderID, tagID)
  }

  private func folderTarget(_ command: SamplePackCommand, prior: SamplePackReceipt?, context: ModelContext) throws
    -> Folder.ID? {
    let repository = SwiftDataFolderRepository(modelContainer: container)
    let state = try repository.library(in: command.kitchenID, context: context)
    if prior?.enabled == true { return prior?.folderID.flatMap { state.canonicalFolderID(for: $0) } }
    let key = try OrganizationName(command.folderName).key
    if let match = state.folders.filter({ $0.parentID == nil && OrganizationName.comparisonKey($0.name) == key })
      .min(by: { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }) { return match.id }
    let creation = try state.prepare(.create(id: command.proposedFolderID, name: command.folderName, parentID: nil),
      id: child(command, "folder", command.proposedFolderID.rawValue), at: command.authoredAt)
    try repository.append([creation], in: command.kitchenID, context: context)
    return command.proposedFolderID
  }

  private func tagTarget(_ command: SamplePackCommand, prior: SamplePackReceipt?, context: ModelContext) throws
    -> Tag.ID? {
    let repository = SwiftDataTagRepository(modelContainer: container)
    let state = try repository.library(in: command.kitchenID, context: context)
    if prior?.enabled == true { return prior?.tagID.flatMap { state.canonicalTagID(for: $0) } }
    let key = OrganizationName.comparisonKey(try TagName(command.tagName).value)
    if let match = state.tags.filter({ OrganizationName.comparisonKey($0.name) == key })
      .min(by: { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }) { return match.id }
    let creation = try state.prepare(.create(id: command.proposedTagID, name: command.tagName),
      id: child(command, "tag", command.proposedTagID.rawValue), at: command.authoredAt)
    try repository.append([creation], in: command.kitchenID, context: context)
    return command.proposedTagID
  }

  private func installRecipes(_ command: SamplePackCommand, explicitTransition: Bool, context: ModelContext) throws
    -> Set<Recipe.ID> {
    let writer = SwiftDataRecipeRepository(context: context)
    var assigned: Set<Recipe.ID> = []
    let deleted = try writer.deletedRecipes(in: command.kitchenID)
    for sample in command.samples {
      switch try writer.recipeAuthority(id: sample.id) {
      case .none:
        try writer.accept(writer.legacyAuthorityCommand(for: sample))
        assigned.insert(sample.id)
      case .available(let value):
        guard value.recipe.kitchenID == command.kitchenID else { throw FolderError.wrongKitchen }
        if explicitTransition, try untouched(value, sample: sample) { assigned.insert(sample.id) }
      case .deleted(let value):
        guard value.recipe.kitchenID == command.kitchenID else { throw FolderError.wrongKitchen }
        if explicitTransition, try untouched(value, sample: sample),
          let item = deleted.first(where: { $0.id == sample.id }) {
          let restorations = item.observedDeletionIDs.map {
            RecipeRestoration(id: child(command, "restore", $0), deletionID: $0)
          }
          try writer.acceptRestoration(
            RecipeRestoreCommand(
              kitchenID: command.kitchenID,
              recipeID: sample.id, restorations: restorations, restoredAt: command.authoredAt))
          assigned.insert(sample.id)
        }
      case .pruned, .unavailable, .recovery: break
      }
    }
    return assigned
  }

  private func child(_ command: SamplePackCommand, _ kind: String, _ source: UUID) -> UUID {
    derivedID(namespace: command.id, kind: "sample-pack/" + kind, source: source)
  }

  private func order(_ lhs: Recipe.ID, _ rhs: Recipe.ID) -> Bool {
    lhs.rawValue.uuidString < rhs.rawValue.uuidString
  }
}
