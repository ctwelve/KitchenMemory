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
      IdentityCollection.coalesce(
        [first, second, first],
        id: \.id,
        orderedBy: { $0.id < $1.id }
      ),
      .coalesced([second, first])
    )
    XCTAssertEqual(
      IdentityCollection.coalesce(
        [first, IdentifiedValue(id: 2, payload: "collision")],
        id: \.id,
        orderedBy: { $0.id < $1.id }
      ),
      .collision(identity: 2)
    )
    XCTAssertEqual(
      IdentityCollection.coalesce(
        [IdentifiedValue](),
        id: \.id,
        orderedBy: { $0.id < $1.id }
      ),
      .coalesced([])
    )

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
  }
}

final class CausalGraphTests: XCTestCase {
  func testEmptyAndDisconnectedGraphsHaveDeterministicMaximalNodes() {
    let empty = CausalGraph<Int>(parentsByNode: [:], orderedBy: <)
    XCTAssertEqual(empty.maximalNodes, [])
    XCTAssertFalse(empty.containsCycle)

    let graph = CausalGraph(parentsByNode: [
      7: [],
      3: [],
      5: [],
    ], orderedBy: <)

    XCTAssertEqual(graph.maximalNodes, [3, 5, 7])
    XCTAssertEqual(graph.reachableNodes(from: [3]), [3])
  }

  func testBranchingConvergingAndMultiParentGraphsExposeAncestryAndMaximalHeads() {
    let graph = CausalGraph(parentsByNode: [
      "root": [],
      "left": ["root"],
      "right": ["root"],
      "merge": ["left", "right"],
      "island": [],
    ], orderedBy: <)

    XCTAssertTrue(graph.isAncestor("root", of: "merge"))
    XCTAssertFalse(graph.isAncestor("left", of: "right"))
    XCTAssertFalse(graph.isAncestor("unknown", of: "merge"))
    XCTAssertEqual(graph.maximalNodes, ["island", "merge"])
    XCTAssertEqual(
      graph.maximalNodes(among: ["root", "left", "right", "merge", "merge"]),
      ["merge"]
    )
    XCTAssertTrue(graph.formsAntichain(["left", "right", "island"]))
    XCTAssertFalse(graph.formsAntichain(["root", "merge"]))
    XCTAssertFalse(graph.containsCycle)
  }

  func testReachabilityIsOrderedDeduplicatedAndIncludesMissingDependencies() {
    let graph = CausalGraph(parentsByNode: [
      "root": [],
      "left": ["root", "root"],
      "right": ["root", "missing"],
      "merge": ["left", "right", "left"],
      "disconnected": [],
    ], orderedBy: <)

    XCTAssertEqual(
      graph.reachableNodes(from: ["merge", "merge"]),
      ["merge", "left", "right", "root", "missing"]
    )
  }

  func testEquivalentArrivalOrdersProduceTheSameCanonicalGraphResults() {
    let first = CausalGraph(parentsByNode: [
      "root": [],
      "right": ["root"],
      "left": ["root"],
      "merge": ["right", "left"],
    ], orderedBy: <)
    let second = CausalGraph(parentsByNode: [
      "merge": ["left", "right"],
      "left": ["root"],
      "root": [],
      "right": ["root"],
    ], orderedBy: <)

    XCTAssertEqual(first.maximalNodes, second.maximalNodes)
    XCTAssertEqual(
      first.reachableNodes(from: ["merge", "right"]),
      second.reachableNodes(from: ["right", "merge"])
    )
  }

  func testReachabilityIdentifiesAllAndOnlyDependenciesRequiredForRetention() {
    let graph = CausalGraph(parentsByNode: [
      "selected": ["payload", "metadata"],
      "payload": ["source"],
      "metadata": [],
      "source": [],
      "prunable": [],
    ], orderedBy: <)

    let retained = graph.reachableNodes(from: ["selected"])

    XCTAssertEqual(retained, ["selected", "metadata", "payload", "source"])
    XCTAssertFalse(retained.contains("prunable"))
  }

  func testCyclesTerminateAndAreDetected() {
    let graph = CausalGraph(parentsByNode: [
      "a": ["b"],
      "b": ["c"],
      "c": ["a"],
      "self": ["self"],
    ], orderedBy: <)

    XCTAssertTrue(graph.containsCycle)
    XCTAssertTrue(graph.isAncestor("a", of: "c"))
    XCTAssertEqual(graph.reachableNodes(from: ["a"]), ["a", "b", "c"])
  }

  func testDeepAcyclicGraphUsesStackSafeTraversal() {
    let depth = 10_000
    let parents = Dictionary(uniqueKeysWithValues: (0..<depth).map { node in
      (node, node == 0 ? [] : [node - 1])
    })
    let graph = CausalGraph(parentsByNode: parents, orderedBy: <)

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
