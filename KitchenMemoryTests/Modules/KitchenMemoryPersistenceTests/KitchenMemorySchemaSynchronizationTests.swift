// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemoryPersistence
import Foundation
import KitchenMemoryDomain
import SwiftData
import XCTest

@MainActor
final class KitchenMemorySchemaSynchronizationTests: XCTestCase {
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

  // swiftlint:disable:next function_body_length
  func testReleasedV1StoreMigratesWithoutChangingRecipeContent() throws {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "KitchenMemoryV1MigrationTests")
      .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let storeURL = directory.appending(path: "KitchenMemory.store")
    let kitchenID = UUID()
    let recipeID = UUID()
    let revisionID = UUID()

    do {
      let schema = Schema(versionedSchema: KitchenMemorySchemaV1.self)
      let configuration = ModelConfiguration(
        "KitchenMemory",
        schema: schema,
        url: storeURL,
        cloudKitDatabase: .none
      )
      let container = try ModelContainer(
        for: schema,
        configurations: [configuration]
      )
      let context = ModelContext(container)
      context.insert(KitchenRecord(id: kitchenID, name: "Home"))
      context.insert(
        RecipeRecord(
          id: recipeID,
          kitchenID: kitchenID,
          currentRevisionID: revisionID
        )
      )
      context.insert(
        RecipeRevisionRecord(
          id: revisionID,
          recipeID: recipeID,
          revisionNumber: 1,
          title: "V1 Soup",
          summary: nil,
          authorName: nil,
          contentLanguage: nil,
          sourceData: nil,
          yieldData: nil,
          prepSeconds: nil,
          cookSeconds: nil,
          totalSeconds: nil,
          cuisinesData: Data("[]".utf8),
          categoriesData: Data("[]".utf8),
          keywordsData: Data("[]".utf8)
        )
      )
      try context.save()
    }

    let migratedContainer = try KitchenMemorySchema.makeContainer(storeURL: storeURL)
    let repository = SwiftDataRecipeRepository(modelContainer: migratedContainer)
    let stored = try XCTUnwrap(
      repository.recipe(id: Recipe.ID(rawValue: recipeID))
    )

    XCTAssertEqual(migratedContainer.schema.version, Schema.Version(2, 0, 0))
    XCTAssertEqual(stored.revision.title, "V1 Soup")
    XCTAssertTrue(
      try ModelContext(migratedContainer)
        .fetch(FetchDescriptor<RecipeDeletionRecord>())
        .isEmpty
    )
  }
}
