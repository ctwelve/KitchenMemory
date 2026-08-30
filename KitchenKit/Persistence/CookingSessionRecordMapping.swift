// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

struct StoredSessionEvidence {
  let evidence: SessionEvidence
  let containsPlaceholder: Bool

  var projection: SessionProjectionResult {
    if containsPlaceholder {
      return .recovery(
        SessionRecovery(evidence: evidence, reasons: [.placeholderBearingRecord])
      )
    }
    return SessionEvidenceProjector.project(evidence)
  }
}

extension CookingSessionTransactionRecords {
  func validateForPersistence() throws {
    guard roots.allSatisfy(\.isComplete),
          facts.allSatisfy(\.isComplete),
          closures.allSatisfy(\.isComplete),
          deletions.allSatisfy(\.isComplete),
          restorations.allSatisfy(\.isComplete)
    else { throw CookingSessionRepositoryError.placeholderBearingEvidence }
  }
}

extension CookingSessionRootEvidence {
  var isComplete: Bool {
    !id.rawValue.isZero && !kitchenID.rawValue.isZero
      && !recipeID.rawValue.isZero && !recipeRevisionID.rawValue.isZero
      && startedAt != .distantPast && snapshotFormatVersion > 0
      && !snapshotData.isEmpty && !snapshotDigest.isEmpty
      && !(sourceSessionID?.rawValue.isZero ?? false)
      && !(sourceClosureID?.rawValue.isZero ?? false)
      && ((sourceSessionID == nil) == (sourceClosureID == nil))
  }
}

extension SessionFactEvidence {
  var isComplete: Bool {
    !id.rawValue.isZero && !sessionID.rawValue.isZero && !kitchenID.rawValue.isZero
      && !kind.isEmpty && authoredAt != .distantPast
      && causalHeadsFormatVersion > 0 && payloadFormatVersion > 0
      && !payloadData.isEmpty && !payloadDigest.isEmpty
      && !(targetSnapshotElementID?.isZero ?? false)
  }
}

extension SessionClosureEvidence {
  var isComplete: Bool {
    !id.rawValue.isZero && !sessionID.rawValue.isZero && !kitchenID.rawValue.isZero
      && finishedAt != .distantPast && causalHeadsFormatVersion > 0
      && snapshotFormatVersion > 0 && !snapshotDigest.isEmpty
      && projectionFormatVersion > 0 && !projectionDigest.isEmpty
      && ((outcomeFormatVersion == nil) == (outcomeData == nil))
      && (outcomeFormatVersion.map { $0 > 0 } ?? true)
      && (outcomeData.map { !$0.isEmpty } ?? true)
  }
}

extension SessionDeletionEvidence {
  var isComplete: Bool {
    !id.rawValue.isZero && !sessionID.rawValue.isZero && !kitchenID.rawValue.isZero
      && deletedAt != .distantPast && sessionHeadsFormatVersion > 0
      && dispositionHeadsFormatVersion > 0 && !sessionHeadsData.isEmpty
  }
}

extension SessionDeletionResolutionEvidence {
  var isComplete: Bool {
    !id.rawValue.isZero && !deletionID.rawValue.isZero
      && !sessionID.rawValue.isZero && !kitchenID.rawValue.isZero
      && restoredAt != .distantPast && dispositionHeadsFormatVersion > 0
      && !dispositionHeadsData.isEmpty
  }
}

extension CookingSessionRecord {
  var evidence: CookingSessionRootEvidence {
    CookingSessionRootEvidence(
      id: .init(rawValue: id),
      kitchenID: .init(rawValue: kitchenID),
      recipeID: .init(rawValue: recipeID),
      recipeRevisionID: .init(rawValue: recipeRevisionID),
      startedAt: startedAt,
      snapshotFormatVersion: snapshotFormatVersion,
      snapshotData: snapshotData,
      snapshotDigest: snapshotDigest,
      sourceSessionID: sourceSessionID.map(CookingSession.ID.init(rawValue:)),
      sourceClosureID: sourceClosureID.map(SessionClosure.ID.init(rawValue:))
    )
  }
}

extension SessionFactRecord {
  var evidence: SessionFactEvidence {
    SessionFactEvidence(
      id: .init(rawValue: id),
      sessionID: .init(rawValue: sessionID),
      kitchenID: .init(rawValue: kitchenID),
      kind: kind,
      targetSnapshotElementID: targetSnapshotElementID,
      authoredAt: authoredAt,
      causalHeadsFormatVersion: causalHeadsFormatVersion,
      causalHeadsData: causalHeadsData,
      payloadFormatVersion: payloadFormatVersion,
      payloadData: payloadData,
      payloadDigest: payloadDigest
    )
  }
}

extension SessionClosureRecord {
  var evidence: SessionClosureEvidence {
    SessionClosureEvidence(
      id: .init(rawValue: id),
      sessionID: .init(rawValue: sessionID),
      kitchenID: .init(rawValue: kitchenID),
      finishedAt: finishedAt,
      causalHeadsFormatVersion: causalHeadsFormatVersion,
      causalHeadsData: causalHeadsData,
      snapshotFormatVersion: snapshotFormatVersion,
      snapshotDigest: snapshotDigest,
      projectionFormatVersion: projectionFormatVersion,
      projectionDigest: projectionDigest,
      outcomeFormatVersion: outcomeFormatVersion,
      outcomeData: outcomeData
    )
  }
}

extension SessionDeletionRecord {
  var evidence: SessionDeletionEvidence {
    SessionDeletionEvidence(
      id: .init(rawValue: id),
      sessionID: .init(rawValue: sessionID),
      kitchenID: .init(rawValue: kitchenID),
      deletedAt: deletedAt,
      sessionHeadsFormatVersion: sessionHeadsFormatVersion,
      sessionHeadsData: sessionHeadsData,
      dispositionHeadsFormatVersion: dispositionHeadsFormatVersion,
      dispositionHeadsData: dispositionHeadsData
    )
  }
}

extension SessionDeletionResolutionRecord {
  var evidence: SessionDeletionResolutionEvidence {
    SessionDeletionResolutionEvidence(
      id: .init(rawValue: id),
      deletionID: .init(rawValue: deletionID),
      sessionID: .init(rawValue: sessionID),
      kitchenID: .init(rawValue: kitchenID),
      restoredAt: restoredAt,
      dispositionHeadsFormatVersion: dispositionHeadsFormatVersion,
      dispositionHeadsData: dispositionHeadsData
    )
  }
}

extension UUID {
  fileprivate var isZero: Bool {
    self == UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
  }
}
