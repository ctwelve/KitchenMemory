// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit

enum PendingCookingSessionResolution {
  case accepted(CookingSessionProjection)
  case rejectedByFinishedSource
  case retiredStaleRestore(CookingSessionAttention)
  case retiredCompletedRestore
  case retiredStaleClosureSelection(CookingSessionAttention)
  case attention(CookingSessionAttention)

  init(
    result: CookingSessionCommandResult,
    pending: PendingCookingSessionCommand
  ) {
    switch (result, pending) {
    case let (.accepted(session), _):
      self = .accepted(session)
    case (.attention(.commandNotAllowed(lifecycle: .finished)), _):
      self = .rejectedByFinishedSource
    case let (.attention(.competingDeletions(deletionIDs)), .restore):
      self = .retiredStaleRestore(.competingDeletions(deletionIDs))
    case (.attention(.restoreNotNeeded), .restore):
      self = .retiredCompletedRestore
    case let (.attention(.recovery(recovery)), .resolveClosure):
      self = .retiredStaleClosureSelection(.recovery(recovery))
    case let (.attention(attention), _):
      self = .attention(attention)
    }
  }
}
