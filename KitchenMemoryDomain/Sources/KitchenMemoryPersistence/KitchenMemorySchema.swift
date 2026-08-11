// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

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

  /// Creates a container suitable for the app or for an in-memory test.
  public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
    let schema = Schema(models)
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
    return try ModelContainer(for: schema, configurations: [configuration])
  }
}
