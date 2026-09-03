// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

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
    let facts = IdentityCollection.stableUnique(evidence.facts, id: \.id)
    let roots = IdentityCollection.stableUnique(evidence.roots, id: \.id)
    let closures = IdentityCollection.stableUnique(evidence.closures, id: \.id)
    var parents = Dictionary(uniqueKeysWithValues: roots.map {
      ($0.id.rawValue, [UUID]())
    })
    for fact in facts {
      parents[fact.id.rawValue] = try decodeHeads(
        version: fact.causalHeadsFormatVersion,
        data: fact.causalHeadsData
      )
    }
    for closure in closures {
      parents[closure.id.rawValue] = try decodeHeads(
        version: closure.causalHeadsFormatVersion,
        data: closure.causalHeadsData
      )
    }
    return CausalGraph(parentsByNode: parents, orderedBy: uuidOrder).maximalNodes
  }

  private func decodeHeads(version: Int, data: Data) throws -> [UUID] {
    try CausalHeadsCodec.decode(formatVersion: version, data: data)
  }

  private func uuidOrder(_ lhs: UUID, _ rhs: UUID) -> Bool {
    lhs.uuidString < rhs.uuidString
  }
}
