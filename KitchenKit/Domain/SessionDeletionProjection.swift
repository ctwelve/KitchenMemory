// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

extension ProjectionBuilder {
    func applyDisposition(to result: SessionProjectionResult) -> SessionProjectionResult {
        guard case let .session(session) = result else { return result }
        switch dispositionContext() {
        case let .failure(result):
            return result
        case .none:
            return result
        case let .success(context):
            return apply(context: context, to: session)
        }
    }

    private func dispositionContext() -> DispositionContextResult {
        guard evidence.deletions.allSatisfy({ $0.sessionID == evidence.sessionID }),
              evidence.restorations.allSatisfy({ $0.sessionID == evidence.sessionID })
        else {
            return .failure(recovery(.crossSessionReference))
        }
        guard let deletions = coalescedByIdentity(evidence.deletions, id: \.id) else {
            return .failure(recovery(.deletionCollision))
        }
        guard let restorations = coalescedByIdentity(evidence.restorations, id: \.id) else {
            return .failure(recovery(.restorationCollision))
        }
        guard !deletions.isEmpty || !restorations.isEmpty else { return .none }
        guard let kitchenID = evidence.roots.first?.kitchenID,
              deletions.allSatisfy({ $0.kitchenID == kitchenID }),
              restorations.allSatisfy({ $0.kitchenID == kitchenID })
        else {
            return .failure(recovery(.crossSessionReference))
        }
        switch dispositionParents(deletions: deletions, restorations: restorations) {
        case let .failure(result):
            return .failure(result)
        case let .success(parents):
            return validateDisposition(
                deletions: deletions,
                restorations: restorations,
                parents: parents
            )
        }
    }

    private func dispositionParents(
        deletions: [SessionDeletionEvidence],
        restorations: [SessionDeletionResolutionEvidence]
    ) -> DispositionParentsResult {
        let knownSessionIDs = Set(
            evidence.roots.map(\.id.rawValue)
                + evidence.facts.map(\.id.rawValue)
                + evidence.closures.map(\.id.rawValue)
        )
        let sessionParents = validatedSessionParents()
        var parents: [UUID: [UUID]] = [:]
        for deletion in deletions {
            let sessionHeads: [UUID]
            switch decodeHeads(
                version: deletion.sessionHeadsFormatVersion,
                data: deletion.sessionHeadsData
            ) {
            case let .failure(result): return .failure(result)
            case let .success(heads): sessionHeads = heads
            }
            if let missing = sessionHeads.first(where: { !knownSessionIDs.contains($0) }) {
                return .failure(unavailable(.incompleteDeletionDisposition(missing)))
            }
            guard directedGraphHeadsAreMaximal(sessionHeads, parents: sessionParents) else {
                return .failure(recovery(.invalidDeletionDisposition))
            }
            switch decodeHeads(
                version: deletion.dispositionHeadsFormatVersion,
                data: deletion.dispositionHeadsData
            ) {
            case let .failure(result): return .failure(result)
            case let .success(heads): parents[deletion.id.rawValue] = heads
            }
        }
        for restoration in restorations {
            switch decodeHeads(
                version: restoration.dispositionHeadsFormatVersion,
                data: restoration.dispositionHeadsData
            ) {
            case let .failure(result): return .failure(result)
            case let .success(heads): parents[restoration.id.rawValue] = heads
            }
        }
        return .success(parents)
    }

    // This is reached only after the Session projection validated all causal
    // data. Re-decoding constructs the complete graph used to audit a deletion's
    // claimed observed Session frontier.
    private func validatedSessionParents() -> [UUID: [UUID]] {
        var parents = Dictionary(evidence.facts.map { fact in
            // swiftlint:disable:next force_try
            (fact.id.rawValue, try! CausalHeadsCodec.decode(
                formatVersion: fact.causalHeadsFormatVersion,
                data: fact.causalHeadsData
            ))
        }, uniquingKeysWith: { first, _ in first })
        for closure in evidence.closures {
            // swiftlint:disable:next force_try
            parents[closure.id.rawValue] = try! CausalHeadsCodec.decode(
                formatVersion: closure.causalHeadsFormatVersion,
                data: closure.causalHeadsData
            )
        }
        for root in evidence.roots {
            parents[root.id.rawValue] = []
        }
        return parents
    }

