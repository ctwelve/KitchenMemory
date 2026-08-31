// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import SwiftData
import XCTest

@MainActor
final class KitchenOwnershipConvergenceTests: XCTestCase {
  func testConvergenceRehomesEveryKitchenScopedRecordAndCreatesPersonalKitchen() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let context = ModelContext(container)
    let legacyKitchenID = UUID()
    let ownerID = KitchenOwner.ID(rawValue: "cloudkit:production:current-user")
    context.insert(KitchenRecord(id: legacyKitchenID, name: "Legacy"))
    context.insert(KitchenOwnershipRecord(
      id: legacyKitchenID,
      kitchenID: legacyKitchenID,
      ownerID: ownerID.rawValue
    ))
    insertKitchenScopedEvidence(into: context, kitchenID: legacyKitchenID)
    try context.save()
    let repository = SwiftDataRecipeRepository(modelContainer: container)
    let personalKitchen = Kitchen(
      id: KitchenBootstrapService.personalKitchenID,
      ownerID: ownerID,
      name: "Legacy"
    )

    try repository.convergeKitchens(into: personalKitchen, ownedBy: ownerID)
    let renamedKitchen = Kitchen(id: personalKitchen.id, ownerID: ownerID, name: "Renamed")
    try repository.save(renamedKitchen)

    let reader = ModelContext(container)
    let destinationID = personalKitchen.id.rawValue
    XCTAssertEqual(try reader.fetch(FetchDescriptor<RecipeDeletionRecord>()).map(\.kitchenID), [destinationID])
    XCTAssertEqual(try reader.fetch(FetchDescriptor<CookingSessionRecord>()).map(\.kitchenID), [destinationID])
    XCTAssertEqual(try reader.fetch(FetchDescriptor<SessionFactRecord>()).map(\.kitchenID), [destinationID])
    XCTAssertEqual(try reader.fetch(FetchDescriptor<SessionClosureRecord>()).map(\.kitchenID), [destinationID])
    XCTAssertEqual(try reader.fetch(FetchDescriptor<SessionDeletionRecord>()).map(\.kitchenID), [destinationID])
    XCTAssertEqual(
      try reader.fetch(FetchDescriptor<SessionDeletionResolutionRecord>()).map(\.kitchenID),
      [destinationID]
    )
    XCTAssertEqual(try repository.kitchens(), [renamedKitchen])
  }

  func testKitchenReadRejectsConflictingOwnerEvidence() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let context = ModelContext(container)
    let kitchenID = Kitchen.ID()
    context.insert(KitchenRecord(id: kitchenID.rawValue, name: "Home"))
    for owner in ["first", "second"] {
      context.insert(KitchenOwnershipRecord(
        id: UUID(),
        kitchenID: kitchenID.rawValue,
        ownerID: owner
      ))
    }
    try context.save()
    let repository = SwiftDataRecipeRepository(modelContainer: container)

    XCTAssertThrowsError(try repository.kitchen(id: kitchenID)) { error in
      XCTAssertEqual(
        error as? KitchenMemoryPersistenceError,
        .kitchenOwnedByAnotherOwner(kitchenID: kitchenID)
      )
    }
  }

  private func insertKitchenScopedEvidence(into context: ModelContext, kitchenID: UUID) {
    let sessionID = UUID()
    context.insert(RecipeDeletionRecord(
      id: UUID(),
      recipeID: UUID(),
      kitchenID: kitchenID
    ))
    context.insert(CookingSessionRecord(
      id: sessionID,
      kitchenID: kitchenID,
      recipeID: UUID(),
      recipeRevisionID: UUID(),
      startedAt: .now,
      snapshotFormatVersion: 1,
      snapshotData: Data(),
      snapshotDigest: Data(),
      sourceSessionID: nil,
      sourceClosureID: nil
    ))
    context.insert(SessionFactRecord(
      id: UUID(), sessionID: sessionID, kitchenID: kitchenID, kind: "note",
      targetSnapshotElementID: nil, authoredAt: .now,
      causalHeadsFormatVersion: 1, causalHeadsData: Data(),
      payloadFormatVersion: 1, payloadData: Data(), payloadDigest: Data()
    ))
    context.insert(SessionClosureRecord(
      id: UUID(), sessionID: sessionID, kitchenID: kitchenID, finishedAt: .now,
      causalHeadsFormatVersion: 1, causalHeadsData: Data(),
      snapshotFormatVersion: 1, snapshotDigest: Data(),
      projectionFormatVersion: 1, projectionDigest: Data(),
      outcomeFormatVersion: nil, outcomeData: nil
    ))
    context.insert(SessionDeletionRecord(
      id: UUID(), sessionID: sessionID, kitchenID: kitchenID, deletedAt: .now,
      sessionHeadsFormatVersion: 1, sessionHeadsData: Data(),
      dispositionHeadsFormatVersion: 1, dispositionHeadsData: Data()
    ))
    context.insert(SessionDeletionResolutionRecord(
      id: UUID(), deletionID: UUID(), sessionID: sessionID,
      kitchenID: kitchenID, restoredAt: .now,
      dispositionHeadsFormatVersion: 1, dispositionHeadsData: Data()
    ))
  }
}
