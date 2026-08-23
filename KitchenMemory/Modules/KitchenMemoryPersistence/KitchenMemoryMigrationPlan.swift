// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import SwiftData

/// The first persisted Kitchen Memory schema.
///
/// This pre-release schema intentionally remains mutable while Kitchen Memory
/// has no external users. A change to V1 requires deleting development stores.
/// After the first release, this type becomes immutable and later changes add
/// a new schema plus a migration stage.
public enum KitchenMemorySchemaV1: VersionedSchema {
  public static let versionIdentifier = Schema.Version(1, 0, 0)

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
}

/// The ordered migration path for Kitchen Memory's private local store.
///
/// V1 is the only schema in this source tree. There is deliberately no
/// migration stage while development stores are disposable.
public enum KitchenMemoryMigrationPlan: SchemaMigrationPlan {
  public static let schemas: [any VersionedSchema.Type] = [
    KitchenMemorySchemaV1.self
  ]

  public static let stages: [MigrationStage] = []
}
