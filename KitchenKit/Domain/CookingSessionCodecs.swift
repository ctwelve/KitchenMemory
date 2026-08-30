// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import CryptoKit
import Foundation

public struct EncodedSessionValue: Equatable, Sendable {
    public let formatVersion: Int
    public let data: Data
    public let digest: Data

    public init(formatVersion: Int, data: Data, digest: Data) {
        self.formatVersion = formatVersion
        self.data = data
        self.digest = digest
    }
}

public enum ExecutionSnapshotCodec {
    public static let formatVersion = 1

    public static func encode(_ snapshot: ExecutionSnapshot) throws -> EncodedSessionValue {
        try canonicalJSON(snapshot, formatVersion: formatVersion)
    }

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

public enum SessionCodecError: Error, Equatable {
    case malformedData
    case noncanonicalData
    case unsupportedFormat(Int)
}

public enum SessionDigest {
    public static func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }
}

public struct EncodedCausalHeads: Equatable, Sendable {
    public let formatVersion: Int
    public let data: Data

    public init(formatVersion: Int, data: Data) {
        self.formatVersion = formatVersion
        self.data = data
    }
}

public enum CausalHeadsCodec {
    public static let formatVersion = 1

    public static func encode(_ identifiers: [UUID]) -> EncodedCausalHeads {
        let sortedBytes = identifiers.map(uuidBytes).sorted(by: lexicographicallyPrecedes)
        return EncodedCausalHeads(
            formatVersion: formatVersion,
            data: Data(sortedBytes.flatMap { $0 })
        )
    }

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

public enum SessionFactPayloadCodec {
    public static let formatVersion = 1

    public static func encode(_ payload: SessionFactPayload) throws -> EncodedSessionValue {
        try canonicalJSON(payload, formatVersion: formatVersion)
    }

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

public enum SessionOutcomeCodec {
    public static let formatVersion = 1

    public static func encode(_ outcome: SessionOutcome) throws -> EncodedSessionValue {
        try canonicalJSON(outcome, formatVersion: formatVersion)
    }

    public static func decode(formatVersion: Int, data: Data) throws -> SessionOutcome {
        guard formatVersion == self.formatVersion else {
            throw SessionCodecError.unsupportedFormat(formatVersion)
        }
        return try decodeCanonicalJSON(SessionOutcome.self, from: data)
    }
}

public enum SessionContinuationBaselineCodec {
    public static let formatVersion = 1

    public static func encode(
        _ baseline: SessionContinuationBaseline
    ) throws -> EncodedSessionValue {
        try canonicalJSON(baseline, formatVersion: formatVersion)
    }

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

public enum ClosedSessionProjectionCodec {
    public static let formatVersion = 1

    public static func encode(_ projection: ClosedSessionProjection) throws -> EncodedSessionValue {
        try canonicalJSON(projection, formatVersion: formatVersion)
    }

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
