// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemoryPersistence
import CoreData
import Foundation
import KitchenMemoryDomain
import SwiftData
import XCTest

@MainActor
final class KitchenMemorySchemaSynchronizationTests: XCTestCase {
  func testV3AddsExactlyTheFiveFrozenCookingSessionRecordFamilies() {
    let v2Names = Set(KitchenMemorySchemaV2.models.map { String(describing: $0) })
    let v3Names = Set(KitchenMemorySchemaV3.models.map { String(describing: $0) })

    XCTAssertEqual(
      v3Names.subtracting(v2Names),
      [
        "CookingSessionRecord",
        "SessionClosureRecord",
        "SessionDeletionRecord",
        "SessionDeletionResolutionRecord",
        "SessionFactRecord",
      ]
    )
    XCTAssertEqual(KitchenMemorySchemaV3.models.count, KitchenMemorySchemaV2.models.count + 5)
  }

  func testV3GeneratedSessionSchemaMatchesTheFrozenPhysicalContract() throws {
    let model = try XCTUnwrap(
      NSManagedObjectModel.makeManagedObjectModel(for: KitchenMemorySchemaV3.models)
    )
    let expectedFields: [String: Set<String>] = [
      "CookingSessionRecord": [
        "id", "kitchenID", "recipeID", "recipeRevisionID", "startedAt",
        "snapshotFormatVersion", "snapshotData", "snapshotDigest",
        "sourceSessionID", "sourceClosureID",
      ],
      "SessionFactRecord": [
        "id", "sessionID", "kitchenID", "kind", "targetSnapshotElementID",
        "authoredAt", "causalHeadsFormatVersion", "causalHeadsData",
        "payloadFormatVersion", "payloadData", "payloadDigest",
      ],
      "SessionClosureRecord": [
        "id", "sessionID", "kitchenID", "finishedAt", "causalHeadsFormatVersion",
        "causalHeadsData", "snapshotFormatVersion", "snapshotDigest",
        "projectionFormatVersion", "projectionDigest", "outcomeFormatVersion",
        "outcomeData",
      ],
      "SessionDeletionRecord": [
        "id", "sessionID", "kitchenID", "deletedAt", "sessionHeadsFormatVersion",
        "sessionHeadsData", "dispositionHeadsFormatVersion", "dispositionHeadsData",
      ],
      "SessionDeletionResolutionRecord": [
        "id", "deletionID", "sessionID", "kitchenID", "restoredAt",
        "dispositionHeadsFormatVersion", "dispositionHeadsData",
      ],
    ]

    for (name, fields) in expectedFields {
      let entity = try XCTUnwrap(model.entitiesByName[name])
      XCTAssertEqual(Set(entity.attributesByName.keys), fields, name)
      XCTAssertTrue(entity.relationshipsByName.isEmpty, name)
      XCTAssertTrue(entity.uniquenessConstraints.isEmpty, name)
      XCTAssertTrue(entity.indexes.isEmpty, name)
      XCTAssertTrue(
        entity.attributesByName.values.allSatisfy {
          !$0.allowsExternalBinaryDataStorage
        },
        name
      )
    }
  }

  func testLocalConfigurationDisablesCloudKit() throws {
    let configuration = try KitchenMemorySchema.makeConfiguration(
      schema: Schema(versionedSchema: KitchenMemorySchemaV1.self),
      inMemory: true,
      storeURL: nil,
      synchronization: .localOnly
    )

    XCTAssertTrue(configuration.isStoredInMemoryOnly)
    XCTAssertNil(configuration.cloudKitContainerIdentifier)
  }

  func testPersonalCloudConfigurationUsesTheNamedPrivateContainer() throws {
    let configuration = try KitchenMemorySchema.makeConfiguration(
      schema: Schema(versionedSchema: KitchenMemorySchemaV1.self),
      inMemory: false,
      storeURL: nil,
      synchronization: .personalCloud(containerIdentifier: "iCloud.example.Kitchen")
    )

    XCTAssertFalse(configuration.isStoredInMemoryOnly)
    XCTAssertEqual(configuration.cloudKitContainerIdentifier, "iCloud.example.Kitchen")
  }

  func testLocalAndPersonalCloudConfigurationsUseTheSameDurableStore() throws {
    let schema = Schema(versionedSchema: KitchenMemorySchemaV2.self)
    let localConfiguration = try KitchenMemorySchema.makeConfiguration(
      schema: schema,
      inMemory: false,
      storeURL: nil,
      synchronization: .localOnly
    )
    let cloudConfiguration = try KitchenMemorySchema.makeConfiguration(
      schema: schema,
      inMemory: false,
      storeURL: nil,
      synchronization: .personalCloud(containerIdentifier: "iCloud.example.Kitchen")
    )

    XCTAssertEqual(localConfiguration.url, cloudConfiguration.url)
  }

