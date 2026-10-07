// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

// swiftlint:disable file_length type_body_length

/// Maps the deployed Recipe payload graph without exposing managed rows to callers.
/// All row replacement, image lookup, and duplicate reconstruction share one context.
@MainActor
final class RecipePayloadStore {
  private let context: ModelContext
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  enum ReconstructionError: Error {
    case collision(RecipeRevision.ID)
  }

  /// New captures share the existing optional source blob so adding source
  /// evidence does not mutate the released SwiftData V1 schema. The decoder
  /// below still accepts the original blob, which contained RecipeSource alone.
  private struct StoredSource: Codable {
    var source: RecipeSource?
    var capture: RecipeSourceCapture
  }

  init(context: ModelContext) {
    self.context = context
  }

  private func imageData(for media: RecipeMedia, recipeID: UUID) throws -> Data? {
    guard media.isPrivateImage else { return nil }
    let revisions = try context.fetch(FetchDescriptor<RecipeRevisionRecord>(
      predicate: #Predicate { $0.recipeID == recipeID }
    ))
    let revisionIDs = Set(revisions.map(\.id))
    let mediaID = media.id.rawValue
    let payloads = try context.fetch(FetchDescriptor<RecipeImagePayloadRecord>(
      predicate: #Predicate { $0.mediaID == mediaID }
    ))
    // A later textual revision may have been saved before these bytes arrived.
    // Resolve retained references only within this Recipe's immutable history.
    return payloads.filter { revisionIDs.contains($0.revisionID) }
      .compactMap(\.imageData).first(where: media.acceptsImageData)
  }

  func restoreImagePayloads(for revision: RecipeRevision) throws {
    let revisionID = revision.id.rawValue
    for media in revision.media {
      guard let data = media.imageData, media.acceptsImageData(data) else { continue }
      let mediaID = media.id.rawValue
      let existing = try context.fetch(FetchDescriptor<RecipeImagePayloadRecord>(
        predicate: #Predicate { $0.revisionID == revisionID && $0.mediaID == mediaID }
      ))
      if !existing.contains(where: { $0.imageData == data }) {
        context.insert(RecipeImagePayloadRecord(revisionID: revisionID, mediaID: mediaID, imageData: data))
      }
    }
  }

