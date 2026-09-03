// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

extension ProjectionBuilder {
    // Closure verification is deliberately linear so every committed digest and
    // causal boundary is checked before a Finished projection can escape.
    // swiftlint:disable:next function_body_length function_parameter_count
    func finishedProjection(
        root: CookingSessionRootEvidence,
        snapshot: ExecutionSnapshot,
        facts: [DecodedFact],
        closures: [SessionClosureEvidence],
        retainedLate: [SessionFact.ID],
        targets: [UUID: SessionProgressTarget],
        parents: [UUID: [UUID]]
    ) -> SessionProjectionResult {
        let headsByClosure: [SessionClosure.ID: [UUID]]
        switch validatedClosureHeads(
            root: root,
            facts: facts,
            closures: closures,
            parents: parents
        ) {
        case let .failure(result): return result
        case let .success(values): headsByClosure = values
        }
        let projectionsByClosure: [SessionClosure.ID: CookingSessionProjection]
        switch validatedClosedProjections(
            snapshot: snapshot,
            facts: facts,
            closures: closures,
            headsByClosure: headsByClosure,
            targets: targets,
            parents: parents
        ) {
        case let .failure(result): return result
        case let .success(values): projectionsByClosure = values
        }
        guard let closure = selectedClosure(from: closures, facts: facts) else {
            return recovery(.competingClosures)
        }
        // Every retained Closure was inserted by validatedClosureHeads.
        // swiftlint:disable:next force_unwrapping
        let heads = headsByClosure[closure.id]!

        let included = facts.filter { fact in
            heads.contains(fact.evidence.id.rawValue) || heads.contains {
                isAncestor(fact.evidence.id.rawValue, of: $0, parents: parents)
            }
        }
        // Every retained Closure was inserted by validatedClosedProjections.
        // swiftlint:disable:next force_unwrapping
        let closed = projectionsByClosure[closure.id]!

        let includedIDs = Set(included.map(\.evidence.id))
        var lateEvidence = facts.filter { $0.kind != .conflictResolution }.map(\.evidence.id)
            .filter { !includedIDs.contains($0) }
        lateEvidence += retainedLate
        lateEvidence.sort { uuidOrder($0.rawValue, $1.rawValue) }
        return .session(
            CookingSessionProjection(
                id: evidence.sessionID,
                snapshot: closed.snapshot,
                sourceSessionID: root.sourceSessionID,
                sourceClosureID: root.sourceClosureID,
                lifecycle: .finished,
                lifecycleBeforeFinish: closed.lifecycle,
                progress: closed.progress,
                workingScale: closed.workingScale,
                entries: closed.entries,
                outcome: closed.outcome,
                conflicts: [],
                selectedClosureID: closure.id,
                lateEvidence: lateEvidence
            )
        )
    }

    // swiftlint:disable:next function_body_length
    private func validatedClosureHeads(
        root: CookingSessionRootEvidence,
        facts: [DecodedFact],
        closures: [SessionClosureEvidence],
        parents: [UUID: [UUID]]
    ) -> ClosureHeadsResult {
        let knownIDs = Set(facts.map(\.evidence.id.rawValue)).union([root.id.rawValue])
        var graph = parents
        var values: [SessionClosure.ID: [UUID]] = [:]
        for closure in closures {
            guard closure.kitchenID == root.kitchenID else {
                return .failure(recovery(.crossSessionReference))
            }
            guard closure.snapshotFormatVersion == root.snapshotFormatVersion,
                  closure.snapshotDigest == root.snapshotDigest
            else { return .failure(recovery(.inconsistentClosure)) }
            guard closure.causalHeadsFormatVersion == CausalHeadsCodec.formatVersion else {
                return .failure(
                    unavailable(.unsupportedCausalHeadsFormat(closure.causalHeadsFormatVersion))
                )
            }
            let heads: [UUID]
            do {
                heads = try CausalHeadsCodec.decode(
                    formatVersion: closure.causalHeadsFormatVersion,
                    data: closure.causalHeadsData
                )
            } catch {
                return .failure(recovery(.malformedCausalHeads))
            }
            if let missing = heads.first(where: { !knownIDs.contains($0) }) {
                return .failure(unavailable(.missingPredecessor(missing)))
            }
            guard !heads.isEmpty else {
                return .failure(recovery(.inconsistentClosure))
            }
            values[closure.id] = heads
            graph[closure.id.rawValue] = heads
        }
        let closureGraph = causalGraph(graph)
        guard !closureGraph.containsCycle else {
            return .failure(recovery(.cycle))
        }
        guard values.values.allSatisfy(closureGraph.formsAntichain) else {
            return .failure(recovery(.inconsistentClosure))
        }
        let resolutionIDs = facts.filter { $0.kind == .conflictResolution }
            .map(\.evidence.id.rawValue)
        guard values.values.allSatisfy({ heads in
            heads.allSatisfy { head in
                !resolutionIDs.contains(head)
                    && !resolutionIDs.contains {
                        closureGraph.isAncestor($0, of: head)
                    }
            }
        }) else {
            return .failure(recovery(.inconsistentClosure))
        }
        return .success(values)
    }

