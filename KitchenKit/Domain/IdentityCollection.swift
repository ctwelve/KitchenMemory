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
/// Stable uniqueness preserves first-seen order and deliberately ignores later
/// values with the same identity. Coalescing accepts only exact retries,
/// reports conflicting identity reuse, and emits the caller's canonical order.
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
    id: KeyPath<Value, Identity>,
    orderedBy areInIncreasingOrder: (Value, Value) -> Bool
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
    return .coalesced(valuesByIdentity.values.sorted(by: areInIncreasingOrder))
  }
}
