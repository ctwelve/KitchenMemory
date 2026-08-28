// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

@testable import KitchenMemoryPersistence
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
      deletionID: version == .releasedV2 ? UUID() : nil,
      resolutionID: version == .releasedV2 ? UUID() : nil
    )
    try fixture.populate(version: version, title: title)
    return fixture
  }

  func remove() {
    try? FileManager.default.removeItem(at: directory)
  }

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
    context.insert(KitchenRecord(id: kitchenID, name: "Fixture Kitchen"))
    context.insert(
      RecipeRecord(id: recipeID, kitchenID: kitchenID, currentRevisionID: revisionID)
    )
    context.insert(
      RecipeRevisionRecord(
        id: revisionID,
        recipeID: recipeID,
        revisionNumber: 1,
        title: title,
        summary: "Preserved summary",
        authorName: "Fixture Author",
        contentLanguage: "en-US",
        sourceData: nil,
        yieldData: nil,
        prepSeconds: 60,
        cookSeconds: 120,
        totalSeconds: 180,
        cuisinesData: Data("[]".utf8),
        categoriesData: Data("[]".utf8),
        keywordsData: Data("[]".utf8)
      )
    )
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