    // Validate every retained Closure, not merely the selected winner. A losing
    // Closure is still durable evidence and corruption cannot be hidden by a
    // later resolution Fact.
    // swiftlint:disable:next function_parameter_count
    private func validatedClosedProjections(
        snapshot: ExecutionSnapshot,
        facts: [DecodedFact],
        closures: [SessionClosureEvidence],
        headsByClosure: [SessionClosure.ID: [UUID]],
        targets: [UUID: SessionProgressTarget],
        parents: [UUID: [UUID]]
    ) -> ClosedProjectionsResult {
        var values: [SessionClosure.ID: CookingSessionProjection] = [:]
        for closure in closures {
            // Every retained Closure was inserted by validatedClosureHeads.
            // swiftlint:disable:next force_unwrapping
            let heads = headsByClosure[closure.id]!
            let included = facts.filter { fact in
                heads.contains(fact.evidence.id.rawValue) || heads.contains {
                    isAncestor(fact.evidence.id.rawValue, of: $0, parents: parents)
                }
            }
            let closed = makeProjection(
                snapshot: snapshot,
                facts: included,
                targets: targets,
                parents: parents
            )
            guard closed.conflicts.isEmpty else {
                return .failure(recovery(.inconsistentClosure))
            }
            guard closure.projectionFormatVersion == ClosedSessionProjectionCodec.formatVersion else {
                return .failure(
                    unavailable(.unsupportedProjectionFormat(closure.projectionFormatVersion))
                )
            }
            // ClosedSessionProjection contains only total, synthesized Codable values;
            // failure here is a programmer invariant violation, not retained evidence.
            // swiftlint:disable:next force_try
            let encoded = try! ClosedSessionProjectionCodec.encode(ClosedSessionProjection(closed))
            guard encoded.digest == closure.projectionDigest else {
                return .failure(recovery(.inconsistentClosure))
            }
            switch closureOutcome(closure) {
            case let .failure(result):
                return .failure(result)
            case let .success(outcome):
                guard outcome == closed.outcome else {
                    return .failure(recovery(.inconsistentClosure))
                }
            }
            values[closure.id] = closed
        }
        return .success(values)
    }

    private func selectedClosure(
        from closures: [SessionClosureEvidence],
        facts: [DecodedFact]
    ) -> SessionClosureEvidence? {
        if closures.count == 1 { return closures[0] }
        let selections = facts.compactMap { fact -> SessionClosure.ID? in
            guard fact.kind == .conflictResolution,
                  case let .closureResolution(selection) = fact.payload,
                  Set(selection.observedClosureIDs.map(\.rawValue))
                    == Set(closures.map(\.id.rawValue))
            else { return nil }
            return selection.selectedClosureID
        }
        guard selections.count == 1 else { return nil }
        return closures.first { $0.id == selections[0] }
    }

    private func closureOutcome(
        _ closure: SessionClosureEvidence
    ) -> ClosureOutcomeResult {
        switch (closure.outcomeFormatVersion, closure.outcomeData) {
        case (nil, nil):
            return .success(nil)
        case let (version?, data?):
            guard version == SessionOutcomeCodec.formatVersion else {
                return .failure(unavailable(.unsupportedOutcomeFormat(version)))
            }
            do {
                return .success(try SessionOutcomeCodec.decode(formatVersion: version, data: data))
            } catch {
                return .failure(recovery(.inconsistentClosure))
            }
        default:
            return .failure(recovery(.inconsistentClosure))
        }
    }
}

private enum ClosureOutcomeResult {
    case success(SessionOutcome?)
    case failure(SessionProjectionResult)
}

private enum ClosureHeadsResult {
    case success([SessionClosure.ID: [UUID]])
    case failure(SessionProjectionResult)
}

private enum ClosedProjectionsResult {
    case success([SessionClosure.ID: CookingSessionProjection])
    case failure(SessionProjectionResult)
}
