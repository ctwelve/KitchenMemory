// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import SwiftData

// These records are storage representations, not objects used to create new
// domain entities. Their initializers therefore copy already-validated values
// and preserve UUIDs supplied by the domain, an import, or synchronization; they
// must not generate replacement identities or invent defaults. Construction and
// validation belong to domain/application workflows, while the repository is
// the only code that maps those values into these deliberately boring setters.
// SwiftData still gives every record an internal identity, but that
// implementation detail never crosses into KitchenMemoryDomain.

@Model final class KitchenRecord {
  var id: UUID
  var name: String

  init(id: UUID, name: String) {
    self.id = id
    self.name = name
  }
}

@Model final class RecipeRecord {
  var id: UUID
  var kitchenID: UUID
  var currentRevisionID: UUID

  init(id: UUID, kitchenID: UUID, currentRevisionID: UUID) {
    self.id = id
    self.kitchenID = kitchenID
    self.currentRevisionID = currentRevisionID
  }
}

@Model final class RecipeRevisionRecord {
  var id: UUID
  var recipeID: UUID
  var revisionNumber: Int
  var title: String
  var summary: String?
  var authorName: String?
  var contentLanguage: String?
  var sourceData: Data?
  var yieldData: Data?
  var prepSeconds: Int?
  var cookSeconds: Int?
  var totalSeconds: Int?
  var cuisinesData: Data
  var categoriesData: Data
  var keywordsData: Data

  init(
    id: UUID, recipeID: UUID, revisionNumber: Int, title: String, summary: String?,
    authorName: String?, contentLanguage: String?, sourceData: Data?, yieldData: Data?,
    prepSeconds: Int?, cookSeconds: Int?,
    totalSeconds: Int?, cuisinesData: Data, categoriesData: Data, keywordsData: Data
  ) {
    self.id = id
    self.recipeID = recipeID
    self.revisionNumber = revisionNumber
    self.title = title
    self.summary = summary
    self.authorName = authorName
    self.contentLanguage = contentLanguage
    self.sourceData = sourceData
    self.yieldData = yieldData
    self.prepSeconds = prepSeconds
    self.cookSeconds = cookSeconds
    self.totalSeconds = totalSeconds
    self.cuisinesData = cuisinesData
    self.categoriesData = categoriesData
    self.keywordsData = keywordsData
  }
}

@Model final class RecipeMediaRecord {
  var id: UUID
  var revisionID: UUID
  var sortIndex: Int
  var role: String
  var assetName: String
  // Avoid the iOS accessibility runtime's property name while retaining the
  // original on-disk field name for existing V1 stores.
  @Attribute(originalName: "accessibilityLabel")
  var mediaAccessibilityLabel: String?

  init(
    id: UUID, revisionID: UUID, sortIndex: Int, role: String, assetName: String,
    accessibilityLabel: String?
  ) {
    self.id = id
    self.revisionID = revisionID
    self.sortIndex = sortIndex
    self.role = role
    self.assetName = assetName
    self.mediaAccessibilityLabel = accessibilityLabel
  }
}

@Model final class EquipmentRecord {
  var id: UUID
  var revisionID: UUID
  var sortIndex: Int
  var originalText: String
  var quantityData: Data?
  var name: String
  var isOptional: Bool

  init(
    id: UUID, revisionID: UUID, sortIndex: Int, originalText: String, quantityData: Data?,
    name: String, isOptional: Bool
  ) {
    self.id = id
    self.revisionID = revisionID
    self.sortIndex = sortIndex
    self.originalText = originalText
    self.quantityData = quantityData
    self.name = name
    self.isOptional = isOptional
  }
}

@Model final class IngredientSectionRecord {
  var id: UUID
  var revisionID: UUID
  var sortIndex: Int
  var title: String?

  init(id: UUID, revisionID: UUID, sortIndex: Int, title: String?) {
    self.id = id
    self.revisionID = revisionID
    self.sortIndex = sortIndex
    self.title = title
  }
}

@Model final class RecipeIngredientRecord {
  var id: UUID
  var sectionID: UUID
  var sortIndex: Int
  var originalText: String
  var presentationMode: String
  var customDisplayText: String?
  var quantityData: Data?
  var unitText: String?
  var packageData: Data?
  var ingredientText: String?
  var preparation: String?
  var note: String?
  var isOptional: Bool
  var scalingBehavior: String
  var parseState: String

  init(
    id: UUID, sectionID: UUID, sortIndex: Int, originalText: String,
    presentationMode: String, customDisplayText: String?,
    quantityData: Data?, unitText: String?, packageData: Data?, ingredientText: String?,
    preparation: String?, note: String?, isOptional: Bool, scalingBehavior: String,
    parseState: String
  ) {
    self.id = id
    self.sectionID = sectionID
    self.sortIndex = sortIndex
    self.originalText = originalText
    self.presentationMode = presentationMode
    self.customDisplayText = customDisplayText
    self.quantityData = quantityData
    self.unitText = unitText
    self.packageData = packageData
    self.ingredientText = ingredientText
    self.preparation = preparation
    self.note = note
    self.isOptional = isOptional
    self.scalingBehavior = scalingBehavior
    self.parseState = parseState
  }
}

@Model final class InstructionSectionRecord {
  var id: UUID
  var revisionID: UUID
  var sortIndex: Int
  var title: String?

  init(id: UUID, revisionID: UUID, sortIndex: Int, title: String?) {
    self.id = id
    self.revisionID = revisionID
    self.sortIndex = sortIndex
    self.title = title
  }
}

@Model final class InstructionStepRecord {
  var id: UUID
  var sectionID: UUID
  var sortIndex: Int
  var name: String?
  var text: String
  var durationSeconds: Int?
  var temperatureData: Data?

  init(
    id: UUID, sectionID: UUID, sortIndex: Int, name: String?, text: String, durationSeconds: Int?,
    temperatureData: Data?
  ) {
    self.id = id
    self.sectionID = sectionID
    self.sortIndex = sortIndex
    self.name = name
    self.text = text
    self.durationSeconds = durationSeconds
    self.temperatureData = temperatureData
  }
}
