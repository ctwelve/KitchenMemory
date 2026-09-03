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
/// reports conflicting identity reuse, and either preserves first-seen order or
/// emits the caller's explicit canonical order.
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
    coalescePreservingOrder(values, id: id)
  }

  static func coalesce<Value: Equatable, Identity: Hashable>(
    _ values: [Value],
    id: KeyPath<Value, Identity>,
    orderedBy areInIncreasingOrder: (Value, Value) -> Bool
  ) -> IdentityCoalescingResult<Value, Identity> {
    switch coalescePreservingOrder(values, id: id) {
    case let .coalesced(values):
      return .coalesced(values.sorted(by: areInIncreasingOrder))
    case let .collision(identity):
      return .collision(identity: identity)
    }
  }

  private static func coalescePreservingOrder<Value: Equatable, Identity: Hashable>(
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
