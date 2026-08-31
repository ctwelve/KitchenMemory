// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit

enum PendingCookingSessionResolution {
  case accepted(CookingSessionProjection)
  case rejectedByFinishedSource
  case retiredStaleConsent(CookingSessionAttention)
  case retiredCompletedRestore
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
      // Restore consent covers exactly one observed deletion frontier.
      self = .retiredStaleConsent(.competingDeletions(deletionIDs))
    case (.attention(.restoreNotNeeded), .restore):
      self = .retiredCompletedRestore
    case let (.attention(.recovery(recovery)), .resolveClosure):
      // Closure consent covers exactly one complete observed candidate set.
      self = .retiredStaleConsent(.recovery(recovery))
    case let (.attention(.unavailable(unavailable)), .resolveClosure):
      // Partial evidence invalidates the old complete candidate set too.
      self = .retiredStaleConsent(.unavailable(unavailable))
    case let (.attention(attention), _):
      self = .attention(attention)
    }
  }
}
