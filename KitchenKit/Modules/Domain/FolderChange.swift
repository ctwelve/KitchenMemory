// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

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
