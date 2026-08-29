// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain

struct SessionFactDescription {
  let kind: SessionFact.Kind
  let payload: SessionFactPayload
  let target: UUID?
}

struct CookingSessionCommandFactory {
  let encoding: any CookingSessionEncoding

  func closure(
    intention: FinishCookingSessionIntention,
    kitchenID: Kitchen.ID,
    projection: CookingSessionProjection,
    evidence: SessionEvidence
  ) throws -> SessionClosureEvidence {
    // Projection has already proven the single root before command creation.
    let root = evidence.roots[0]
    let closed: EncodedSessionValue
    do {
      closed = try encoding.projection(ClosedSessionProjection(projection))
    } catch {
      throw CookingSessionLogicError.encodingFailed
    }
    let encodedOutcome: EncodedSessionValue?
    do {
      encodedOutcome = try projection.outcome.map(encoding.outcome)
    } catch {
      throw CookingSessionLogicError.encodingFailed
    }
    let heads = CausalHeadsCodec.encode(try maximalSessionHeads(evidence))
    return SessionClosureEvidence(
      id: intention.closureID,
      sessionID: intention.sessionID,
      kitchenID: kitchenID,
      finishedAt: intention.finishedAt,
      causalHeadsFormatVersion: heads.formatVersion,
      causalHeadsData: heads.data,
      snapshotFormatVersion: root.snapshotFormatVersion,
      snapshotDigest: root.snapshotDigest,
      projectionFormatVersion: closed.formatVersion,
      projectionDigest: closed.digest,
      outcomeFormatVersion: encodedOutcome?.formatVersion,
      outcomeData: encodedOutcome?.data
    )
  }

  func fact(
    intention: SessionFactIntention,
    kitchenID: Kitchen.ID,
    description: SessionFactDescription,
    evidence: SessionEvidence
  ) throws -> SessionFactEvidence {
    let encodedPayload: EncodedSessionValue
    do {
      encodedPayload = try encoding.fact(description.payload)
    } catch {
      throw CookingSessionLogicError.encodingFailed
    }
    let heads = CausalHeadsCodec.encode(try maximalSessionHeads(evidence))
    return SessionFactEvidence(
      id: intention.id,
      sessionID: intention.sessionID,
      kitchenID: kitchenID,
      kind: description.kind.rawValue,
      targetSnapshotElementID: description.target,
      authoredAt: intention.authoredAt,
      causalHeadsFormatVersion: heads.formatVersion,
      causalHeadsData: heads.data,
      payloadFormatVersion: encodedPayload.formatVersion,
      payloadData: encodedPayload.data,
      payloadDigest: encodedPayload.digest
    )
  }

  func matchesRetry(
    _ existing: SessionFactEvidence,
    intention: SessionFactIntention,
    kitchenID: Kitchen.ID,
    description: SessionFactDescription
  ) throws -> Bool {
    let encoded: EncodedSessionValue
    do {
      encoded = try encoding.fact(description.payload)
    } catch {
      throw CookingSessionLogicError.encodingFailed
    }
    return existing.id == intention.id
      && existing.sessionID == intention.sessionID
      && existing.kitchenID == kitchenID
      && existing.kind == description.kind.rawValue
      && existing.targetSnapshotElementID == description.target
      && existing.authoredAt == intention.authoredAt
      && existing.payloadFormatVersion == encoded.formatVersion
      && existing.payloadData == encoded.data
      && existing.payloadDigest == encoded.digest
  }

  func maximalSessionHeads(_ evidence: SessionEvidence) throws -> [UUID] {
    let uniqueFacts = Dictionary(grouping: evidence.facts, by: \.id).compactMap { _, facts in
      facts.first
    }
    var parents = Dictionary(uniqueKeysWithValues: try uniqueFacts.map { fact in
      let decoded = try CausalHeadsCodec.decode(
        formatVersion: fact.causalHeadsFormatVersion,
        data: fact.causalHeadsData
      )
      return (fact.id.rawValue, decoded)
    })
    for root in evidence.roots {
      parents[root.id.rawValue] = []
    }
    for closure in evidence.closures {
      parents[closure.id.rawValue] = try CausalHeadsCodec.decode(
        formatVersion: closure.causalHeadsFormatVersion,
        data: closure.causalHeadsData
      )
    }
    return parents.keys.filter { candidate in
      !parents.keys.contains { other in
        candidate != other && isAncestor(candidate, of: other, parents: parents)
      }
    }.sorted { $0.uuidString < $1.uuidString }
  }

  private func isAncestor(
    _ ancestor: UUID,
    of descendant: UUID,
    parents: [UUID: [UUID]]
  ) -> Bool {
    // Every descendant is selected from this dictionary's keys.
    // swiftlint:disable:next force_unwrapping
    let directParents = parents[descendant]!
    if directParents.contains(ancestor) { return true }
    return directParents.contains {
      isAncestor(ancestor, of: $0, parents: parents)
    }
  }
}
