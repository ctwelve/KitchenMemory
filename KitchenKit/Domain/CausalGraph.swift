// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import DequeModule
import OrderedCollections

/// Iterative traversal mechanics shared by Kitchen Memory evidence families.
///
/// Nodes and parent lists retain their supplied order. Graph policy—whether a
/// missing dependency, cycle, or competing head is valid—belongs to the Domain
/// caller rather than this module.
struct CausalGraph<Node: Hashable> {
  private let parentsByNode: OrderedDictionary<Node, [Node]>

  init(_ parentLists: [(node: Node, parents: [Node])]) {
    var orderedParents: OrderedDictionary<Node, [Node]> = [:]
    for parentList in parentLists where orderedParents[parentList.node] == nil {
      orderedParents[parentList.node] = parentList.parents
    }
    parentsByNode = orderedParents
  }

  var containsCycle: Bool {
    var visiting = Set<Node>()
    var visited = Set<Node>()

    for node in parentsByNode.keys where !visited.contains(node) {
      var workQueue: Deque<CausalGraphVisit<Node>> = [.enter(node)]
      while let visit = workQueue.popLast() {
        switch visit {
        case let .enter(candidate):
          if visited.contains(candidate) { continue }
          _ = visiting.insert(candidate)
          workQueue.append(.exit(candidate))
          for parent in (parentsByNode[candidate] ?? []).reversed()
          where parentsByNode[parent] != nil {
            if visiting.contains(parent) { return true }
            if !visited.contains(parent) { workQueue.append(.enter(parent)) }
          }
        case let .exit(candidate):
          visiting.remove(candidate)
          visited.insert(candidate)
        }
      }
    }
    return false
  }

  func isAncestor(_ ancestor: Node, of descendant: Node) -> Bool {
    var visited: Set<Node> = [descendant]
    var workQueue = Deque(parentsByNode[descendant] ?? [])
    while let candidate = workQueue.popFirst() {
      if candidate == ancestor { return true }
      guard visited.insert(candidate).inserted else { continue }
      workQueue.append(contentsOf: parentsByNode[candidate] ?? [])
    }
    return false
  }

  func formsAntichain(_ nodes: [Node]) -> Bool {
    nodes.allSatisfy { candidate in
      !nodes.contains { other in
        candidate != other && isAncestor(candidate, of: other)
      }
    }
  }

  func maximalNodes(among candidates: [Node]) -> [Node] {
    IdentityCollection.stableUnique(candidates, id: \.self).filter { candidate in
      !candidates.contains { other in
        candidate != other && isAncestor(candidate, of: other)
      }
    }
  }

  var maximalNodes: [Node] {
    let nonmaximalNodes = Set(parentsByNode.values.joined())
    return parentsByNode.keys.filter { !nonmaximalNodes.contains($0) }
  }

  /// Returns starting nodes and their transitive parents in first-reached order.
  /// Referenced parents without a retained node are included but not expanded.
  func reachableNodes(from startingNodes: [Node]) -> [Node] {
    var reached = OrderedSet<Node>()
    var workQueue = Deque(startingNodes)
    while let candidate = workQueue.popFirst() {
      guard reached.append(candidate).inserted else { continue }
      workQueue.append(contentsOf: parentsByNode[candidate] ?? [])
    }
    return Array(reached)
  }
}

private enum CausalGraphVisit<Node> {
  case enter(Node)
  case exit(Node)
}
