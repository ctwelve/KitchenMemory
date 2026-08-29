// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

protocol CookingSessionEncoding {
  func snapshot(_ value: ExecutionSnapshot) throws -> EncodedSessionValue
  func fact(_ value: SessionFactPayload) throws -> EncodedSessionValue
  func projection(_ value: ClosedSessionProjection) throws -> EncodedSessionValue
  func outcome(_ value: SessionOutcome) throws -> EncodedSessionValue
}

struct CanonicalCookingSessionEncoding: CookingSessionEncoding {
  func snapshot(_ value: ExecutionSnapshot) throws -> EncodedSessionValue {
    try ExecutionSnapshotCodec.encode(value)
  }

  func fact(_ value: SessionFactPayload) throws -> EncodedSessionValue {
    try SessionFactPayloadCodec.encode(value)
  }

  func projection(_ value: ClosedSessionProjection) throws -> EncodedSessionValue {
    try ClosedSessionProjectionCodec.encode(value)
  }

  func outcome(_ value: SessionOutcome) throws -> EncodedSessionValue {
    try SessionOutcomeCodec.encode(value)
  }
}
