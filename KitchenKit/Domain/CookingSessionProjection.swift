// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Reconstructs one complete Session from retained, unordered evidence.
public enum SessionEvidenceProjector {
    public static func project(_ evidence: SessionEvidence) -> SessionProjectionResult {
        let builder = ProjectionBuilder(evidence: evidence)
        return builder.applyDisposition(to: builder.build())
    }
}

struct DecodedFact {
    let evidence: SessionFactEvidence
    let kind: SessionFact.Kind
    let heads: [UUID]
    let payload: SessionFactPayload
}

private enum FactDecodeResult {
    case success(
        facts: [DecodedFact],
        retainedLate: [SessionFact.ID],
        parents: [UUID: [UUID]]
    )
    case failure(SessionProjectionResult)
}

// The builder keeps every reconstruction stage on one evidence value so helper
// files can share validation state without exposing an application-facing API.
// swiftlint:disable file_length type_body_length
struct ProjectionBuilder {
    let evidence: SessionEvidence

    // Keep the classification gates in contract order: changing their order can
    // turn the same retained bytes from Unavailable into Recovery or vice versa.
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func build() -> SessionProjectionResult {
        guard let root = evidence.roots.first else {
            return unavailable(.missingRoot)
        }
        guard evidence.roots.allSatisfy({ $0.id == evidence.sessionID }),
              evidence.facts.allSatisfy({ $0.sessionID == evidence.sessionID }),
              evidence.closures.allSatisfy({ $0.sessionID == evidence.sessionID })
        else {
            return recovery(.crossSessionReference)
        }
        guard evidence.roots.allSatisfy({ $0 == root }) else {
            return recovery(.rootCollision)
        }
        guard let facts = coalescedFacts() else {
            return recovery(.factCollision)
        }
        guard let closures = coalescedClosures() else {
            return recovery(.closureCollision)
        }
        guard root.snapshotFormatVersion == ExecutionSnapshotCodec.formatVersion else {
            return unavailable(.unsupportedSnapshotFormat(root.snapshotFormatVersion))
        }
        guard SessionDigest.sha256(root.snapshotData) == root.snapshotDigest else {
            return recovery(.digestMismatch)
        }

        let snapshot: ExecutionSnapshot
        do {
            snapshot = try ExecutionSnapshotCodec.decode(
                formatVersion: root.snapshotFormatVersion,
                data: root.snapshotData
            )
        } catch {
            return recovery(.malformedSnapshot)
        }
        guard !snapshot.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return recovery(.malformedSnapshot)
        }
        guard validContinuation(root: root, snapshot: snapshot) else {
            return recovery(.invalidContinuation)
        }
        let targets = snapshotTargets(snapshot)
        guard targets.count == snapshotTargetCount(snapshot) else {
            return recovery(.malformedSnapshot)
        }
        guard snapshot.initialWorkingScale.map({ valid(scale: $0, targets: targets) }) ?? true else {
            return recovery(.malformedSnapshot)
        }

