// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import SwiftData

/// The immutable schema shipped by Kitchen Memory 0.1.0.
///
/// Published local and CloudKit names remain frozen. Every later change adds a
/// new schema and migration stage rather than editing this definition.
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

/// Adds durable recipe-deletion intent and observed restoration records.
///
/// V1's recipe graph remains byte-for-byte compatible. The two new additive
/// record types let every repository read converge after disconnected devices
/// exchange edits and deletions without changing Domain values.
public enum KitchenMemorySchemaV2: VersionedSchema {
  public static let versionIdentifier = Schema.Version(2, 0, 0)

  public static let models: [any PersistentModel.Type] = [
    KitchenRecord.self,
    RecipeRecord.self,
    RecipeDeletionRecord.self,
    RecipeDeletionResolutionRecord.self,
    RecipeRevisionRecord.self,
    RecipeMediaRecord.self,
    EquipmentRecord.self,
    IngredientSectionRecord.self,
    RecipeIngredientRecord.self,
    InstructionSectionRecord.self,
    InstructionStepRecord.self,
  ]
}

/// Adds immutable Cooking Session document evidence without changing V2 rows.
public enum KitchenMemorySchemaV3: VersionedSchema {
  public static let versionIdentifier = Schema.Version(3, 0, 0)

  public static let models: [any PersistentModel.Type] = KitchenMemorySchemaV2.models + [
    CookingSessionRecord.self,
    SessionFactRecord.self,
    SessionClosureRecord.self,
    SessionDeletionRecord.self,
    SessionDeletionResolutionRecord.self,
  ]
}

/// The ordered migration path for Kitchen Memory's private local store.
///
/// Released V1 stores migrate additively to V2; neither existing recipe rows
/// nor the deployed V1 CloudKit record types are renamed or repurposed.
public enum KitchenMemoryMigrationPlan: SchemaMigrationPlan {
  public static let schemas: [any VersionedSchema.Type] = [
    KitchenMemorySchemaV1.self,
    KitchenMemorySchemaV2.self,
    KitchenMemorySchemaV3.self,
  ]

  public static let stages: [MigrationStage] = [
    .lightweight(fromVersion: KitchenMemorySchemaV1.self, toVersion: KitchenMemorySchemaV2.self),
    .lightweight(fromVersion: KitchenMemorySchemaV2.self, toVersion: KitchenMemorySchemaV3.self),
  ]
}
