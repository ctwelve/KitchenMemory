// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import XCTest

final class IdentityCollectionTests: XCTestCase {
  func testStableUniquenessKeepsTheFirstValueForEachIdentityInEncounterOrder() {
    let values = [
      IdentifiedValue(id: 2, payload: "first two"),
      IdentifiedValue(id: 1, payload: "one"),
      IdentifiedValue(id: 2, payload: "later two"),
    ]

    XCTAssertEqual(
      IdentityCollection.stableUnique(values, id: \.id),
      [values[0], values[1]]
    )
    XCTAssertEqual(
      IdentityCollection.stableUnique([IdentifiedValue](), id: \.id),
      []
    )
  }

  func testCoalescingAcceptsExactRetriesAndReportsConflictingIdentityReuse() {
    let first = IdentifiedValue(id: 2, payload: "two")
    let second = IdentifiedValue(id: 1, payload: "one")

    XCTAssertEqual(
      IdentityCollection.coalesce([first, second, first], id: \.id),
      .coalesced([first, second])
    )
    XCTAssertEqual(
      IdentityCollection.coalesce(
        [first, IdentifiedValue(id: 2, payload: "collision")],
        id: \.id
      ),
      .collision(identity: 2)
    )
    XCTAssertEqual(
      IdentityCollection.coalesce([IdentifiedValue](), id: \.id),
      .coalesced([])
    )
  }
}

final class CausalGraphTests: XCTestCase {
  func testEmptyAndDisconnectedGraphsHaveDeterministicMaximalNodes() {
    XCTAssertEqual(CausalGraph<Int>([]).maximalNodes, [])
    XCTAssertFalse(CausalGraph<Int>([]).containsCycle)

    let graph = CausalGraph([
      (node: 7, parents: []),
      (node: 3, parents: []),
      (node: 5, parents: []),
    ])

    XCTAssertEqual(graph.maximalNodes, [7, 3, 5])
    XCTAssertEqual(graph.reachableNodes(from: [3]), [3])
  }

  func testBranchingConvergingAndMultiParentGraphsExposeAncestryAndMaximalHeads() {
    let graph = CausalGraph([
      (node: "root", parents: []),
      (node: "left", parents: ["root"]),
      (node: "right", parents: ["root"]),
      (node: "merge", parents: ["left", "right"]),
      (node: "island", parents: []),
    ])

    XCTAssertTrue(graph.isAncestor("root", of: "merge"))
    XCTAssertFalse(graph.isAncestor("left", of: "right"))
    XCTAssertFalse(graph.isAncestor("unknown", of: "merge"))
    XCTAssertEqual(graph.maximalNodes, ["merge", "island"])
    XCTAssertEqual(
      graph.maximalNodes(among: ["root", "left", "right", "merge", "merge"]),
      ["merge"]
    )
    XCTAssertTrue(graph.formsAntichain(["left", "right", "island"]))
    XCTAssertFalse(graph.formsAntichain(["root", "merge"]))
    XCTAssertFalse(graph.containsCycle)
  }

  func testReachabilityIsOrderedDeduplicatedAndIncludesMissingDependencies() {
    let graph = CausalGraph([
      (node: "root", parents: []),
      (node: "left", parents: ["root", "root"]),
      (node: "right", parents: ["root", "missing"]),
      (node: "merge", parents: ["left", "right", "left"]),
      (node: "disconnected", parents: []),
    ])

    XCTAssertEqual(
      graph.reachableNodes(from: ["merge", "merge"]),
      ["merge", "left", "right", "root", "missing"]
    )
  }

  func testCyclesTerminateAndAreDetected() {
    let graph = CausalGraph([
      (node: "a", parents: ["b"]),
      (node: "b", parents: ["c"]),
      (node: "c", parents: ["a"]),
      (node: "self", parents: ["self"]),
    ])

    XCTAssertTrue(graph.containsCycle)
    XCTAssertTrue(graph.isAncestor("a", of: "c"))
    XCTAssertEqual(graph.reachableNodes(from: ["a"]), ["a", "b", "c"])
  }

  func testDeepAcyclicGraphUsesStackSafeTraversal() {
    let depth = 10_000
    let graph = CausalGraph((0..<depth).map { node in
      (node: node, parents: node == 0 ? [] : [node - 1])
    })

    XCTAssertFalse(graph.containsCycle)
    XCTAssertTrue(graph.isAncestor(0, of: depth - 1))
    XCTAssertEqual(graph.maximalNodes, [depth - 1])
    XCTAssertEqual(graph.reachableNodes(from: [depth - 1]).count, depth)
  }
}

private struct IdentifiedValue: Equatable {
  let id: Int
  let payload: String
}
