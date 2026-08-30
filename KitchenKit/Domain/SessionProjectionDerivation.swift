// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

extension ProjectionBuilder {
    func makeProjection(
        snapshot: ExecutionSnapshot,
        facts: [DecodedFact],
        targets: [UUID: SessionProgressTarget],
        parents: [UUID: [UUID]]
    ) -> CookingSessionProjection {
        let lifecycle = lifecycle(facts: facts, parents: parents)
        let progress = progress(
            facts: facts,
            baseline: snapshot.continuationBaseline?.progress ?? [],
            targets: targets,
            parents: parents
        )
        let workingScale = workingScale(facts: facts, snapshot: snapshot, parents: parents)
        let entries = entries(
            facts: facts,
            baseline: snapshot.continuationBaseline?.entries ?? [],
            targets: targets,
            parents: parents
        )
        let outcome = outcome(facts: facts, parents: parents)
        return CookingSessionProjection(
            id: evidence.sessionID,
            snapshot: snapshot,
            sourceSessionID: evidence.roots.first?.sourceSessionID,
            sourceClosureID: evidence.roots.first?.sourceClosureID,
            lifecycle: lifecycle,
            progress: progress.values,
            workingScale: workingScale.value,
            entries: entries.values,
            outcome: outcome.value,
            conflicts: progress.conflicts
                + workingScale.conflicts
                + entries.conflicts
                + outcome.conflicts
        )
    }

    func lifecycle(facts: [DecodedFact], parents: [UUID: [UUID]]) -> SessionLifecycle {
        let lifecycleFacts = facts.filter { $0.kind == .stop || $0.kind == .resume }
        let maximal = maximalFacts(lifecycleFacts, parents: parents)
        guard !maximal.isEmpty else { return .active }
        return maximal.contains(where: { $0.kind == .resume }) ? .active : .stopped
    }

    func progress(
        facts: [DecodedFact],
        baseline: [SessionProgress],
        targets: [UUID: SessionProgressTarget],
        parents: [UUID: [UUID]]
    ) -> (values: [SessionProgress], conflicts: [SessionConflict]) {
        let progressFacts = facts.filter { $0.kind == .progress }
        let groups = Dictionary(grouping: progressFacts) { $0.evidence.targetSnapshotElementID! }
        var values: [SessionProgress] = []
        var conflicts: [SessionConflict] = []
        for targetID in groups.keys.sorted(by: uuidOrder) {
            guard let target = targets[targetID], let group = groups[targetID] else { continue }
            let maximal = maximalFacts(group, parents: parents).sorted(by: decodedFactOrder)
            let states = maximal.compactMap { fact -> SessionProgressState? in
                guard case let .progress(state) = fact.payload else { return nil }
                return state
            }
            let distinct = Set(states)
            let state = distinct.count == 1 ? states[0] : nonhidingState(for: target)
            values.append(SessionProgress(target: target, state: state))
            if distinct.count > 1 {
                conflicts.append(
                    .progress(
                        target: target,
                        factIDs: maximal.map(\.evidence.id),
                        states: states
                    )
                )
            }
        }
        let changedTargets = Set(groups.keys)
        values += baseline.filter { !changedTargets.contains($0.target.rawIdentifier) }
        values.sort { uuidOrder($0.target.rawIdentifier, $1.target.rawIdentifier) }
        return (values, conflicts)
    }

    func workingScale(
        facts: [DecodedFact],
        snapshot: ExecutionSnapshot,
        parents: [UUID: [UUID]]
    ) -> (value: SessionWorkingScale?, conflicts: [SessionConflict]) {
        let scaleFacts = maximalFacts(
            facts.filter { $0.kind == .workingScale },
            parents: parents
        ).sorted(by: decodedFactOrder)
        guard !scaleFacts.isEmpty else {
            return (
                snapshot.continuationBaseline?.workingScale ?? snapshot.initialWorkingScale,
                []
            )
        }
        let values = scaleFacts.compactMap { fact -> SessionWorkingScale? in
            guard case let .workingScale(value) = fact.payload else { return nil }
            return value
        }
        guard allEqual(values) else {
            return (
                nil,
                [.workingScale(factIDs: scaleFacts.map(\.evidence.id), values: values)]
            )
        }
        return (values[0], [])
    }

