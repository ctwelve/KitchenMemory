// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import OrderedCollections

enum IdentityCoalescingResult<Value: Equatable, Identity: Hashable>: Equatable {
  case coalesced([Value])
  case collision(identity: Identity)
}

/// Kitchen Memory-owned identity semantics for unordered retained evidence.
///
/// Both operations preserve first-seen order. Stable uniqueness deliberately
/// ignores later values with the same identity, while coalescing accepts only
/// exact retries and reports conflicting identity reuse.
enum IdentityCollection {
  static func stableUnique<Value, Identity: Hashable>(
    _ values: [Value],
    id: KeyPath<Value, Identity>
  ) -> [Value] {
    var identities = OrderedSet<Identity>()
    return values.filter { value in
      identities.append(value[keyPath: id]).inserted
    }
  }

  static func coalesce<Value: Equatable, Identity: Hashable>(
    _ values: [Value],
    id: KeyPath<Value, Identity>
  ) -> IdentityCoalescingResult<Value, Identity> {
    var valuesByIdentity: OrderedDictionary<Identity, Value> = [:]
    for value in values {
      let identity = value[keyPath: id]
      if let retained = valuesByIdentity[identity] {
        guard retained == value else { return .collision(identity: identity) }
      } else {
        valuesByIdentity[identity] = value
      }
    }
    return .coalesced(Array(valuesByIdentity.values))
  }
}
