// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// A flat Kitchen-owned classification of stable Recipes.
public struct Tag: Equatable, Identifiable, Sendable {
  public typealias ID = StableIdentifier<Tag>
  public let id: ID
  public let name: String
  public var displayName: String { "#" + name }
}

public enum TagOrdering: String, Codable, Equatable, Sendable {
  case alphabetical
  case manual
}

public enum TagIntent: Equatable, Sendable {
  case create(id: Tag.ID, name: String)
  case rename(id: Tag.ID, name: String)
  case assign(recipeID: Recipe.ID, tagID: Tag.ID)
  case remove(recipeID: Recipe.ID, tagID: Tag.ID)
  case delete(id: Tag.ID)
  case merge(ids: [Tag.ID], survivorID: Tag.ID?, name: String)
  case reorder(id: Tag.ID, afterID: Tag.ID?)
  case ordering(TagOrdering)
}

/// Preserve the prepared command for exact retries, including observed assignment dots.
public struct TagCommand: Codable, Equatable, Sendable {
  public var id: UUID { action.id }
  public let kitchenID: Kitchen.ID
  let action: OrganizationAction<TagChange>
}

enum TagChange: OrganizationPayload {
  case create(id: Tag.ID, name: String)
  case rename(id: Tag.ID, name: String)
  case assign(recipeID: Recipe.ID, tagID: Tag.ID)
  case remove(recipeID: Recipe.ID, tagID: Tag.ID, assignments: [UUID])
  case delete(id: Tag.ID)
  case merge(ids: [Tag.ID], survivorID: Tag.ID, name: String)
  case reorder(id: Tag.ID, afterID: Tag.ID?)
  case ordering(TagOrdering)

  var compactableRegister: String? {
    switch self {
    case let .rename(id, _): return "name:\(id.rawValue.uuidString)"
    case .ordering: return "tag-ordering"
    // Assignment dots and removal receipts remain reconstructive structural evidence.
    default: return nil
    }
  }

  var tagID: Tag.ID? {
    switch self {
    case let .create(id, _), let .rename(id, _), let .delete(id), let .reorder(id, _): return id
    case let .merge(_, survivor, _): return survivor
    case .assign, .remove, .ordering: return nil
    }
  }
}

public enum TagError: Error, Equatable {
  case invalidEvidence
  case invalidOrder
  case invalidMerge
  case invalidName
  case duplicateName
  case identityCollision(Tag.ID)
  case missingTag(Tag.ID)
  case missingRecipe(Recipe.ID)
  case causalCycle
  case wrongKitchen
  case actionCollision(UUID)
}

/// Keeps the shared substrate's historical Folder errors behind the Tag interface.
func tagBoundary<Value>(_ operation: () throws -> Value) throws -> Value {
  do { return try operation() } catch let error as FolderError {
    switch error {
    case .invalidName: throw TagError.invalidName
    case .causalCycle: throw TagError.causalCycle
    case .wrongKitchen: throw TagError.wrongKitchen
    case let .missingRecipe(id): throw TagError.missingRecipe(id)
    case let .actionCollision(id): throw TagError.actionCollision(id)
    default: throw TagError.invalidEvidence
    }
  }
}

struct TagName {
  let value: String
  init(_ entered: String) throws {
    value = try tagBoundary {
      guard !entered.unicodeScalars.contains(where: {
        CharacterSet.controlCharacters.contains($0) || CharacterSet.newlines.contains($0)
      }) else { throw TagError.invalidName }
      let checked = entered.trimmingCharacters(in: .whitespacesAndNewlines)
      let unprefixed = String(checked.drop(while: { $0 == "#" }))
      return try OrganizationName(unprefixed).value
    }
  }
}
