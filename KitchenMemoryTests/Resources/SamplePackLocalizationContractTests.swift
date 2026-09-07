// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
@testable import KitchenMemory
import SwiftData
import XCTest

@MainActor
final class SamplePackLocalizationContractTests: XCTestCase {
  private let locales = ["en-US", "en-GB", "es-MX", "fr-CA", "de-DE"]

  func testEveryAuthoredVariantPreservesStructureProvenanceAndDistinctStableIdentity() throws {
    let manifest = try SampleRecipeCatalog.loadManifest()
    var identities: Set<UUID> = []
    XCTAssertEqual(Set(manifest.recipes.map(\.familyID)).count, manifest.recipes.count)
    for family in manifest.recipes {
      XCTAssertEqual(Set(family.variants.map(\.localeIdentifier)), Set(locales))
      let source = try SampleRecipeCatalog.loadRecipe(XCTUnwrap(family.variant(preferredLanguages: ["en-US"])))
      for variant in family.variants {
        let document = try SampleRecipeCatalog.loadRecipe(variant)
        XCTAssertEqual(try SampleRecipeCatalog.loadRecipe(variant), document)
        XCTAssertEqual(document.revision.contentLanguage?.rawValue, variant.localeIdentifier)
        XCTAssertEqual(document.recipeID, document.revision.recipeID)
        XCTAssertTrue(identities.insert(document.recipeID.rawValue).inserted)
        XCTAssertTrue(identities.insert(document.revision.id.rawValue).inserted)
        XCTAssertEqual(document.revision.ingredientSections.map { $0.ingredients.count },
          source.revision.ingredientSections.map { $0.ingredients.count })
        XCTAssertEqual(document.revision.instructionSections.map { $0.steps.count },
          source.revision.instructionSections.map { $0.steps.count })
        let childIDs = document.revision.ingredientSections.map(\.id.rawValue)
          + document.revision.ingredientSections.flatMap { $0.ingredients.map(\.id.rawValue) }
          + document.revision.instructionSections.map(\.id.rawValue)
          + document.revision.instructionSections.flatMap { $0.steps.map(\.id.rawValue) }
          + document.revision.media.map(\.id.rawValue) + document.revision.equipment.map(\.id.rawValue)
        for id in childIDs { XCTAssertTrue(identities.insert(id).inserted) }
        XCTAssertEqual(document.revision.equipment.count, source.revision.equipment.count)
        XCTAssertEqual(document.revision.media.map(\.assetName), source.revision.media.map(\.assetName))
        XCTAssertEqual(document.revision.source?.kind, source.revision.source?.kind)
        if source.revision.source != nil {
          XCTAssertFalse(try XCTUnwrap(document.revision.source?.title).isEmpty)
        }
        XCTAssertEqual(document.revision.source?.canonicalURL, source.revision.source?.canonicalURL)
        XCTAssertEqual(document.revision.source?.authorName, source.revision.source?.authorName)
        XCTAssertFalse(document.revision.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        for section in document.revision.instructionSections {
          for step in section.steps {
            XCTAssertFalse(step.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
      }
    }
  }

  func testInstallUsesExplicitLocaleNamesAndDoesNotRenameUserOwnedOrganizationOnRefresh() throws {
    for language in locales {
      let locale = Locale(identifier: language)
      let container = try KitchenMemorySchema.makeContainer(inMemory: true)
      let repository = SwiftDataRecipeRepository(modelContainer: container)
      let kitchen = Kitchen(name: "Synthetic Kitchen")
      try repository.save(kitchen)
      let library = RecipeLibrary(kitchenID: kitchen.id, repository: repository,
        samples: BundledSampleRecipeProvider(preferredLanguages: [language]), importer: RecipeImportService(),
        samplePackRepository: SwiftDataSamplePackRepository(modelContainer: container),
        sampleFolderName: LocalizedStringResource.settingsSamplesFolderName.localized(for: locale),
        sampleTagName: LocalizedStringResource.settingsSamplesTagName.localized(for: locale))
      try library.installSamples()
      let status = try XCTUnwrap(library.samplePackStatus())
      let folders = SwiftDataFolderRepository(modelContainer: container)
      let tags = SwiftDataTagRepository(modelContainer: container)
      let initial = try folders.library(in: kitchen.id)
      XCTAssertEqual(initial.folders.first?.name,
        LocalizedStringResource.settingsSamplesFolderName.localized(for: locale))
      XCTAssertEqual(try tags.library(in: kitchen.id).tags.first?.name,
        LocalizedStringResource.settingsSamplesTagName.localized(for: locale))
      try folders.append(initial.prepare(.rename(id: XCTUnwrap(status.folderID), name: "My spelling")))
      _ = try library.load()
      XCTAssertEqual(try folders.library(in: kitchen.id).folders.first?.name, "My spelling")
      XCTAssertEqual(try library.samplePackStatus()?.folderID, status.folderID)
    }
  }
}
