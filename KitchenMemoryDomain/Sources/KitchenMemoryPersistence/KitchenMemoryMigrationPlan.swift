// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import SwiftData

/// The first persisted Kitchen Memory schema.
///
/// Keep this version immutable after it has been released. Future versions add
/// their own schema type and a migration stage to ``KitchenMemoryMigrationPlan``.
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
/// V1 is the only released schema in this source tree, so no migration stage
/// exists yet. The plan is installed now to make the next schema change a
/// deliberate compatibility decision rather than an implicit store rewrite.
public enum KitchenMemoryMigrationPlan: SchemaMigrationPlan {
  public static let schemas: [any VersionedSchema.Type] = [
    KitchenMemorySchemaV1.self
  ]

  public static let stages: [MigrationStage] = []
}
