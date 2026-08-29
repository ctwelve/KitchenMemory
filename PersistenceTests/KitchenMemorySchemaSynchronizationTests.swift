// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemoryPersistence
import CoreData
import Foundation
import KitchenMemoryDomain
import SwiftData
import XCTest

// Frozen V1/V2/V3 manifests are intentionally explicit compatibility evidence.
// swiftlint:disable file_length

@MainActor
// swiftlint:disable:next type_body_length
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

  // Keeping the complete released manifest together makes field drift visible.
  // swiftlint:disable:next function_body_length
  func testReleasedV1AndV2GeneratedSchemasRemainFrozen() throws {
    let model = try XCTUnwrap(
      NSManagedObjectModel.makeManagedObjectModel(for: KitchenMemorySchemaV2.models)
    )
    let expectedTypes: [String: [String: NSAttributeType]] = [
      "KitchenRecord": ["id": .UUIDAttributeType, "name": .stringAttributeType],
      "RecipeRecord": [
        "id": .UUIDAttributeType, "kitchenID": .UUIDAttributeType,
        "currentRevisionID": .UUIDAttributeType,
      ],
      "RecipeRevisionRecord": [
        "id": .UUIDAttributeType, "recipeID": .UUIDAttributeType,
        "revisionNumber": .integer64AttributeType, "title": .stringAttributeType,
        "summary": .stringAttributeType, "authorName": .stringAttributeType,
        "contentLanguage": .stringAttributeType, "sourceData": .binaryDataAttributeType,
        "yieldData": .binaryDataAttributeType, "prepSeconds": .integer64AttributeType,
        "cookSeconds": .integer64AttributeType, "totalSeconds": .integer64AttributeType,
        "cuisinesData": .binaryDataAttributeType, "categoriesData": .binaryDataAttributeType,
        "keywordsData": .binaryDataAttributeType,
      ],
      "RecipeMediaRecord": [
        "id": .UUIDAttributeType, "revisionID": .UUIDAttributeType,
        "sortIndex": .integer64AttributeType, "role": .stringAttributeType,
        "assetName": .stringAttributeType, "mediaAccessibilityLabel": .stringAttributeType,
      ],
      "EquipmentRecord": [
        "id": .UUIDAttributeType, "revisionID": .UUIDAttributeType,
        "sortIndex": .integer64AttributeType, "originalText": .stringAttributeType,
        "quantityData": .binaryDataAttributeType, "name": .stringAttributeType,
        "isOptional": .booleanAttributeType,
      ],
      "IngredientSectionRecord": [
        "id": .UUIDAttributeType, "revisionID": .UUIDAttributeType,
        "sortIndex": .integer64AttributeType, "title": .stringAttributeType,
      ],
      "RecipeIngredientRecord": [
        "id": .UUIDAttributeType, "sectionID": .UUIDAttributeType,
        "sortIndex": .integer64AttributeType, "originalText": .stringAttributeType,
        "presentationMode": .stringAttributeType, "customDisplayText": .stringAttributeType,
        "quantityData": .binaryDataAttributeType, "unitText": .stringAttributeType,
        "packageData": .binaryDataAttributeType, "ingredientText": .stringAttributeType,
        "preparation": .stringAttributeType, "note": .stringAttributeType,
        "isOptional": .booleanAttributeType, "scalingBehavior": .stringAttributeType,
        "parseState": .stringAttributeType,
      ],
      "InstructionSectionRecord": [
        "id": .UUIDAttributeType, "revisionID": .UUIDAttributeType,
        "sortIndex": .integer64AttributeType, "title": .stringAttributeType,
      ],
      "InstructionStepRecord": [
        "id": .UUIDAttributeType, "sectionID": .UUIDAttributeType,
        "sortIndex": .integer64AttributeType, "name": .stringAttributeType,
        "text": .stringAttributeType, "durationSeconds": .integer64AttributeType,
        "temperatureData": .binaryDataAttributeType,
      ],
      "RecipeDeletionRecord": [
        "id": .UUIDAttributeType, "recipeID": .UUIDAttributeType,
        "kitchenID": .UUIDAttributeType,
      ],
      "RecipeDeletionResolutionRecord": [
        "id": .UUIDAttributeType, "deletionID": .UUIDAttributeType,
        "recipeID": .UUIDAttributeType,
      ],
    ]
    let optionalFields: [String: Set<String>] = [
      "RecipeRevisionRecord": [
        "summary", "authorName", "contentLanguage", "sourceData", "yieldData",
        "prepSeconds", "cookSeconds", "totalSeconds",
      ],
      "RecipeMediaRecord": ["mediaAccessibilityLabel"],
      "EquipmentRecord": ["quantityData"],
      "IngredientSectionRecord": ["title"],
      "RecipeIngredientRecord": [
        "customDisplayText", "quantityData", "unitText", "packageData",
        "ingredientText", "preparation", "note",
      ],
      "InstructionSectionRecord": ["title"],
      "InstructionStepRecord": ["name", "durationSeconds", "temperatureData"],
    ]

    XCTAssertEqual(Set(model.entitiesByName.keys), Set(expectedTypes.keys))
    for (entityName, fields) in expectedTypes {
      let entity = try XCTUnwrap(model.entitiesByName[entityName])
      XCTAssertEqual(Set(entity.attributesByName.keys), Set(fields.keys), entityName)
      XCTAssertTrue(entity.relationshipsByName.isEmpty, entityName)
      for (fieldName, type) in fields {
        let attribute = try XCTUnwrap(entity.attributesByName[fieldName])
        XCTAssertEqual(attribute.attributeType, type, "\(entityName).\(fieldName)")
        XCTAssertEqual(
          attribute.isOptional,
          optionalFields[entityName, default: []].contains(fieldName),
          "\(entityName).\(fieldName)"
        )
      }
    }
    XCTAssertEqual(
      model.entitiesByName["RecipeMediaRecord"]?
        .attributesByName["mediaAccessibilityLabel"]?.renamingIdentifier,
      "accessibilityLabel"
    )
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
    try assertFixtureGraph(repository, fixture: fixture, title: "V1 Soup")
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
    try assertFixtureGraph(repository, fixture: fixture, title: "V2 Soup")
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

  func testInterruptedV2ToV3MigrationLeavesTheReleasedStoreRecoverable() throws {
    let fixture = try MigrationFixtureStore.make(version: .releasedV2, title: "Interrupted Soup")
    defer { fixture.remove() }
    let v3Schema = Schema(versionedSchema: KitchenMemorySchemaV3.self)
    let interruptedConfiguration = ModelConfiguration(
      "KitchenMemory",
      schema: v3Schema,
      url: fixture.storeURL,
      cloudKitDatabase: .none
    )

    XCTAssertThrowsError(try ModelContainer(
      for: v3Schema,
      migrationPlan: InterruptedV3MigrationPlan.self,
      configurations: [interruptedConfiguration]
    ))

    do {
      let v2Schema = Schema(versionedSchema: KitchenMemorySchemaV2.self)
      let configuration = ModelConfiguration(
        "KitchenMemory",
        schema: v2Schema,
        url: fixture.storeURL,
        cloudKitDatabase: .none
      )
      let releasedContainer = try ModelContainer(
        for: v2Schema,
        configurations: [configuration]
      )
      let revisions = try ModelContext(releasedContainer).fetch(
        FetchDescriptor<RecipeRevisionRecord>()
      )
      XCTAssertEqual(
        Set(revisions.map(\.title)),
        ["Interrupted Soup", "Original Interrupted Soup"]
      )
    }

    let migratedContainer = try KitchenMemorySchema.makeContainer(storeURL: fixture.storeURL)
    XCTAssertEqual(migratedContainer.schema.version, Schema.Version(3, 0, 0))
  }

  private func assertFixtureGraph(
    _ repository: SwiftDataRecipeRepository,
    fixture: MigrationFixtureStore,
    title: String
  ) throws {
    let stored = try XCTUnwrap(repository.recipe(id: Recipe.ID(rawValue: fixture.recipeID)))
    XCTAssertEqual(stored.revision.title, title)
    XCTAssertEqual(stored.revision.source?.canonicalURL?.absoluteString, "https://example.com/fixture-soup")
    XCTAssertEqual(stored.revision.sourceCapture?.payload, Data("{\"name\":\"Fixture Soup\"}".utf8))
    XCTAssertEqual(stored.revision.media.map(\.assetName), ["fixture-soup"])
    XCTAssertEqual(stored.revision.equipment.map(\.originalText), ["1 soup pot"])
    XCTAssertEqual(
      stored.revision.ingredientSections.flatMap(\.ingredients).map(\.originalText),
      ["1 onion, diced"]
    )
    XCTAssertEqual(
      stored.revision.instructionSections.flatMap(\.steps).map(\.text),
      ["Simmer gently."]
    )
    XCTAssertEqual(
      try repository.revisions(for: Recipe.ID(rawValue: fixture.recipeID)).map(\.id.rawValue),
      [fixture.revisionID, fixture.olderRevisionID]
    )
  }
}

private enum InjectedMigrationError: Error, Equatable {
  case interrupted
}

private enum InterruptedV3MigrationPlan: SchemaMigrationPlan {
  static var schemas: [any VersionedSchema.Type] {
    [KitchenMemorySchemaV2.self, KitchenMemorySchemaV3.self]
  }

  static var stages: [MigrationStage] {
    [
      .custom(
        fromVersion: KitchenMemorySchemaV2.self,
        toVersion: KitchenMemorySchemaV3.self,
        willMigrate: { _ in throw InjectedMigrationError.interrupted },
        didMigrate: nil
      ),
    ]
  }
}

// swiftlint:enable file_length
