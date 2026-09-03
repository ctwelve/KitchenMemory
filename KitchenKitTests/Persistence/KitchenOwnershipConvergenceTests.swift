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
    XCTAssertEqual(try reader.fetch(FetchDescriptor<RecipeSaveRecord>()).map(\.kitchenID), [destinationID])
    XCTAssertEqual(
      try reader.fetch(FetchDescriptor<RecipeSelectionRecord>()).map(\.kitchenID),
      [destinationID]
    )
    XCTAssertEqual(try reader.fetch(FetchDescriptor<RecipePruneRecord>()).map(\.kitchenID), [destinationID])
    XCTAssertEqual(
      try reader.fetch(FetchDescriptor<RecipeDeletionResolutionRecord>()).map(\.kitchenID),
      [destinationID]
    )
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

  func testRepeatedConvergencePreservesSettledOwnershipEvidence() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let context = ModelContext(container)
    let ownerID = KitchenOwner.ID(rawValue: "cloudkit:production:current-user")
    let personalKitchen = Kitchen(
      id: KitchenBootstrapService.personalKitchenID,
      ownerID: ownerID,
      name: "Home"
    )
    context.insert(KitchenRecord(id: personalKitchen.id.rawValue, name: "Old Name"))
    context.insert(KitchenOwnershipRecord(
      id: personalKitchen.id.rawValue,
      kitchenID: personalKitchen.id.rawValue,
      ownerID: ownerID.rawValue
    ))
    context.insert(KitchenOwnershipRecord(
      id: UUID(),
      kitchenID: personalKitchen.id.rawValue,
      ownerID: ownerID.rawValue
    ))
    try context.save()
    let canonicalOwnership = try XCTUnwrap(
      context.fetch(FetchDescriptor<KitchenOwnershipRecord>())
        .first { $0.id == personalKitchen.id.rawValue }
    )
    let firstPersistentID = canonicalOwnership.persistentModelID
    let repository = SwiftDataRecipeRepository(modelContainer: container)

    try repository.convergeKitchens(into: personalKitchen, ownedBy: ownerID)
    try repository.convergeKitchens(into: personalKitchen, ownedBy: ownerID)
    let secondReader = ModelContext(container)
    let secondOwnership = try XCTUnwrap(
      secondReader.fetch(FetchDescriptor<KitchenOwnershipRecord>()).first
    )

    XCTAssertEqual(secondOwnership.persistentModelID, firstPersistentID)
    XCTAssertEqual(
      try secondReader.fetchCount(FetchDescriptor<KitchenOwnershipRecord>()),
      1
    )
    XCTAssertEqual(try repository.kitchen(id: personalKitchen.id), personalKitchen)
  }

  // One fixture intentionally enumerates every Kitchen-routed persistence family.
  // swiftlint:disable:next function_body_length
  private func insertKitchenScopedEvidence(into context: ModelContext, kitchenID: UUID) {
    let sessionID = UUID()
    context.insert(RecipeDeletionRecord(
      id: UUID(),
      recipeID: UUID(),
      kitchenID: kitchenID
    ))
    let recipeID = UUID()
    context.insert(RecipeSaveRecord(
      id: UUID(), kitchenID: kitchenID, recipeID: recipeID, revisionID: UUID(),
      savedAt: .distantPast, ancestryFormatVersion: 1, parentRevisionIDsData: Data(),
      payloadManifestFormatVersion: 1, payloadManifestData: Data(),
      revisionFormatVersion: 1, revisionDigest: Data()
    ))
    context.insert(RecipeSelectionRecord(
      id: UUID(), kitchenID: kitchenID, recipeID: recipeID,
      selectedRevisionID: UUID(), selectedAt: .distantPast,
      frontierFormatVersion: 1, observedSelectionIDsData: Data()
    ))
    context.insert(RecipePruneRecord(
      id: UUID(), kitchenID: kitchenID, recipeID: recipeID,
      prunedAt: .distantPast, antiResurrectionUntil: .distantFuture,
      frontierFormatVersion: 1, frontierData: Data(), frontierDigest: Data()
    ))
    context.insert(RecipeDeletionResolutionRecord(
      id: UUID(), deletionID: UUID(), recipeID: recipeID, kitchenID: kitchenID
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
