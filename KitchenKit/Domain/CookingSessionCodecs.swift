// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CryptoKit
import Foundation

/// Canonical format-tagged Session bytes and their SHA-256 commitment.
public struct EncodedSessionValue: Equatable, Sendable {
    /// The frozen codec version interpreting these bytes.
    public let formatVersion: Int
    /// The canonical encoded bytes to retain unchanged in the evidence envelope.
    public let data: Data
    /// SHA-256 of the canonical encoded bytes, independent of transport availability.
    public let digest: Data

    /// Retains an encoded envelope without verifying canonicality or checking an external commitment.
    public init(formatVersion: Int, data: Data, digest: Data) {
        self.formatVersion = formatVersion
        self.data = data
        self.digest = digest
    }
}

/// The format-1 canonical JSON representation of self-contained cooking context.
public enum ExecutionSnapshotCodec {
    /// The supported canonical JSON format, currently version 1.
    public static let formatVersion = 1

    /// Encodes the supplied snapshot as sorted-key JSON and returns its SHA-256 commitment.
    ///
    /// Encoding does not perform evidence ownership, target, or causal validation.
    /// Caller-created collection order must already satisfy the format’s invariants.
    public static func encode(_ snapshot: ExecutionSnapshot) throws -> EncodedSessionValue {
        try canonicalJSON(snapshot, formatVersion: formatVersion)
    }

    /// Decodes a supported canonical snapshot without repairing retained bytes.
    ///
    /// Throws for unknown versions, malformed JSON, or a value whose canonical re-encoding
    /// differs. Evidence digest and domain-invariant checks remain projector responsibilities.
    public static func decode(formatVersion: Int, data: Data) throws -> ExecutionSnapshot {
        guard formatVersion == self.formatVersion else {
            throw SessionCodecError.unsupportedFormat(formatVersion)
        }
        return try decodeCanonicalJSON(
            ExecutionSnapshot.self,
            from: data,
            valueIsCanonical: snapshotCollectionsAreCanonical
        )
    }
}

/// A failure to read canonical Session evidence without changing the retained bytes.
public enum SessionCodecError: Error, Equatable {
    /// The supplied byte layout or JSON cannot represent the declared value.
    case malformedData
    /// Decoded values or re-encoded bytes violate canonical ordering or spelling.
    case noncanonicalData
    /// The declared format version is unknown; retain its bytes for a future reader.
    case unsupportedFormat(Int)
}

/// SHA-256 commitments for canonical Session evidence bytes.
public enum SessionDigest {
    /// Returns the raw 32-byte SHA-256 digest of exactly the supplied bytes.
    public static func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }
}

/// A format-tagged sorted UUID frontier with no payload values.
public struct EncodedCausalHeads: Equatable, Sendable {
    /// The frozen codec version interpreting these bytes.
    public let formatVersion: Int
    /// The canonical encoded bytes to retain unchanged in the evidence envelope.
    public let data: Data

    /// Retains an encoded envelope without verifying canonicality or checking an external commitment.
    public init(formatVersion: Int, data: Data) {
        self.formatVersion = formatVersion
        self.data = data
    }
}

/// Format-1 Session frontiers encoded as lexicographically sorted raw UUID bytes.
///
/// Decoding rejects duplicate or unsorted identities instead of silently normalizing
/// retained evidence. Encoding sorts but does not remove duplicate input identities.
public enum CausalHeadsCodec {
    /// The supported raw sorted UUID frontier format, currently version 1.
    public static let formatVersion = 1

    /// Sorts raw UUID bytes and concatenates them without delimiters.
    ///
    /// Input duplicates are retained; callers must supply a set-like frontier or the
    /// result will fail the decoder’s uniqueness check.
    public static func encode(_ identifiers: [UUID]) -> EncodedCausalHeads {
        let sortedBytes = identifiers.map(uuidBytes).sorted(by: lexicographicallyPrecedes)
        return EncodedCausalHeads(
            formatVersion: formatVersion,
            data: Data(sortedBytes.flatMap { $0 })
        )
    }

