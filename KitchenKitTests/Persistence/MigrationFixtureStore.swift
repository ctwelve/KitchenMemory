// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import SwiftData

@MainActor
struct MigrationFixtureStore {
  enum ReleasedVersion: Equatable {
    case releasedV1
    case releasedV2
  }

  let directory: URL
  let storeURL: URL
  let kitchenID: UUID
  let recipeID: UUID
  let revisionID: UUID
  let olderRevisionID: UUID
  let deletionID: UUID?
  let resolutionID: UUID?

  static func make(version: ReleasedVersion, title: String) throws -> Self {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: "KitchenMemoryMigrationFixtures")
      .appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fixture = Self(
      directory: directory,
      storeURL: directory.appending(path: "KitchenMemory.store"),
      kitchenID: UUID(),
      recipeID: UUID(),
      revisionID: UUID(),
      olderRevisionID: UUID(),
      deletionID: version == .releasedV2 ? UUID() : nil,
      resolutionID: version == .releasedV2 ? UUID() : nil
    )
    try fixture.populate(version: version, title: title)
    return fixture
  }

  func remove() {
    try? FileManager.default.removeItem(at: directory)
  }

  // One authored graph keeps the released-store fixture reviewable as a whole.
  // swiftlint:disable:next function_body_length
  private func populate(version: ReleasedVersion, title: String) throws {
    let schema: Schema
    switch version {
    case .releasedV1: schema = Schema(versionedSchema: KitchenMemorySchemaV1.self)
    case .releasedV2: schema = Schema(versionedSchema: KitchenMemorySchemaV2.self)
    }
    let configuration = ModelConfiguration(
      "KitchenMemory",
      schema: schema,
      url: storeURL,
      cloudKitDatabase: .none
    )
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let context = ModelContext(container)
    guard let sourceURL = URL(string: "https://example.com/fixture-soup") else {
      preconditionFailure("Static fixture URL must be valid")
    }
    let sourceData = try JSONEncoder().encode(
      FixtureStoredSource(
        source: RecipeSource(kind: .webpage, title: "Fixture Source", canonicalURL: sourceURL),
        capture: RecipeSourceCapture(
          kind: .schemaOrgJSONLD,
          sourceURL: sourceURL,
          capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
          mediaType: "application/ld+json",
          payload: Data("{\"name\":\"Fixture Soup\"}".utf8),
          blockIndex: 1,
          objectIndex: 2
        )
      )
    )
    context.insert(KitchenRecord(id: kitchenID, name: "Fixture Kitchen"))
    context.insert(
      RecipeRecord(id: recipeID, kitchenID: kitchenID, currentRevisionID: revisionID)
    )
    context.insert(
      RecipeRevisionRecord(
        id: revisionID,
        recipeID: recipeID,
        revisionNumber: 2,
        title: title,
        summary: "Preserved summary",
        authorName: "Fixture Author",
        contentLanguage: "en-US",
        sourceData: sourceData,
        yieldData: nil,
        prepSeconds: 60,
        cookSeconds: 120,
        totalSeconds: 180,
        cuisinesData: Data("[]".utf8),
        categoriesData: Data("[]".utf8),
        keywordsData: Data("[]".utf8)
      )
    )
    context.insert(
      RecipeRevisionRecord(
        id: olderRevisionID,
        recipeID: recipeID,
        revisionNumber: 1,
        title: "Original \(title)",
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
    let ingredientSectionID = UUID()
    let instructionSectionID = UUID()
    context.insert(RecipeMediaRecord(
      id: UUID(), revisionID: revisionID, sortIndex: 0, role: "hero",
      assetName: "fixture-soup", accessibilityLabel: "A bowl of soup"
    ))
    context.insert(EquipmentRecord(
      id: UUID(), revisionID: revisionID, sortIndex: 0, originalText: "1 soup pot",
      quantityData: nil, name: "soup pot", isOptional: false
    ))
    context.insert(IngredientSectionRecord(
      id: ingredientSectionID, revisionID: revisionID, sortIndex: 0, title: "Soup"
    ))
    context.insert(RecipeIngredientRecord(
      id: UUID(), sectionID: ingredientSectionID, sortIndex: 0,
      originalText: "1 onion, diced", presentationMode: "original",
      customDisplayText: nil, quantityData: nil, unitText: nil, packageData: nil,
      ingredientText: "onion", preparation: "diced", note: "keep authored text",
      isOptional: false, scalingBehavior: "linear", parseState: "reviewed"
    ))
    context.insert(InstructionSectionRecord(
      id: instructionSectionID, revisionID: revisionID, sortIndex: 0, title: "Cook"
    ))
    context.insert(InstructionStepRecord(
      id: UUID(), sectionID: instructionSectionID, sortIndex: 0, name: "Simmer",
      text: "Simmer gently.", durationSeconds: 600, temperatureData: nil
    ))
    if let deletionID, let resolutionID {
      context.insert(
        RecipeDeletionRecord(id: deletionID, recipeID: recipeID, kitchenID: kitchenID)
      )
      context.insert(
        RecipeDeletionResolutionRecord(
          id: resolutionID,
          deletionID: deletionID,
          recipeID: recipeID
        )
      )
    }
    try context.save()
  }
}

private struct FixtureStoredSource: Codable {
  let source: RecipeSource?
  let capture: RecipeSourceCapture
}
