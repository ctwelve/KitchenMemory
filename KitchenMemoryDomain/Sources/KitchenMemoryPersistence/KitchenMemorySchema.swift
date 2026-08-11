// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import SwiftData

/// Access to Kitchen Memory's current versioned SwiftData schema.
///
/// App setup, previews, and tests use the same migration plan. Add a new
/// immutable ``VersionedSchema`` and an explicit stage when this store evolves.
public enum KitchenMemorySchema {
  /// Creates an in-memory test container or the app's durable local container.
  ///
  /// The default persistent location remains SwiftData-managed. Persistent
  /// stores are local-only for this slice: CloudKit is selected at the
  /// synchronization boundary later, rather than enabled implicitly here.
  public static func makeContainer(
    inMemory: Bool = false,
    storeURL: URL? = nil
  ) throws -> ModelContainer {
    let schema = Schema(versionedSchema: KitchenMemorySchemaV1.self)
    let configuration: ModelConfiguration
    if let storeURL {
      configuration = ModelConfiguration(
        "KitchenMemory",
        schema: schema,
        url: storeURL,
        cloudKitDatabase: .none
      )
    } else {
      configuration = ModelConfiguration(
        "KitchenMemory",
        schema: schema,
        isStoredInMemoryOnly: inMemory,
        cloudKitDatabase: .none
      )
    }
    return try ModelContainer(
      for: schema,
      migrationPlan: KitchenMemoryMigrationPlan.self,
      configurations: [configuration]
    )
  }
}