    /// Reads only supported, 16-byte-aligned, unique, sorted predecessor UUIDs.
    ///
    /// Throws for unsupported versions, malformed layout, or noncanonical ordering;
    /// it does not verify dependency existence or causal antichain policy.
    public static func decode(formatVersion: Int, data: Data) throws -> [UUID] {
        guard formatVersion == self.formatVersion else {
            throw SessionCodecError.unsupportedFormat(formatVersion)
        }
        guard data.count.isMultiple(of: 16) else {
            throw SessionCodecError.malformedData
        }
        let bytes = [UInt8](data)
        let identifiers = stride(from: 0, to: bytes.count, by: 16).map { offset in
            UUID(uuid: (
                bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3],
                bytes[offset + 4], bytes[offset + 5], bytes[offset + 6], bytes[offset + 7],
                bytes[offset + 8], bytes[offset + 9], bytes[offset + 10], bytes[offset + 11],
                bytes[offset + 12], bytes[offset + 13], bytes[offset + 14], bytes[offset + 15]
            ))
        }
        guard Set(identifiers).count == identifiers.count,
              encode(identifiers).data == data
        else {
            throw SessionCodecError.noncanonicalData
        }
        return identifiers
    }

    private static func uuidBytes(_ identifier: UUID) -> [UInt8] {
        var value = identifier.uuid
        return withUnsafeBytes(of: &value) { Array($0) }
    }

    private static func lexicographicallyPrecedes(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
        lhs.lexicographicallyPrecedes(rhs)
    }
}

/// The format-1 canonical JSON representation of typed cooking Fact content.
public enum SessionFactPayloadCodec {
    /// The supported canonical JSON format, currently version 1.
    public static let formatVersion = 1

    /// Encodes the supplied Fact payload as sorted-key JSON and returns its SHA-256 commitment.
    ///
    /// Encoding does not perform evidence ownership, target, or causal validation.
    /// Caller-created collection order must already satisfy the format’s invariants.
    public static func encode(_ payload: SessionFactPayload) throws -> EncodedSessionValue {
        try canonicalJSON(payload, formatVersion: formatVersion)
    }

    /// Decodes a supported canonical Fact payload without repairing retained bytes.
    ///
    /// Throws for unknown versions, malformed JSON, or a value whose canonical re-encoding
    /// differs. Evidence digest and domain-invariant checks remain projector responsibilities.
    public static func decode(formatVersion: Int, data: Data) throws -> SessionFactPayload {
        guard formatVersion == self.formatVersion else {
            throw SessionCodecError.unsupportedFormat(formatVersion)
        }
        return try decodeCanonicalJSON(
            SessionFactPayload.self,
            from: data,
            valueIsCanonical: payloadCollectionsAreCanonical
        )
    }
}

/// The format-1 canonical JSON representation of a coarse Session Outcome.
public enum SessionOutcomeCodec {
    /// The supported canonical JSON format, currently version 1.
    public static let formatVersion = 1

    /// Encodes the coarse assessment as sorted-key JSON and returns its SHA-256 commitment.
    ///
    /// The assessment is independent of lifecycle; this method does not finish a
    /// Session or compare an external Closure’s commitment.
    public static func encode(_ outcome: SessionOutcome) throws -> EncodedSessionValue {
        try canonicalJSON(outcome, formatVersion: formatVersion)
    }

    /// Decodes a supported canonical Outcome without repairing retained bytes.
    ///
    /// Throws for unknown versions, malformed JSON, or a value whose canonical re-encoding
    /// differs. Evidence digest and domain-invariant checks remain projector responsibilities.
    public static func decode(formatVersion: Int, data: Data) throws -> SessionOutcome {
        guard formatVersion == self.formatVersion else {
            throw SessionCodecError.unsupportedFormat(formatVersion)
        }
        return try decodeCanonicalJSON(SessionOutcome.self, from: data)
    }
}

/// The format-1 canonical JSON representation of copied continuation context.
public enum SessionContinuationBaselineCodec {
    /// The supported canonical JSON format, currently version 1.
    public static let formatVersion = 1

    /// Encodes the supplied continuation baseline as sorted-key JSON and returns its SHA-256 commitment.
    ///
    /// Encoding does not perform evidence ownership, target, or causal validation.
    /// Caller-created collection order must already satisfy the format’s invariants.
    public static func encode(
        _ baseline: SessionContinuationBaseline
    ) throws -> EncodedSessionValue {
        try canonicalJSON(baseline, formatVersion: formatVersion)
    }

