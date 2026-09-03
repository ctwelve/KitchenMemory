// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import DequeModule

/// Device-local FIFO for Cooking Session intentions awaiting a durable result.
///
/// The persisted boundary remains an ordinary array so the package collection
/// is an application implementation detail rather than part of the wire format.
struct CookingSessionOutbox {
  private var queue: Deque<PendingCookingSessionCommand>

  init(persistedCommands: [PendingCookingSessionCommand]) {
    queue = Deque(persistedCommands)
  }

  var commands: [PendingCookingSessionCommand] {
    Array(queue)
  }

  var head: PendingCookingSessionCommand? {
    queue.first
  }

  var isEmpty: Bool {
    queue.isEmpty
  }

  func contains(_ command: PendingCookingSessionCommand) -> Bool {
    queue.contains(command)
  }

  func allSatisfy(
    _ predicate: (PendingCookingSessionCommand) throws -> Bool
  ) rethrows -> Bool {
    try queue.allSatisfy(predicate)
  }

  mutating func replace(with command: PendingCookingSessionCommand) {
    queue = [command]
  }

  mutating func enqueue(_ command: PendingCookingSessionCommand) {
    queue.append(command)
  }

  @discardableResult
  mutating func retireHead() -> PendingCookingSessionCommand? {
    queue.popFirst()
  }
}
