// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation

func coalescedByIdentity<Value: Equatable, Identifier: Hashable>(
    _ values: [Value],
    id: KeyPath<Value, Identifier>
) -> [Value]? {
    let groups = Dictionary(grouping: values) { $0[keyPath: id] }
    guard groups.values.allSatisfy({ group in
        guard let first = group.first else { return true }
        return group.allSatisfy { $0 == first }
    }) else { return nil }
    return groups.values.compactMap(\.first)
}

func directedGraphContainsCycle(_ parents: [UUID: [UUID]]) -> Bool {
    var visiting: Set<UUID> = []
    var visited: Set<UUID> = []
    func visit(_ identifier: UUID) -> Bool {
        if visiting.contains(identifier) { return true }
        if visited.contains(identifier) { return false }
        visiting.insert(identifier)
        // `visit` starts at a key and recurses only into parents that are keys.
        // swiftlint:disable:next force_unwrapping
        for parent in parents[identifier]! {
            if parents[parent] != nil, visit(parent) { return true }
        }
        visiting.remove(identifier)
        visited.insert(identifier)
        return false
    }
    return parents.keys.contains(where: visit)
}

func directedGraphIsAncestor(
    _ ancestor: UUID,
    of descendant: UUID,
    parents: [UUID: [UUID]]
) -> Bool {
    if parents[descendant]?.contains(ancestor) == true { return true }
    return parents[descendant]?.contains {
        directedGraphIsAncestor(ancestor, of: $0, parents: parents)
    } ?? false
}

func directedGraphHeadsAreMaximal(
    _ heads: [UUID],
    parents: [UUID: [UUID]]
) -> Bool {
    heads.allSatisfy { candidate in
        !heads.contains { other in
            candidate != other
                && directedGraphIsAncestor(candidate, of: other, parents: parents)
        }
    }
}

extension ProjectionBuilder {
    func maximalFacts(
        _ facts: [DecodedFact],
        parents: [UUID: [UUID]]
    ) -> [DecodedFact] {
        facts.filter { candidate in
            !facts.contains { other in
                candidate.evidence.id != other.evidence.id
                    && isAncestor(
                        candidate.evidence.id.rawValue,
                        of: other.evidence.id.rawValue,
                        parents: parents
                    )
            }
        }
    }

    func isAncestor(_ ancestor: UUID, of descendant: UUID, parents: [UUID: [UUID]]) -> Bool {
        directedGraphIsAncestor(ancestor, of: descendant, parents: parents)
    }

    func snapshotTargets(_ snapshot: ExecutionSnapshot) -> [UUID: SessionProgressTarget] {
        let pairs = snapshot.ingredientSections.flatMap(\.ingredients).map {
            ($0.id.rawValue, SessionProgressTarget.ingredient($0.id))
        } + snapshot.instructionSections.flatMap(\.steps).map {
            ($0.id.rawValue, SessionProgressTarget.instruction($0.id))
        }
        return Dictionary(pairs, uniquingKeysWith: { first, _ in first })
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
