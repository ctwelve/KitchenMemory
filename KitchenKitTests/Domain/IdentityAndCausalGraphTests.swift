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
  }
}

final class CausalGraphTests: XCTestCase {
  func testEmptyAndDisconnectedGraphsHaveDeterministicMaximalNodes() {
    let empty = graph([(node: Int, parents: [Int])](), orderedBy: <)
    XCTAssertEqual(empty.maximalNodes, [])
    XCTAssertFalse(empty.containsCycle)

    let graph = graph([
      (node: 7, parents: []),
      (node: 3, parents: []),
      (node: 5, parents: []),
    ], orderedBy: <)

    XCTAssertEqual(graph.maximalNodes, [3, 5, 7])
    XCTAssertEqual(graph.reachableNodes(from: [3]), [3])
  }

  func testBranchingConvergingAndMultiParentGraphsExposeAncestryAndMaximalHeads() {
    let graph = graph([
      (node: "root", parents: []),
      (node: "left", parents: ["root"]),
      (node: "right", parents: ["root"]),
      (node: "merge", parents: ["left", "right"]),
      (node: "island", parents: []),
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
    let graph = graph([
      (node: "root", parents: []),
      (node: "left", parents: ["root", "root"]),
      (node: "right", parents: ["root", "missing"]),
      (node: "merge", parents: ["left", "right", "left"]),
      (node: "disconnected", parents: []),
    ], orderedBy: <)

    XCTAssertEqual(
      graph.reachableNodes(from: ["merge", "merge"]),
      ["merge", "left", "right", "root", "missing"]
    )
  }

  func testEquivalentArrivalOrdersProduceTheSameCanonicalGraphResults() {
    let first = graph([
      (node: "root", parents: []),
      (node: "right", parents: ["root"]),
      (node: "left", parents: ["root"]),
      (node: "merge", parents: ["right", "left"]),
    ], orderedBy: <)
    let second = graph([
      (node: "merge", parents: ["left", "right"]),
      (node: "left", parents: ["root"]),
      (node: "root", parents: []),
      (node: "right", parents: ["root"]),
    ], orderedBy: <)

    XCTAssertEqual(first.maximalNodes, second.maximalNodes)
    XCTAssertEqual(
      first.reachableNodes(from: ["merge", "right"]),
      second.reachableNodes(from: ["right", "merge"])
    )
  }

  func testGraphConstructionCoalescesExactDefinitionsAndReportsCollisions() {
    let exact = graph([
      (node: "merge", parents: ["right", "left", "right"]),
      (node: "merge", parents: ["left", "right"]),
      (node: "left", parents: []),
      (node: "right", parents: []),
    ], orderedBy: <)
    XCTAssertEqual(exact.reachableNodes(from: ["merge"]), ["merge", "left", "right"])

    switch CausalGraph.coalescing([
      (node: "merge", parents: ["left"]),
      (node: "merge", parents: ["right"]),
    ], orderedBy: <) {
    case .graph:
      XCTFail("Expected conflicting parent definitions to remain visible")
    case let .collision(node):
      XCTAssertEqual(node, "merge")
    }
  }

  func testReachabilityIdentifiesAllAndOnlyDependenciesRequiredForRetention() {
    let graph = graph([
      (node: "selected", parents: ["payload", "metadata"]),
      (node: "payload", parents: ["source"]),
      (node: "metadata", parents: []),
      (node: "source", parents: []),
      (node: "prunable", parents: []),
    ], orderedBy: <)

    let retained = graph.reachableNodes(from: ["selected"])

    XCTAssertEqual(retained, ["selected", "metadata", "payload", "source"])
    XCTAssertFalse(retained.contains("prunable"))
  }

  func testCyclesTerminateAndAreDetected() {
    let graph = graph([
      (node: "a", parents: ["b"]),
      (node: "b", parents: ["c"]),
      (node: "c", parents: ["a"]),
      (node: "self", parents: ["self"]),
    ], orderedBy: <)

    XCTAssertTrue(graph.containsCycle)
    XCTAssertTrue(graph.isAncestor("a", of: "c"))
    XCTAssertEqual(graph.reachableNodes(from: ["a"]), ["a", "b", "c"])
  }

  func testDeepAcyclicGraphUsesStackSafeTraversal() {
    let depth = 10_000
    let graph = graph((0..<depth).map { node in
      (node: node, parents: node == 0 ? [] : [node - 1])
    }, orderedBy: <)

    XCTAssertFalse(graph.containsCycle)
    XCTAssertTrue(graph.isAncestor(0, of: depth - 1))
    XCTAssertEqual(graph.maximalNodes, [depth - 1])
    XCTAssertEqual(graph.reachableNodes(from: [depth - 1]).count, depth)
  }

  private func graph<Node: Hashable>(
    _ parentLists: [(node: Node, parents: [Node])],
    orderedBy order: @escaping (Node, Node) -> Bool,
    file: StaticString = #filePath,
    line: UInt = #line
  ) -> CausalGraph<Node> {
    switch CausalGraph.coalescing(parentLists, orderedBy: order) {
    case let .graph(graph):
      return graph
    case let .collision(node):
      XCTFail("Unexpected conflicting definitions for \(node)", file: file, line: line)
      fatalError("A failed graph construction cannot supply a test value")
    }
  }
}

private struct IdentifiedValue: Equatable {
  let id: Int
  let payload: String
}
