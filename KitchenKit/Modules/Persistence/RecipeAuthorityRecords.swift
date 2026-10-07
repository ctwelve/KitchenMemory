// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

// Recipe authority rows are immutable operation envelopes joined to the
// existing Recipe payload graph only by stable application-owned identifiers.
// Declaration defaults satisfy managed CloudKit; repository mapping must reject
// them rather than treating placeholders as accepted domain evidence.

@Model final class RecipeSaveRecord {
  var id: UUID = UUID()
  var kitchenID: UUID = UUID()
  var recipeID: UUID = UUID()
  var revisionID: UUID = UUID()
  var savedAt: Date = Date.distantPast
  var ancestryFormatVersion: Int = -1
  var parentRevisionIDsData: Data = Data()
  var payloadManifestFormatVersion: Int = -1
  var payloadManifestData: Data = Data()
  var revisionFormatVersion: Int = -1
  var revisionDigest: Data = Data()

  init(
    id: UUID, kitchenID: UUID, recipeID: UUID, revisionID: UUID,
    savedAt: Date, ancestryFormatVersion: Int, parentRevisionIDsData: Data,
    payloadManifestFormatVersion: Int, payloadManifestData: Data,
    revisionFormatVersion: Int, revisionDigest: Data
  ) {
    self.id = id
    self.kitchenID = kitchenID
    self.recipeID = recipeID
    self.revisionID = revisionID
    self.savedAt = savedAt
    self.ancestryFormatVersion = ancestryFormatVersion
    self.parentRevisionIDsData = parentRevisionIDsData
    self.payloadManifestFormatVersion = payloadManifestFormatVersion
    self.payloadManifestData = payloadManifestData
    self.revisionFormatVersion = revisionFormatVersion
    self.revisionDigest = revisionDigest
  }
}

@Model final class RecipeSelectionRecord {
  var id: UUID = UUID()
  var kitchenID: UUID = UUID()
  var recipeID: UUID = UUID()
  var selectedRevisionID: UUID = UUID()
  var selectedAt: Date = Date.distantPast
  var frontierFormatVersion: Int = -1
  var observedSelectionIDsData: Data = Data()

  init(
    id: UUID, kitchenID: UUID, recipeID: UUID, selectedRevisionID: UUID,
    selectedAt: Date, frontierFormatVersion: Int,
    observedSelectionIDsData: Data
  ) {
    self.id = id
    self.kitchenID = kitchenID
    self.recipeID = recipeID
    self.selectedRevisionID = selectedRevisionID
    self.selectedAt = selectedAt
    self.frontierFormatVersion = frontierFormatVersion
    self.observedSelectionIDsData = observedSelectionIDsData
  }
}

@Model final class RecipePruneRecord {
  var id: UUID = UUID()
  var kitchenID: UUID = UUID()
  var recipeID: UUID = UUID()
  var prunedAt: Date = Date.distantPast
  var antiResurrectionUntil: Date = Date.distantPast
  var frontierFormatVersion: Int = -1
  var frontierData: Data = Data()
  var frontierDigest: Data = Data()

  init(
    id: UUID, kitchenID: UUID, recipeID: UUID, prunedAt: Date,
    antiResurrectionUntil: Date, frontierFormatVersion: Int,
    frontierData: Data, frontierDigest: Data
  ) {
    self.id = id
    self.kitchenID = kitchenID
    self.recipeID = recipeID
    self.prunedAt = prunedAt
    self.antiResurrectionUntil = antiResurrectionUntil
    self.frontierFormatVersion = frontierFormatVersion
    self.frontierData = frontierData
    self.frontierDigest = frontierDigest
  }
}