  func testLocalOnlyChangesRemainInHistoryForFutureCloudReconnection() throws {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "KitchenMemoryCloudReconnectionHistoryTests")
      .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storeURL = directory.appending(path: "KitchenMemory.store")

    do {
      let container = try KitchenMemorySchema.makeContainer(storeURL: storeURL)
      let repository = SwiftDataRecipeRepository(modelContainer: container)
      try repository.save(Kitchen(name: "Offline kitchen"))
    }

    let reopenedContainer = try KitchenMemorySchema.makeContainer(storeURL: storeURL)
    let history = try ModelContext(reopenedContainer).fetchHistory(
      HistoryDescriptor<DefaultHistoryTransaction>()
    )

    XCTAssertFalse(history.isEmpty)
  }

  func testPersonalCloudRejectsDisposableAndExplicitlyLocatedStores() throws {
    let schema = Schema(versionedSchema: KitchenMemorySchemaV1.self)
    let temporaryURL = FileManager.default.temporaryDirectory.appending(path: "Kitchen.store")

    XCTAssertThrowsError(try KitchenMemorySchema.makeConfiguration(
      schema: schema,
      inMemory: true,
      storeURL: nil,
      synchronization: .personalCloud(containerIdentifier: "iCloud.example.Kitchen")
    )) { error in
      XCTAssertEqual(
        error as? KitchenMemorySchemaError,
        .cloudRequiresDefaultStore
      )
    }
    XCTAssertThrowsError(try KitchenMemorySchema.makeConfiguration(
      schema: schema,
      inMemory: false,
      storeURL: temporaryURL,
      synchronization: .personalCloud(containerIdentifier: "iCloud.example.Kitchen")
    )) { error in
      XCTAssertEqual(
        error as? KitchenMemorySchemaError,
        .cloudRequiresDefaultStore
      )
    }
  }

  func testExplicitLocalStoreRetainsItsRequestedURL() throws {
    let storeURL = FileManager.default.temporaryDirectory.appending(path: "Explicit.store")
    let configuration = try KitchenMemorySchema.makeConfiguration(
      schema: Schema(versionedSchema: KitchenMemorySchemaV1.self),
      inMemory: false,
      storeURL: storeURL,
      synchronization: .localOnly
    )

    XCTAssertEqual(configuration.url, storeURL)
    XCTAssertNil(configuration.cloudKitContainerIdentifier)
  }

  func testReleasedV1StoreMigratesWithoutChangingRecipeContent() throws {
    let fixture = try MigrationFixtureStore.make(version: .releasedV1, title: "V1 Soup")
    defer { fixture.remove() }
    let migratedContainer = try KitchenMemorySchema.makeContainer(storeURL: fixture.storeURL)
    let repository = SwiftDataRecipeRepository(modelContainer: migratedContainer)
    let stored = try XCTUnwrap(
      repository.recipe(id: Recipe.ID(rawValue: fixture.recipeID))
    )

    XCTAssertEqual(migratedContainer.schema.version, Schema.Version(3, 0, 0))
    XCTAssertEqual(stored.revision.title, "V1 Soup")
    XCTAssertTrue(
      try ModelContext(migratedContainer)
        .fetch(FetchDescriptor<RecipeDeletionRecord>())
        .isEmpty
    )
  }

  func testReleasedV2StoreMigratesWithDeletionAndRestorationEvidenceIntact() throws {
    let fixture = try MigrationFixtureStore.make(version: .releasedV2, title: "V2 Soup")
    defer { fixture.remove() }
    let migratedContainer = try KitchenMemorySchema.makeContainer(storeURL: fixture.storeURL)
    let repository = SwiftDataRecipeRepository(modelContainer: migratedContainer)

    XCTAssertEqual(migratedContainer.schema.version, Schema.Version(3, 0, 0))
    XCTAssertEqual(
      try repository.recipe(id: Recipe.ID(rawValue: fixture.recipeID))?.revision.title,
      "V2 Soup"
    )
    let context = ModelContext(migratedContainer)
    XCTAssertEqual(try context.fetch(FetchDescriptor<RecipeDeletionRecord>()).map(\.id), [
      try XCTUnwrap(fixture.deletionID),
    ])
    XCTAssertEqual(
      try context.fetch(FetchDescriptor<RecipeDeletionResolutionRecord>()).map(\.id),
      [try XCTUnwrap(fixture.resolutionID)]
    )
    XCTAssertTrue(try context.fetch(FetchDescriptor<CookingSessionRecord>()).isEmpty)
  }
}