  func validateOwnership(of recipe: Recipe) throws {
    let identifier = recipe.id.rawValue
    let descriptor = FetchDescriptor<RecipeRecord>(predicate: #Predicate { $0.id == identifier })
    if let existing = try context.fetch(descriptor).first,
      existing.kitchenID != recipe.kitchenID.rawValue {
      throw KitchenMemoryPersistenceError.recipeAlreadyOwnedByAnotherKitchen(recipeID: recipe.id)
    }
  }

  func validateOwnership(of revision: RecipeRevision) throws {
    let identifier = revision.id.rawValue
    let descriptor = FetchDescriptor<RecipeRevisionRecord>(
      predicate: #Predicate { $0.id == identifier })
    if let existing = try context.fetch(descriptor).first,
      existing.recipeID != revision.recipeID.rawValue {
      throw KitchenMemoryPersistenceError.revisionAlreadyOwnedByAnotherRecipe(
        revisionID: revision.id)
    }
  }

  func upsert(_ recipe: Recipe) throws {
    let identifier = recipe.id.rawValue
    let descriptor = FetchDescriptor<RecipeRecord>(predicate: #Predicate { $0.id == identifier })
    if let record = try context.fetch(descriptor).first {
      record.kitchenID = recipe.kitchenID.rawValue
      record.currentRevisionID = recipe.currentRevisionID.rawValue
    } else {
      context.insert(
        RecipeRecord(
          id: identifier, kitchenID: recipe.kitchenID.rawValue,
          currentRevisionID: recipe.currentRevisionID.rawValue))
    }
  }

  // swiftlint:disable:next function_body_length
  func replace(_ revision: RecipeRevision) throws {
    let identifier = revision.id.rawValue
    try deleteRevisionRows(revisionID: identifier)

    context.insert(
      RecipeRevisionRecord(
        id: identifier,
        recipeID: revision.recipeID.rawValue,
        revisionNumber: revision.revisionNumber,
        title: revision.title,
        summary: revision.summary,
        authorName: revision.authorName,
        contentLanguage: revision.contentLanguage?.rawValue,
        sourceData: try encodeSource(revision.source, capture: revision.sourceCapture),
        yieldData: try encodeOptional(revision.recipeYield),
        prepSeconds: revision.prepDuration?.seconds,
        cookSeconds: revision.cookDuration?.seconds,
        totalSeconds: revision.totalDuration?.seconds,
        cuisinesData: try encoder.encode(revision.cuisines),
        categoriesData: try encoder.encode(revision.categories),
        keywordsData: try encoder.encode(revision.keywords)
      ))

    for (index, media) in revision.media.enumerated() {
      if let data = media.imageData, media.acceptsImageData(data) {
        context.insert(RecipeImagePayloadRecord(
          revisionID: identifier, mediaID: media.id.rawValue, imageData: data
        ))
      }
      context.insert(
        RecipeMediaRecord(
          id: media.id.rawValue, revisionID: identifier, sortIndex: index,
          role: media.role.rawValue, assetName: media.assetName,
          accessibilityLabel: media.accessibilityLabel))
    }
    for (index, item) in revision.equipment.enumerated() {
      context.insert(
        EquipmentRecord(
          id: item.id.rawValue, revisionID: identifier, sortIndex: index,
          originalText: item.originalText, quantityData: try encodeOptional(item.quantity),
          name: item.name, isOptional: item.isOptional))
    }
    for (sectionIndex, section) in revision.ingredientSections.enumerated() {
      context.insert(
        IngredientSectionRecord(
          id: section.id.rawValue, revisionID: identifier, sortIndex: sectionIndex,
          title: section.title))
      for (itemIndex, item) in section.ingredients.enumerated() {
        context.insert(
          RecipeIngredientRecord(
            id: item.id.rawValue, sectionID: section.id.rawValue, sortIndex: itemIndex,
            originalText: item.originalText, presentationMode: item.presentationMode.rawValue,
            customDisplayText: item.customDisplayText,
            quantityData: try encodeOptional(item.quantity), unitText: item.unitText,
            packageData: try encodeOptional(item.package), ingredientText: item.ingredientText,
            preparation: item.preparation, note: item.note, isOptional: item.isOptional,
            scalingBehavior: item.scalingBehavior.rawValue, parseState: item.parseState.rawValue
          ))
      }
    }
    for (sectionIndex, section) in revision.instructionSections.enumerated() {
      context.insert(
        InstructionSectionRecord(
          id: section.id.rawValue, revisionID: identifier, sortIndex: sectionIndex,
          title: section.title))
      for (stepIndex, step) in section.steps.enumerated() {
        context.insert(
          InstructionStepRecord(
            id: step.id.rawValue, sectionID: section.id.rawValue, sortIndex: stepIndex,
            name: step.name, text: step.text, durationSeconds: step.duration?.seconds,
            temperatureData: try encodeOptional(step.temperature)))
      }
    }
  }

  // swiftlint:disable:next function_body_length
  func domainRevision(from record: RecipeRevisionRecord) throws -> RecipeRevision {
    let storedSource = try decodeSource(record.sourceData)
    let revisionID = record.id
    let mediaRecords = try coalescedPayloadRows(context.fetch(
      FetchDescriptor<RecipeMediaRecord>(
        predicate: #Predicate { $0.revisionID == revisionID }, sortBy: [SortDescriptor(\.sortIndex)]
      )
    ), revisionID: record.id, id: \.id) { lhs, rhs in
      lhs.revisionID == rhs.revisionID && lhs.sortIndex == rhs.sortIndex
        && lhs.role == rhs.role && lhs.assetName == rhs.assetName
        && lhs.mediaAccessibilityLabel == rhs.mediaAccessibilityLabel
    }
    let media = try mediaRecords.map { item in
      guard let role = RecipeMedia.Role(rawValue: item.role) else {
        throw KitchenMemoryPersistenceError.invalidStoredValue(field: "media.role")
      }
      var media = RecipeMedia(
        id: .init(rawValue: item.id), role: role, assetName: item.assetName,
        accessibilityLabel: item.mediaAccessibilityLabel)
      media.imageData = try imageData(for: media, recipeID: record.recipeID)
      return media
    }
    let equipmentRecords = try coalescedPayloadRows(context.fetch(
      FetchDescriptor<EquipmentRecord>(
        predicate: #Predicate { $0.revisionID == revisionID }, sortBy: [SortDescriptor(\.sortIndex)]
      )
    ), revisionID: record.id, id: \.id) { lhs, rhs in
      lhs.revisionID == rhs.revisionID && lhs.sortIndex == rhs.sortIndex
        && lhs.originalText == rhs.originalText && lhs.quantityData == rhs.quantityData
        && lhs.name == rhs.name && lhs.isOptional == rhs.isOptional
    }
    let equipment = try equipmentRecords.map { item in
      EquipmentItem(
        id: .init(rawValue: item.id), originalText: item.originalText,
        quantity: try decodeOptional(
          QuantityExpression.self, from: item.quantityData, field: "equipment.quantity"),
        name: item.name, isOptional: item.isOptional)
    }

    let ingredientSectionRecords = try coalescedPayloadRows(context.fetch(
      FetchDescriptor<IngredientSectionRecord>(
        predicate: #Predicate { $0.revisionID == revisionID }, sortBy: [SortDescriptor(\.sortIndex)]
      )
    ), revisionID: record.id, id: \.id) { lhs, rhs in
      lhs.revisionID == rhs.revisionID && lhs.sortIndex == rhs.sortIndex && lhs.title == rhs.title
    }
    let ingredientSections = try ingredientSectionRecords.map { section in
      let sectionID = section.id
      let storedItems = try context.fetch(
        FetchDescriptor<RecipeIngredientRecord>(
          predicate: #Predicate { $0.sectionID == sectionID }, sortBy: [SortDescriptor(\.sortIndex)]
        )
      )
      let itemRecords = try coalescedPayloadRows(
        storedItems, revisionID: record.id, id: \.id, equivalent: ingredientsMatch
      )
      let items = try itemRecords.map { item in
        guard let presentationMode = RecipeIngredient.PresentationMode(rawValue: item.presentationMode)
        else {
          throw KitchenMemoryPersistenceError.invalidStoredValue(
            field: "ingredient.presentationMode")
        }
        guard let scaling = RecipeIngredient.ScalingBehavior(rawValue: item.scalingBehavior) else {
          throw KitchenMemoryPersistenceError.invalidStoredValue(field: "ingredient.scalingBehavior")
        }
        guard let parseState = RecipeIngredient.ParseState(rawValue: item.parseState) else {
          throw KitchenMemoryPersistenceError.invalidStoredValue(field: "ingredient.parseState")
        }
        return RecipeIngredient(
          id: .init(rawValue: item.id), originalText: item.originalText,
          presentationMode: presentationMode,
          customDisplayText: item.customDisplayText,
          quantity: try decodeOptional(
            QuantityExpression.self, from: item.quantityData, field: "ingredient.quantity"),
          unitText: item.unitText,
          package: try decodeOptional(
            PackageDescription.self, from: item.packageData, field: "ingredient.package"),
          ingredientText: item.ingredientText, preparation: item.preparation, note: item.note,
          isOptional: item.isOptional, scalingBehavior: scaling, parseState: parseState
        )
      }
      return IngredientSection(
        id: .init(rawValue: section.id), title: section.title, ingredients: items)
    }

    let instructionSectionRecords = try coalescedPayloadRows(context.fetch(
      FetchDescriptor<InstructionSectionRecord>(
        predicate: #Predicate { $0.revisionID == revisionID }, sortBy: [SortDescriptor(\.sortIndex)]
      )
    ), revisionID: record.id, id: \.id) { lhs, rhs in
      lhs.revisionID == rhs.revisionID && lhs.sortIndex == rhs.sortIndex && lhs.title == rhs.title
    }
    let instructionSections = try instructionSectionRecords.map { section in
      let sectionID = section.id
      let storedSteps = try context.fetch(
        FetchDescriptor<InstructionStepRecord>(
          predicate: #Predicate { $0.sectionID == sectionID }, sortBy: [SortDescriptor(\.sortIndex)]
        )
      )
      let stepRecords = try coalescedPayloadRows(storedSteps, revisionID: record.id, id: \.id) { lhs, rhs in
        lhs.sectionID == rhs.sectionID && lhs.sortIndex == rhs.sortIndex
          && lhs.name == rhs.name && lhs.text == rhs.text
          && lhs.durationSeconds == rhs.durationSeconds
          && lhs.temperatureData == rhs.temperatureData
      }
      let steps = try stepRecords.map { step in
        InstructionStep(
          id: .init(rawValue: step.id), name: step.name, text: step.text,
          duration: step.durationSeconds.map(RecipeDuration.init(seconds:)),
          temperature: try decodeOptional(
            RecipeTemperature.self, from: step.temperatureData, field: "step.temperature"))
      }
      return InstructionSection(id: .init(rawValue: section.id), title: section.title, steps: steps)
    }

    let contentLanguage: RecipeContentLanguage?
    if let storedLanguage = record.contentLanguage {
      guard let language = RecipeContentLanguage(rawValue: storedLanguage) else {
        throw KitchenMemoryPersistenceError.invalidStoredValue(
          field: "revision.contentLanguage"
        )
      }
      contentLanguage = language
    } else {
      contentLanguage = nil
    }

    return RecipeRevision(
      id: .init(rawValue: record.id), recipeID: .init(rawValue: record.recipeID),
      revisionNumber: record.revisionNumber,
      title: record.title, summary: record.summary, authorName: record.authorName,
      contentLanguage: contentLanguage,
      source: storedSource.source,
      sourceCapture: storedSource.capture,
      recipeYield: try decodeOptional(
        RecipeYield.self, from: record.yieldData, field: "revision.yield"),
      prepDuration: record.prepSeconds.map(RecipeDuration.init(seconds:)),
      cookDuration: record.cookSeconds.map(RecipeDuration.init(seconds:)),
      totalDuration: record.totalSeconds.map(RecipeDuration.init(seconds:)),
      cuisines: try decode([String].self, from: record.cuisinesData, field: "revision.cuisines"),
      categories: try decode(
        [String].self, from: record.categoriesData, field: "revision.categories"),
      keywords: try decode([String].self, from: record.keywordsData, field: "revision.keywords"),
      media: media, equipment: equipment, ingredientSections: ingredientSections,
      instructionSections: instructionSections
    )
  }

  private func coalescedPayloadRows<Record>(
    _ records: [Record],
    revisionID: UUID,
    id: KeyPath<Record, UUID>,
    equivalent: (Record, Record) -> Bool
  ) throws -> [Record] {
    var retained: [UUID: Record] = [:]
    var result: [Record] = []
    for record in records {
      let identifier = record[keyPath: id]
      if let existing = retained[identifier] {
        guard equivalent(existing, record) else {
          throw ReconstructionError.collision(.init(rawValue: revisionID))
        }
      } else {
        retained[identifier] = record
        result.append(record)
      }
    }
    return result
  }

  private func ingredientsMatch(
    _ lhs: RecipeIngredientRecord,
    _ rhs: RecipeIngredientRecord
  ) -> Bool {
    lhs.sectionID == rhs.sectionID && lhs.sortIndex == rhs.sortIndex
      && lhs.originalText == rhs.originalText && lhs.presentationMode == rhs.presentationMode
      && lhs.customDisplayText == rhs.customDisplayText && lhs.quantityData == rhs.quantityData
      && lhs.unitText == rhs.unitText && lhs.packageData == rhs.packageData
      && lhs.ingredientText == rhs.ingredientText && lhs.preparation == rhs.preparation
      && lhs.note == rhs.note && lhs.isOptional == rhs.isOptional
      && lhs.scalingBehavior == rhs.scalingBehavior && lhs.parseState == rhs.parseState
  }

  func deleteRevisionRows(revisionID: UUID) throws {
    for record in try context.fetch(FetchDescriptor<RecipeImagePayloadRecord>(
      predicate: #Predicate { $0.revisionID == revisionID }
    )) { context.delete(record) }
    for record in try context.fetch(FetchDescriptor<RecipeMediaRecord>(
      predicate: #Predicate { $0.revisionID == revisionID }
    )) {
      context.delete(record)
    }
    for record in try context.fetch(FetchDescriptor<EquipmentRecord>(
      predicate: #Predicate { $0.revisionID == revisionID }
    )) {
      context.delete(record)
    }
    for section in try context.fetch(
      FetchDescriptor<IngredientSectionRecord>(
        predicate: #Predicate { $0.revisionID == revisionID })) {
      let sectionID = section.id
      for item in try context.fetch(
        FetchDescriptor<RecipeIngredientRecord>(predicate: #Predicate { $0.sectionID == sectionID })
      ) { context.delete(item) }
      context.delete(section)
    }
    for section in try context.fetch(
      FetchDescriptor<InstructionSectionRecord>(
        predicate: #Predicate { $0.revisionID == revisionID })) {
      let sectionID = section.id
      for step in try context.fetch(FetchDescriptor<InstructionStepRecord>(
        predicate: #Predicate { $0.sectionID == sectionID }
      )) {
        context.delete(step)
      }
      context.delete(section)
    }
  }

  private func encodeOptional<Value: Encodable>(_ value: Value?) throws -> Data? {
    try value.map(encoder.encode)
  }

  private func encodeSource(
    _ source: RecipeSource?,
    capture: RecipeSourceCapture?
  ) throws -> Data? {
    guard let capture else { return try encodeOptional(source) }
    return try encoder.encode(StoredSource(source: source, capture: capture))
  }

  private func decodeSource(_ data: Data?) throws -> (
    source: RecipeSource?, capture: RecipeSourceCapture?
  ) {
    guard let data else { return (nil, nil) }
    if let stored = try? decoder.decode(StoredSource.self, from: data) {
      return (stored.source, stored.capture)
    }
    return (
      try decode(RecipeSource.self, from: data, field: "revision.source"),
      nil
    )
  }

  private func decode<Value: Decodable>(_ type: Value.Type, from data: Data, field: String) throws
    -> Value {
    do { return try decoder.decode(type, from: data) } catch {
      throw KitchenMemoryPersistenceError.invalidStoredValue(field: field)
    }
  }

  private func decodeOptional<Value: Decodable>(_ type: Value.Type, from data: Data?, field: String)
    throws -> Value? {
    guard let data else { return nil }
    return try decode(type, from: data, field: field)
  }
}

// swiftlint:enable file_length type_body_length
