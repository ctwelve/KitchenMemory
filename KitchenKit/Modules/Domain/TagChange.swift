// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

enum TagChange: OrganizationPayload {
  case create(id: Tag.ID, name: String)
  case rename(id: Tag.ID, name: String)
  case assign(recipeID: Recipe.ID, tagID: Tag.ID)
  case remove(recipeID: Recipe.ID, assignments: [UUID])
  case delete(id: Tag.ID)
  case merge(ids: [Tag.ID], survivorID: Tag.ID, name: String)
  case reorder(id: Tag.ID, afterID: Tag.ID?)
  case ordering(TagOrdering)
  case systemViewVisible(Bool)

  var compactableRegister: String? {
    switch self {
    case let .rename(id, _): return "name:\(id.rawValue.uuidString)"
    case .ordering: return "tag-ordering"
    case .systemViewVisible: return "tag-system-view"
    // Assignment dots and removal receipts remain reconstructive structural evidence.
    default: return nil
    }
  }

  var tagID: Tag.ID? {
    switch self {
    case let .create(id, _), let .rename(id, _), let .delete(id), let .reorder(id, _): return id
    case let .merge(_, survivor, _): return survivor
    case .assign, .remove, .ordering, .systemViewVisible: return nil
    }
  }
}