    private func validateDisposition(
        deletions: [SessionDeletionEvidence],
        restorations: [SessionDeletionResolutionEvidence],
        parents: [UUID: [UUID]]
    ) -> DispositionContextResult {
        let knownIDs = Set(parents.keys)
        if let missing = parents.values.joined().first(where: { !knownIDs.contains($0) }) {
            return .failure(unavailable(.incompleteDeletionDisposition(missing)))
        }
        guard !directedGraphContainsCycle(parents) else {
            return .failure(recovery(.invalidDeletionDisposition))
        }
        guard parents.values.allSatisfy({
            directedGraphHeadsAreMaximal($0, parents: parents)
        }) else {
            return .failure(recovery(.invalidDeletionDisposition))
        }
        let deletionsByID = Dictionary(uniqueKeysWithValues: deletions.map { ($0.id, $0) })
        let restorationsAreCausal = restorations.allSatisfy { restoration in
            guard let deletion = deletionsByID[restoration.deletionID] else { return false }
            return directedGraphIsAncestor(
                deletion.id.rawValue,
                of: restoration.id.rawValue,
                parents: parents
            )
        }
        guard restorationsAreCausal else {
            return .failure(recovery(.invalidDeletionDisposition))
        }
        return .success(
            DispositionContext(
                deletions: deletions,
                restorations: restorations,
                parents: parents
            )
        )
    }

    private func apply(
        context: DispositionContext,
        to session: CookingSessionProjection
    ) -> SessionProjectionResult {
        let resolved = Set(context.restorations.map(\.deletionID))
        let unresolved = context.deletions.filter { !resolved.contains($0.id) }
        guard !unresolved.isEmpty else {
            return .session(session.withDisposition(.ordinary))
        }
        let needsAttention = context.restorations.contains { restoration in
            unresolved.contains { deletion in
                !directedGraphIsAncestor(
                    restoration.id.rawValue,
                    of: deletion.id.rawValue,
                    parents: context.parents
                )
            }
        }
        return .session(session.withDisposition(.deleted(needsAttention: needsAttention)))
    }

    private func decodeHeads(version: Int, data: Data) -> DispositionHeadsResult {
        guard version == CausalHeadsCodec.formatVersion else {
            return .failure(unavailable(.unsupportedCausalHeadsFormat(version)))
        }
        do {
            return .success(try CausalHeadsCodec.decode(formatVersion: version, data: data))
        } catch {
            return .failure(recovery(.invalidDeletionDisposition))
        }
    }

}

private struct DispositionContext {
    let deletions: [SessionDeletionEvidence]
    let restorations: [SessionDeletionResolutionEvidence]
    let parents: [UUID: [UUID]]
}

private enum DispositionContextResult {
    case none
    case success(DispositionContext)
    case failure(SessionProjectionResult)
}

private enum DispositionParentsResult {
    case success([UUID: [UUID]])
    case failure(SessionProjectionResult)
}

private enum DispositionHeadsResult {
    case success([UUID])
    case failure(SessionProjectionResult)
}

private extension CookingSessionProjection {
    func withDisposition(_ disposition: SessionDisposition) -> Self {
        Self(
            id: id,
            snapshot: snapshot,
            sourceSessionID: sourceSessionID,
            sourceClosureID: sourceClosureID,
            lifecycle: lifecycle,
            lifecycleBeforeFinish: lifecycleBeforeFinish,
            disposition: disposition,
            progress: progress,
            workingScale: workingScale,
            entries: entries,
            outcome: outcome,
            conflicts: conflicts,
            selectedClosureID: selectedClosureID,
            lateEvidence: lateEvidence
        )
    }
}
