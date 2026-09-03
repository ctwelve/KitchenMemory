// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import DequeModule
import Foundation
import OrderedCollections

func coalescedByIdentity<Value: Equatable, Identifier: Hashable>(
    _ values: [Value],
    id: KeyPath<Value, Identifier>
) -> [Value]? {
    var coalesced: OrderedDictionary<Identifier, Value> = [:]
    for value in values {
        let identifier = value[keyPath: id]
        if let first = coalesced[identifier], first != value { return nil }
        coalesced[identifier] = value
    }
    return Array(coalesced.values)
}

struct DirectedGraph<Node: Hashable> {
    let parentsByNode: [Node: [Node]]

    var containsCycle: Bool {
        var visiting: Set<Node> = []
        var visited: Set<Node> = []

        for node in parentsByNode.keys where !visited.contains(node) {
            var worklist: Deque<DirectedGraphVisit<Node>> = [.enter(node)]
            while let visit = worklist.popLast() {
                switch visit {
                case let .enter(candidate):
                    if visited.contains(candidate) { continue }
                    _ = visiting.insert(candidate)
                    worklist.append(.exit(candidate))
                    // The worklist starts with a key and admits only parents that are keys.
                    // swiftlint:disable:next force_unwrapping
                    for parent in parentsByNode[candidate]!
                    where parentsByNode[parent] != nil {
                        if visiting.contains(parent) { return true }
                        if !visited.contains(parent) { worklist.append(.enter(parent)) }
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
        var worklist = Deque(parentsByNode[descendant] ?? [])
        while let candidate = worklist.popFirst() {
            if candidate == ancestor { return true }
            guard visited.insert(candidate).inserted else { continue }
            worklist.append(contentsOf: parentsByNode[candidate] ?? [])
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
        candidates.filter { candidate in
            !candidates.contains { other in
                candidate != other && isAncestor(candidate, of: other)
            }
        }
    }

    var maximalNodes: [Node] {
        let nonmaximalNodes = Set(parentsByNode.values.joined())
        return parentsByNode.keys.filter { !nonmaximalNodes.contains($0) }
    }
}

private enum DirectedGraphVisit<Node> {
    case enter(Node)
    case exit(Node)
}

extension ProjectionBuilder {
    func maximalFacts(
        _ facts: [DecodedFact],
        parents: [UUID: [UUID]]
    ) -> [DecodedFact] {
        let graph = causalGraph(parents)
        let maximalIDs = Set(graph.maximalNodes(among: facts.map(\.evidence.id.rawValue)))
        return facts.filter {
            maximalIDs.contains($0.evidence.id.rawValue)
        }
    }

    func isAncestor(_ ancestor: UUID, of descendant: UUID, parents: [UUID: [UUID]]) -> Bool {
        causalGraph(parents).isAncestor(ancestor, of: descendant)
    }

    func causalGraph(_ parents: [UUID: [UUID]]) -> CausalGraph<UUID> {
        CausalGraph(parentsByNode: parents, orderedBy: uuidOrder)
    }

    func snapshotTargets(_ snapshot: ExecutionSnapshot) -> [UUID: SessionProgressTarget] {
        let ingredients: [(UUID, SessionProgressTarget)] = snapshot.ingredientSections
            .flatMap(\.ingredients).map {
            ($0.id.rawValue, SessionProgressTarget.ingredient($0.id))
        }
        let instructions: [(UUID, SessionProgressTarget)] = snapshot.instructionSections
            .flatMap(\.steps).map {
            ($0.id.rawValue, SessionProgressTarget.instruction($0.id))
        }
        return Dictionary(ingredients + instructions, uniquingKeysWith: { first, _ in first })
    }

    func snapshotTargetCount(_ snapshot: ExecutionSnapshot) -> Int {
        snapshot.ingredientSections.flatMap(\.ingredients).count
            + snapshot.instructionSections.flatMap(\.steps).count
    }

    func unavailable(_ reason: UnavailableSession.Reason) -> SessionProjectionResult {
        .unavailable(UnavailableSession(evidence: evidence, reasons: [reason]))
    }

    func recovery(_ reason: SessionRecovery.Reason) -> SessionProjectionResult {
        .recovery(SessionRecovery(evidence: evidence, reasons: [reason]))
    }

    func factOrder(_ lhs: SessionFactEvidence, _ rhs: SessionFactEvidence) -> Bool {
        uuidOrder(lhs.id.rawValue, rhs.id.rawValue)
    }

    func decodedFactOrder(_ lhs: DecodedFact, _ rhs: DecodedFact) -> Bool {
        factOrder(lhs.evidence, rhs.evidence)
    }

    func uuidOrder(_ lhs: UUID, _ rhs: UUID) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}
