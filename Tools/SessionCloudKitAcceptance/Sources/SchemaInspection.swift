// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import CoreData
import Foundation
import SwiftData

enum SchemaInspection {
  static func printV3() throws {
    guard let model = NSManagedObjectModel.makeManagedObjectModel(
      for: KitchenMemorySchemaV3.models
    ) else {
      throw AcceptanceHarnessError.generatedModelUnavailable
    }
    let sessionNames = Set([
      "CookingSessionRecord",
      "SessionFactRecord",
      "SessionClosureRecord",
      "SessionDeletionRecord",
      "SessionDeletionResolutionRecord",
    ])
    for entity in model.entities.filter({ sessionNames.contains($0.name ?? "") })
      .sorted(by: { $0.name ?? "" < $1.name ?? "" }) {
      let fields = entity.attributesByName.values.sorted { $0.name < $1.name }.map {
        [
          "name": $0.name,
          "type": $0.attributeType.rawValue,
          "optional": $0.isOptional,
          "hasDefault": $0.defaultValue != nil,
          "external": $0.allowsExternalBinaryDataStorage,
        ] as [String: Any]
      }
      AcceptanceOutput.emit([
        "event": "schema-entity",
        "name": entity.name ?? "unnamed",
        "fields": fields,
        "relationships": entity.relationshipsByName.count,
        "indexes": entity.indexes.count,
        "uniquenessConstraints": entity.uniquenessConstraints.count,
        "optionalEncryption": "not-requested",
      ])
    }
  }
}
