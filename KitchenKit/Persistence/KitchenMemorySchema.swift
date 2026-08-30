// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

/// Selects whether a durable Kitchen Memory store participates in personal sync.
///
/// This is deliberately a persistence concern. Domain values and repository
/// callers never need to know whether CloudKit moves their records between
/// devices, and a future shared-Kitchen adapter can use a different mechanism.
public enum KitchenMemoryStoreSynchronization: Equatable, Sendable {
  case localOnly
  case personalCloud(containerIdentifier: String)
}

public enum KitchenMemorySchemaError: Error, Equatable {
  case cloudRequiresDefaultStore
}

public enum KitchenMemorySchema {
  /// Creates an in-memory test container or the app's durable container.
  ///
  /// Tests and explicitly located stores remain local. The application opts its
  /// standard durable store into private CloudKit synchronization at its
  /// composition root rather than making cloud behavior an implicit framework
  /// default.
  public static func makeContainer(
    inMemory: Bool = false,
    storeURL: URL? = nil,
    synchronization: KitchenMemoryStoreSynchronization = .localOnly
  ) throws -> ModelContainer {
    let schema = Schema(versionedSchema: KitchenMemorySchemaV3.self)
    let configuration = try makeConfiguration(
      schema: schema,
      inMemory: inMemory,
      storeURL: storeURL,
      synchronization: synchronization
    )
    return try ModelContainer(
      for: schema,
      migrationPlan: KitchenMemoryMigrationPlan.self,
      configurations: [configuration]
    )
  }

  static func makeConfiguration(
    schema: Schema,
    inMemory: Bool,
    storeURL: URL?,
    synchronization: KitchenMemoryStoreSynchronization
  ) throws -> ModelConfiguration {
    let cloudKitDatabase: ModelConfiguration.CloudKitDatabase
    switch synchronization {
    case .localOnly:
      cloudKitDatabase = .none
    case let .personalCloud(containerIdentifier):
      guard !inMemory, storeURL == nil else {
        throw KitchenMemorySchemaError.cloudRequiresDefaultStore
      }
      cloudKitDatabase = .private(containerIdentifier)
    }

    if let storeURL {
      return ModelConfiguration(
        "KitchenMemory",
        schema: schema,
        url: storeURL,
        cloudKitDatabase: cloudKitDatabase
      )
    }
    return ModelConfiguration(
      "KitchenMemory",
      schema: schema,
      isStoredInMemoryOnly: inMemory,
      cloudKitDatabase: cloudKitDatabase
    )
  }
}
