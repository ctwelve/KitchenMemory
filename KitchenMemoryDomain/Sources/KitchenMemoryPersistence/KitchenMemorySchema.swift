// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import SwiftData

/// The complete SwiftData schema owned by the persistence module.
///
/// Keeping this list in one place makes app setup, previews, and tests use the
/// same schema. Add migrations here when the first shipped schema must evolve.
public enum KitchenMemorySchema {
  public static let models: [any PersistentModel.Type] = [
    KitchenRecord.self,
    RecipeRecord.self,
    RecipeRevisionRecord.self,
    RecipeMediaRecord.self,
    EquipmentRecord.self,
    IngredientSectionRecord.self,
    RecipeIngredientRecord.self,
    InstructionSectionRecord.self,
    InstructionStepRecord.self,
  ]

  /// Creates an in-memory test container or the app's durable local container.
  ///
  /// The default persistent location remains SwiftData-managed. Persistent
  /// stores are local-only for this slice: CloudKit is selected at the
  /// synchronization boundary later, rather than enabled implicitly here.
  public static func makeContainer(
    inMemory: Bool = false,
    storeURL: URL? = nil
  ) throws -> ModelContainer {
    let schema = Schema(models)
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
    return try ModelContainer(for: schema, configurations: [configuration])
  }
}