    /// Decodes a supported canonical continuation baseline without repairing retained bytes.
    ///
    /// Throws for unknown versions, malformed JSON, or a value whose canonical re-encoding
    /// differs. Evidence digest and domain-invariant checks remain projector responsibilities.
    public static func decode(
        formatVersion: Int,
        data: Data
    ) throws -> SessionContinuationBaseline {
        guard formatVersion == self.formatVersion else {
            throw SessionCodecError.unsupportedFormat(formatVersion)
        }
        return try decodeCanonicalJSON(
            SessionContinuationBaseline.self,
            from: data,
            valueIsCanonical: baselineCollectionsAreCanonical
        )
    }
}

/// The format-1 canonical JSON representation committed by a Session Closure.
public enum ClosedSessionProjectionCodec {
    /// The supported canonical JSON format, currently version 1.
    public static let formatVersion = 1

    /// Encodes the supplied closed projection as sorted-key JSON and returns its SHA-256 commitment.
    ///
    /// Encoding does not perform evidence ownership, target, or causal validation.
    /// Caller-created collection order must already satisfy the format’s invariants.
    public static func encode(_ projection: ClosedSessionProjection) throws -> EncodedSessionValue {
        try canonicalJSON(projection, formatVersion: formatVersion)
    }

    /// Decodes a supported canonical closed projection without repairing retained bytes.
    ///
    /// Throws for unknown versions, malformed JSON, or a value whose canonical re-encoding
    /// differs. Evidence digest and domain-invariant checks remain projector responsibilities.
    public static func decode(formatVersion: Int, data: Data) throws -> ClosedSessionProjection {
        guard formatVersion == self.formatVersion else {
            throw SessionCodecError.unsupportedFormat(formatVersion)
        }
        return try decodeCanonicalJSON(
            ClosedSessionProjection.self,
            from: data,
            valueIsCanonical: closedProjectionCollectionsAreCanonical
        )
    }
}

private func canonicalJSON<Value: Encodable>(
    _ value: Value,
    formatVersion: Int
) throws -> EncodedSessionValue {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(value)
    return EncodedSessionValue(
        formatVersion: formatVersion,
        data: data,
        digest: SessionDigest.sha256(data)
    )
}

private func decodeCanonicalJSON<Value: Codable>(
    _ type: Value.Type,
    from data: Data,
    valueIsCanonical: (Value) -> Bool = { _ in true }
) throws -> Value {
    let value: Value
    do {
        value = try JSONDecoder().decode(type, from: data)
    } catch {
        throw SessionCodecError.malformedData
    }
    guard valueIsCanonical(value),
          try canonicalJSON(value, formatVersion: 0).data == data
    else {
        throw SessionCodecError.noncanonicalData
    }
    return value
}

private func snapshotCollectionsAreCanonical(_ snapshot: ExecutionSnapshot) -> Bool {
    (snapshot.initialWorkingScale.map(scaleCollectionsAreCanonical) ?? true)
        && (snapshot.continuationBaseline.map(baselineCollectionsAreCanonical) ?? true)
}

private func payloadCollectionsAreCanonical(_ payload: SessionFactPayload) -> Bool {
    switch payload {
    case let .workingScale(scale):
        scaleCollectionsAreCanonical(scale)
    case let .closureResolution(selection):
        uuidsAreSorted(selection.observedClosureIDs.map(\.rawValue))
    default:
        true
    }
}

private func baselineCollectionsAreCanonical(_ baseline: SessionContinuationBaseline) -> Bool {
    guard uuidsAreSorted(baseline.progress.map(\.target.rawIdentifier)),
          uuidsAreSorted(baseline.entries.map(\.entry.id.rawValue)),
          uuidsAreSorted(baseline.targetMappings.map(\.target.rawIdentifier))
    else { return false }
    if let scale = baseline.workingScale {
        return scaleCollectionsAreCanonical(scale)
    }
    return true
}

private func closedProjectionCollectionsAreCanonical(_ projection: ClosedSessionProjection) -> Bool {
    guard snapshotCollectionsAreCanonical(projection.snapshot),
          uuidsAreSorted(projection.progress.map(\.target.rawIdentifier)),
          uuidsAreSorted(projection.entries.map(\.id.rawValue))
    else { return false }
    if let scale = projection.workingScale {
        return scaleCollectionsAreCanonical(scale)
    }
    return true
}

private func scaleCollectionsAreCanonical(_ scale: SessionWorkingScale) -> Bool {
    uuidsAreSorted(scale.quantities.map(\.ingredientID.rawValue))
}

private func uuidsAreSorted(_ identifiers: [UUID]) -> Bool {
    identifiers == identifiers.sorted { $0.uuidString < $1.uuidString }
}
