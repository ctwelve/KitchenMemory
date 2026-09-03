// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

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
