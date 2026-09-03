// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import DequeModule
import OrderedCollections

/// Iterative traversal mechanics shared by Kitchen Memory evidence families.
///
/// Construction canonicalizes nodes and parent lists using the caller's stable
/// total order. Graph policy—whether a missing dependency, cycle, or competing
/// head is valid—belongs to the Domain caller rather than this module.
enum CausalGraphConstructionResult<Node: Hashable> {
  case graph(CausalGraph<Node>)
  case collision(node: Node)
}

struct CausalGraph<Node: Hashable> {
  private let parentsByNode: OrderedDictionary<Node, [Node]>
  private let areInIncreasingOrder: (Node, Node) -> Bool

  private init(
    parentsByNode: OrderedDictionary<Node, [Node]>,
    orderedBy areInIncreasingOrder: @escaping (Node, Node) -> Bool
  ) {
    self.parentsByNode = parentsByNode
    self.areInIncreasingOrder = areInIncreasingOrder
  }

  static func coalescing(
    _ parentLists: [(node: Node, parents: [Node])],
    orderedBy areInIncreasingOrder: @escaping (Node, Node) -> Bool
  ) -> CausalGraphConstructionResult<Node> {
    var orderedParents: OrderedDictionary<Node, [Node]> = [:]
    for parentList in parentLists.sorted(by: {
      areInIncreasingOrder($0.node, $1.node)
    }) {
      let canonicalParents = IdentityCollection.stableUnique(
        parentList.parents.sorted(by: areInIncreasingOrder),
        id: \.self
      )
      if let retainedParents = orderedParents[parentList.node] {
        guard retainedParents == canonicalParents else {
          return .collision(node: parentList.node)
        }
      } else {
        orderedParents[parentList.node] = canonicalParents
      }
    }
    return .graph(CausalGraph(
      parentsByNode: orderedParents,
      orderedBy: areInIncreasingOrder
    ))
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
      isMaximal(candidate, among: nodes)
    }
  }

  func maximalNodes(among candidates: [Node]) -> [Node] {
    let canonicalCandidates = IdentityCollection.stableUnique(
      candidates.sorted(by: areInIncreasingOrder),
      id: \.self
    )
    return canonicalCandidates.filter { isMaximal($0, among: canonicalCandidates) }
  }

  var maximalNodes: [Node] {
    let nonmaximalNodes = Set(parentsByNode.values.joined())
    return parentsByNode.keys.filter { !nonmaximalNodes.contains($0) }
  }

  /// Returns starting nodes and their transitive parents in first-reached order.
  /// Referenced parents without a retained node are included but not expanded.
  func reachableNodes(from startingNodes: [Node]) -> [Node] {
    var reached = OrderedSet<Node>()
    let canonicalStartingNodes = IdentityCollection.stableUnique(
      startingNodes.sorted(by: areInIncreasingOrder),
      id: \.self
    )
    var workQueue = Deque(canonicalStartingNodes)
    while let candidate = workQueue.popFirst() {
      guard reached.append(candidate).inserted else { continue }
      workQueue.append(contentsOf: parentsByNode[candidate] ?? [])
    }
    return Array(reached)
  }

  private func isMaximal(_ candidate: Node, among nodes: [Node]) -> Bool {
    !nodes.contains { other in
      candidate != other && isAncestor(candidate, of: other)
    }
  }
}

private enum CausalGraphVisit<Node> {
  case enter(Node)
  case exit(Node)
}