    func validEntryHistories(
        facts: [DecodedFact],
        snapshot: ExecutionSnapshot,
        parents: [UUID: [UUID]]
    ) -> Bool {
        let entryFacts = facts.filter { $0.kind == .sessionEntry }
        let baselineIDs = Set(snapshot.continuationBaseline?.entries.map(\.entry.id) ?? [])
        return entryFacts.allSatisfy { fact in
            guard case let .sessionEntry(operation) = fact.payload else { return false }
            switch operation {
            case .submit:
                return true
            case let .revise(entryID, _), let .withdraw(entryID):
                return baselineIDs.contains(entryID) || entryFacts.contains { possibleSubmit in
                    guard case let .sessionEntry(.submit(submittedID, _)) = possibleSubmit.payload,
                          submittedID == entryID
                    else { return false }
                    return isAncestor(
                        possibleSubmit.evidence.id.rawValue,
                        of: fact.evidence.id.rawValue,
                        parents: parents
                    )
                }
            }
        }
    }

    func entries(
        facts: [DecodedFact],
        baseline: [SessionContinuationEntry],
        targets: [UUID: SessionProgressTarget],
        parents: [UUID: [UUID]]
    ) -> (values: [SessionEntry], conflicts: [SessionConflict]) {
        let keyedFacts = facts.compactMap { fact -> (SessionEntry.ID, DecodedFact)? in
            guard case let .sessionEntry(operation) = fact.payload else { return nil }
            return (operation.entryID, fact)
        }
        let groups = Dictionary(grouping: keyedFacts, by: \.0)
        var values: [SessionEntry] = []
        var conflicts: [SessionConflict] = []
        for entryID in groups.keys.sorted(by: { uuidOrder($0.rawValue, $1.rawValue) }) {
            guard let group = groups[entryID] else { continue }
            let maximal = maximalFacts(group.map(\.1), parents: parents).sorted(by: decodedFactOrder)
            let candidates = maximal.compactMap { entryValue(fact: $0, targets: targets) }
            if allEqual(candidates) {
                if case let .present(entry) = candidates[0] { values.append(entry) }
            } else {
                conflicts.append(
                    .entry(
                        entryID: entryID,
                        factIDs: maximal.map(\.evidence.id),
                        values: candidates
                    )
                )
            }
        }
        let changedEntryIDs = Set(groups.keys)
        values += baseline.map(\.entry).filter { !changedEntryIDs.contains($0.id) }
        values.sort { uuidOrder($0.id.rawValue, $1.id.rawValue) }
        return (values, conflicts)
    }

    func outcome(
        facts: [DecodedFact],
        parents: [UUID: [UUID]]
    ) -> (value: SessionOutcome?, conflicts: [SessionConflict]) {
        let outcomeFacts = maximalFacts(
            facts.filter { $0.kind == .sessionOutcome },
            parents: parents
        ).sorted(by: decodedFactOrder)
        guard !outcomeFacts.isEmpty else { return (nil, []) }
        let values = outcomeFacts.compactMap { fact -> SessionOutcomeConflictValue? in
            guard case let .sessionOutcome(change) = fact.payload else { return nil }
            switch change {
            case let .set(value): return .value(value)
            case .clear: return .cleared
            }
        }
        guard allEqual(values) else {
            return (nil, [.outcome(factIDs: outcomeFacts.map(\.evidence.id), values: values)])
        }
        if case let .value(value) = values[0] { return (value, []) }
        return (nil, [])
    }

    private func entryValue(
        fact: DecodedFact,
        targets: [UUID: SessionProgressTarget]
    ) -> SessionEntryConflictValue? {
        guard case let .sessionEntry(operation) = fact.payload else { return nil }
        switch operation {
        case let .submit(entryID, text), let .revise(entryID, text):
            return .present(
                SessionEntry(
                    id: entryID,
                    target: fact.evidence.targetSnapshotElementID.flatMap { targets[$0] },
                    text: text
                )
            )
        case .withdraw:
            return .withdrawn
        }
    }

    private func allEqual<Value: Equatable>(_ values: [Value]) -> Bool {
        guard let first = values.first else { return true }
        return values.dropFirst().allSatisfy { $0 == first }
    }

    private func nonhidingState(for target: SessionProgressTarget) -> SessionProgressState {
        switch target {
        case .ingredient: .ingredient(.open)
        case .instruction: .instruction(.open)
        }
    }
}
