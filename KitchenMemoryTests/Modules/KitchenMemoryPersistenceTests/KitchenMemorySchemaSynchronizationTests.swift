// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemoryPersistence
import Foundation
import SwiftData
import XCTest

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
}