        switch decode(facts: facts, closures: closures, root: root, targets: targets) {
        case let .failure(result):
            return result
        case let .success(decoded, retainedLate, parents):
            return project(
                root: root,
                snapshot: snapshot,
                facts: decoded,
                closures: closures,
                retainedLate: retainedLate,
                targets: targets,
                parents: parents
            )
        }
    }

    private func coalescedFacts() -> [SessionFactEvidence]? {
        coalescedByIdentity(evidence.facts, id: \.id)?.sorted(by: factOrder)
    }

    private func validContinuation(
        root: CookingSessionRootEvidence,
        snapshot: ExecutionSnapshot
    ) -> Bool {
        switch (root.sourceSessionID, root.sourceClosureID, snapshot.continuationBaseline) {
        case (nil, nil, nil):
            return true
        case let (sourceSessionID?, .some, baseline?) where sourceSessionID != root.id:
            let targets = snapshotTargets(snapshot)
            let progressTargets = baseline.progress.map(\.target.rawIdentifier)
            let entryIDs = baseline.entries.map(\.entry.id)
            let sourceEntryIDs = baseline.entries.compactMap(\.sourceEntryID)
            let mappedTargets = baseline.targetMappings.map(\.target.rawIdentifier)
            let sourceTargets = baseline.targetMappings.map(\.sourceTarget.rawIdentifier)
            let inheritedTargets = progressTargets
                + baseline.entries.compactMap { $0.entry.target?.rawIdentifier }
                + (baseline.workingScale?.quantities.map(\.ingredientID.rawValue) ?? [])
            return Set(progressTargets).count == progressTargets.count
                && baseline.progress.allSatisfy {
                    targets[$0.target.rawIdentifier] == $0.target
                }
                && Set(entryIDs).count == entryIDs.count
                && Set(sourceEntryIDs).count == sourceEntryIDs.count
                && baseline.entries.allSatisfy { entryTargetExists($0, targets: targets) }
                && Set(mappedTargets).count == mappedTargets.count
                && Set(inheritedTargets).isSubset(of: Set(mappedTargets))
                && baseline.targetMappings.allSatisfy {
                    targets[$0.target.rawIdentifier] == $0.target
                        && sameTargetKind($0.target, $0.sourceTarget)
                }
                && Set(sourceTargets).count == sourceTargets.count
                && baselineScaleIsValid(baseline, targets: targets)
        default:
            return false
        }
    }

    private func entryTargetExists(
        _ continuation: SessionContinuationEntry,
        targets: [UUID: SessionProgressTarget]
    ) -> Bool {
        guard let target = continuation.entry.target else { return true }
        return targets[target.rawIdentifier] == target
    }

    private func baselineScaleIsValid(
        _ baseline: SessionContinuationBaseline,
        targets: [UUID: SessionProgressTarget]
    ) -> Bool {
        guard let scale = baseline.workingScale else { return true }
        return valid(scale: scale, targets: targets)
    }

    private func sameTargetKind(
        _ target: SessionProgressTarget,
        _ source: SessionProgressTarget
    ) -> Bool {
        switch (target, source) {
        case (.ingredient, .ingredient), (.instruction, .instruction): true
        default: false
        }
    }

    private func coalescedClosures() -> [SessionClosureEvidence]? {
        coalescedByIdentity(evidence.closures, id: \.id)?.sorted {
            uuidOrder($0.id.rawValue, $1.id.rawValue)
        }
    }

    // Fact decoding preserves a single ordered classification path across every
    // supported and forward-compatible evidence variant.
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func decode(
        facts: [SessionFactEvidence],
        closures: [SessionClosureEvidence],
        root: CookingSessionRootEvidence,
        targets: [UUID: SessionProgressTarget]
    ) -> FactDecodeResult {
        var headsByID: [UUID: [UUID]] = [:]
        for fact in facts {
            guard fact.kitchenID == root.kitchenID else {
                return .failure(recovery(.crossSessionReference))
            }
            guard fact.causalHeadsFormatVersion == CausalHeadsCodec.formatVersion else {
                return .failure(
                    unavailable(.unsupportedCausalHeadsFormat(fact.causalHeadsFormatVersion))
                )
            }
            do {
                headsByID[fact.id.rawValue] = try CausalHeadsCodec.decode(
                    formatVersion: fact.causalHeadsFormatVersion,
                    data: fact.causalHeadsData
                )
            } catch {
                return .failure(recovery(.malformedCausalHeads))
            }
        }
        guard !directedGraphContainsCycle(headsByID) else {
            return .failure(recovery(.cycle))
        }
        let knownIDs = Set(headsByID.keys)
            .union(closures.map(\.id.rawValue))
            .union([root.id.rawValue])
        if let missing = headsByID.values.joined().first(where: { !knownIDs.contains($0) }) {
            return .failure(unavailable(.missingPredecessor(missing)))
        }
        guard headsByID.values.allSatisfy({
            directedGraphHeadsAreMaximal($0, parents: headsByID)
        }) else {
            return .failure(recovery(.invalidFact))
        }
        let closedCone = closedFactCone(closures: closures, parents: headsByID)
        var decoded: [DecodedFact] = []
        var retainedLate: [SessionFact.ID] = []
        for fact in facts {
            // The first pass inserts every Fact ID or returns a classification.
            // swiftlint:disable:next force_unwrapping
            let heads = headsByID[fact.id.rawValue]!
            guard SessionDigest.sha256(fact.payloadData) == fact.payloadDigest else {
                return .failure(recovery(.digestMismatch))
            }
            guard let kind = SessionFact.Kind(rawValue: fact.kind) else {
                guard let closedCone,
                      !closedCone.contains(fact.id.rawValue)
                else {
                    return .failure(unavailable(.unsupportedFactKind(fact.kind)))
                }
                retainedLate.append(fact.id)
                continue
            }
            guard fact.payloadFormatVersion == SessionFactPayloadCodec.formatVersion else {
                return .failure(unavailable(.unsupportedPayloadFormat(fact.payloadFormatVersion)))
            }
            let payload: SessionFactPayload
            do {
                payload = try SessionFactPayloadCodec.decode(
                    formatVersion: fact.payloadFormatVersion,
                    data: fact.payloadData
                )
            } catch {
                return .failure(recovery(.malformedPayload))
            }
            guard valid(fact: fact, kind: kind, payload: payload, targets: targets) else {
                return .failure(recovery(.invalidFact))
            }
            decoded.append(DecodedFact(evidence: fact, kind: kind, heads: heads, payload: payload))
        }
        return .success(facts: decoded, retainedLate: retainedLate, parents: headsByID)
    }

    private func closedFactCone(
        closures: [SessionClosureEvidence],
        parents: [UUID: [UUID]]
    ) -> Set<UUID>? {
        guard !closures.isEmpty else { return nil }
        let closureHeads = closures.compactMap { closure -> [UUID]? in
            guard closure.causalHeadsFormatVersion == CausalHeadsCodec.formatVersion else {
                return nil
            }
            return try? CausalHeadsCodec.decode(
                formatVersion: closure.causalHeadsFormatVersion,
                data: closure.causalHeadsData
            )
        }
        guard closureHeads.count == closures.count else { return nil }
        let heads = closureHeads.flatMap { $0 }
        return Set(parents.keys.filter { identifier in
            heads.contains(identifier) || heads.contains {
                directedGraphIsAncestor(identifier, of: $0, parents: parents)
            }
        })
    }

    private func valid(
        fact: SessionFactEvidence,
        kind: SessionFact.Kind,
        payload: SessionFactPayload,
        targets: [UUID: SessionProgressTarget]
    ) -> Bool {
        let target = fact.targetSnapshotElementID
        return switch (kind, target, payload) {
        case (.stop, nil, .empty), (.resume, nil, .empty):
            true
        case let (.progress, target?, .progress(state)):
            targetMatches(state: state, target: targets[target])
        case let (.workingScale, nil, .workingScale(scale)):
            valid(scale: scale, targets: targets)
        case let (.sessionEntry, target, .sessionEntry(operation)):
            valid(entry: operation, factID: fact.id, target: target, targets: targets)
        case (.sessionOutcome, nil, .sessionOutcome):
            true
        case (.conflictResolution, nil, .closureResolution):
            true
        default:
            false
        }
    }

    private func valid(
        scale: SessionWorkingScale,
        targets: [UUID: SessionProgressTarget]
    ) -> Bool {
        let quantityIDs = scale.quantities.map(\.ingredientID.rawValue)
        let unique = Set(quantityIDs).count == quantityIDs.count
        let ingredientsExist = quantityIDs.allSatisfy {
            if case .ingredient = targets[$0] { return true }
            return false
        }
        let validExactScale = scale.exactScale.map {
            $0.normalized != nil && $0.numerator > 0
        } ?? true
        return unique && ingredientsExist && validExactScale
    }

    private func valid(
        entry: SessionEntryOperation,
        factID: SessionFact.ID,
        target: UUID?,
        targets: [UUID: SessionProgressTarget]
    ) -> Bool {
        if let target, targets[target] == nil { return false }
        return switch entry {
        case let .submit(entryID, text):
            entryID.rawValue == factID.rawValue && !text.isEmpty
        case let .revise(_, text):
            !text.isEmpty
        case .withdraw:
            target == nil
        }
    }

    private func targetMatches(
        state: SessionProgressState,
        target: SessionProgressTarget?
    ) -> Bool {
        switch (state, target) {
        case (.ingredient, .ingredient), (.instruction, .instruction): true
        default: false
        }
    }

    // These inputs are the separately verified parts of one projection context;
    // keeping them explicit makes accidental trust of raw evidence harder.
    // swiftlint:disable:next function_parameter_count
    private func project(
        root: CookingSessionRootEvidence,
        snapshot: ExecutionSnapshot,
        facts: [DecodedFact],
        closures: [SessionClosureEvidence],
        retainedLate: [SessionFact.ID],
        targets: [UUID: SessionProgressTarget],
        parents: [UUID: [UUID]]
    ) -> SessionProjectionResult {
        let closureIDs = Set(closures.map(\.id.rawValue))
        for fact in facts {
            if fact.kind != .conflictResolution,
               fact.heads.contains(where: closureIDs.contains) {
                return recovery(.invalidFact)
            }
            if fact.kind == .conflictResolution,
               !validClosureResolution(fact, closureIDs: closureIDs) {
                return recovery(.invalidFact)
            }
        }
        guard facts.filter({ $0.kind != .conflictResolution }).allSatisfy({
            directedGraphIsAncestor(
                root.id.rawValue,
                of: $0.evidence.id.rawValue,
                parents: parents
            )
        }) else {
            return recovery(.invalidFact)
        }
        guard validEntryHistories(facts: facts, snapshot: snapshot, parents: parents) else {
            return recovery(.invalidFact)
        }
        guard !closures.isEmpty else {
            return .session(
                makeProjection(
                    snapshot: snapshot,
                    facts: facts,
                    targets: targets,
                    parents: parents
                )
            )
        }
        return finishedProjection(
            root: root,
            snapshot: snapshot,
            facts: facts,
            closures: closures,
            retainedLate: retainedLate,
            targets: targets,
            parents: parents
        )
    }

    private func validClosureResolution(_ fact: DecodedFact, closureIDs: Set<UUID>) -> Bool {
        guard case let .closureResolution(selection) = fact.payload
        else { return false }
        let observed = selection.observedClosureIDs.map(\.rawValue)
        let observedSet = Set(observed)
        return observedSet.count > 1
            && observedSet.isSubset(of: closureIDs)
            && observedSet.count == observed.count
            && observedSet.contains(selection.selectedClosureID.rawValue)
            && Set(fact.heads) == observedSet
    }

}
// swiftlint:enable file_length type_body_length
