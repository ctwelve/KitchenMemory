// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain
import SwiftData

/// A recipe together with the revision selected as its current content.
public struct StoredRecipe: Equatable, Sendable {
  public let recipe: Recipe
  public let revision: RecipeRevision

  public init(recipe: Recipe, revision: RecipeRevision) {
    self.recipe = recipe
    self.revision = revision
  }
}

/// Domain-facing storage operations needed by the first recipe workflow.
///
/// The protocol mentions no SwiftData types, so application use cases and test
/// doubles can depend on it without adopting the persistence framework.
@MainActor
public protocol RecipeRepository: AnyObject {
  func save(_ kitchen: Kitchen) throws
  func save(recipe: Recipe, revision: RecipeRevision) throws
  func kitchens() throws -> [Kitchen]
  func kitchen(id: Kitchen.ID) throws -> Kitchen?
  func recipe(id: Recipe.ID) throws -> StoredRecipe?
  func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe]
  /// Returns every saved revision for a recipe, newest revision first.
  func revisions(for recipeID: Recipe.ID) throws -> [RecipeRevision]
}

/// Failures detected while translating between domain values and stored rows.
public enum KitchenMemoryPersistenceError: Error, Equatable {
  /// The recipe and revision do not refer to each other as current content.
  case inconsistentRecipeIdentity

  /// A recipe cannot be saved before its owning Kitchen exists.
  case missingKitchen

  /// A recipe row refers to a revision that is absent from the store.
  case missingCurrentRevision

  /// Persisted encoded data or an enum raw value cannot be decoded safely.
  case invalidStoredValue(field: String)
}

/// A SwiftData implementation of ``RecipeRepository``.
///
/// All access is main-actor isolated because `ModelContext` is an actor-bound
/// unit of work. Later background import can create its own repository and
/// context rather than passing managed records between actors.
@MainActor
public final class SwiftDataRecipeRepository: RecipeRepository {
  private let context: ModelContext
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  public init(modelContainer: ModelContainer) {
    context = ModelContext(modelContainer)
  }

  public func save(_ kitchen: Kitchen) throws {
    let identifier = kitchen.id.rawValue
    let descriptor = FetchDescriptor<KitchenRecord>(predicate: #Predicate { $0.id == identifier })
    if let record = try context.fetch(descriptor).first {
      record.name = kitchen.name
    } else {
      context.insert(KitchenRecord(id: identifier, name: kitchen.name))
    }
    try context.save()
  }

  public func save(recipe: Recipe, revision: RecipeRevision) throws {
    guard revision.recipeID == recipe.id, recipe.currentRevisionID == revision.id else {
      throw KitchenMemoryPersistenceError.inconsistentRecipeIdentity
    }
    guard try kitchen(id: recipe.kitchenID) != nil else {
      throw KitchenMemoryPersistenceError.missingKitchen
    }
    try upsert(recipe)
    try replace(revision)
    try context.save()
  }

  public func kitchen(id: Kitchen.ID) throws -> Kitchen? {
    let identifier = id.rawValue
    let descriptor = FetchDescriptor<KitchenRecord>(predicate: #Predicate { $0.id == identifier })
    return try context.fetch(descriptor).first.map {
      Kitchen(id: .init(rawValue: $0.id), name: $0.name)
    }
  }

  public func kitchens() throws -> [Kitchen] {
    let descriptor = FetchDescriptor<KitchenRecord>(sortBy: [SortDescriptor(\.name)])
    return try context.fetch(descriptor).map {
      Kitchen(id: .init(rawValue: $0.id), name: $0.name)
    }
  }

  public func recipe(id: Recipe.ID) throws -> StoredRecipe? {
    let identifier = id.rawValue
    let recipeDescriptor = FetchDescriptor<RecipeRecord>(
      predicate: #Predicate { $0.id == identifier })
    guard let recipeRecord = try context.fetch(recipeDescriptor).first else { return nil }
    let revisionID = recipeRecord.currentRevisionID
    let revisionDescriptor = FetchDescriptor<RecipeRevisionRecord>(
      predicate: #Predicate { $0.id == revisionID })
    guard let revisionRecord = try context.fetch(revisionDescriptor).first else {
      throw KitchenMemoryPersistenceError.missingCurrentRevision
    }

    let recipe = Recipe(
      id: .init(rawValue: recipeRecord.id),
      kitchenID: .init(rawValue: recipeRecord.kitchenID),
      currentRevisionID: .init(rawValue: recipeRecord.currentRevisionID)
    )
    return StoredRecipe(recipe: recipe, revision: try domainRevision(from: revisionRecord))
  }

  public func recipes(in kitchenID: Kitchen.ID) throws -> [StoredRecipe] {
    let identifier = kitchenID.rawValue
    let descriptor = FetchDescriptor<RecipeRecord>(
      predicate: #Predicate { $0.kitchenID == identifier }
    )
    return try context.fetch(descriptor)
      .compactMap { try recipe(id: .init(rawValue: $0.id)) }
      .sorted {
        $0.revision.title.localizedStandardCompare($1.revision.title) == .orderedAscending
      }
  }

  public func revisions(for recipeID: Recipe.ID) throws -> [RecipeRevision] {
    let identifier = recipeID.rawValue
    let descriptor = FetchDescriptor<RecipeRevisionRecord>(
      predicate: #Predicate { $0.recipeID == identifier },
      sortBy: [SortDescriptor(\.revisionNumber, order: .reverse)]
    )
    return try context.fetch(descriptor).map(domainRevision)
  }

  private func upsert(_ recipe: Recipe) throws {
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

  private func replace(_ revision: RecipeRevision) throws {
    let identifier = revision.id.rawValue
    try deleteRevisionRows(revisionID: identifier)
    let descriptor = FetchDescriptor<RecipeRevisionRecord>(
      predicate: #Predicate { $0.id == identifier })
    if let oldRecord = try context.fetch(descriptor).first { context.delete(oldRecord) }

    context.insert(
      RecipeRevisionRecord(
        id: identifier,
        recipeID: revision.recipeID.rawValue,
        revisionNumber: revision.revisionNumber,
        title: revision.title,
        summary: revision.summary,
        authorName: revision.authorName,
        sourceData: try encodeOptional(revision.source),
        yieldData: try encodeOptional(revision.recipeYield),
        prepSeconds: revision.prepDuration?.seconds,
        cookSeconds: revision.cookDuration?.seconds,
        totalSeconds: revision.totalDuration?.seconds,
        cuisinesData: try encoder.encode(revision.cuisines),
        categoriesData: try encoder.encode(revision.categories),
        keywordsData: try encoder.encode(revision.keywords)
      ))

    for (index, media) in revision.media.enumerated() {
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
            originalText: item.originalText, displayText: item.displayText,
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

  private func domainRevision(from record: RecipeRevisionRecord) throws -> RecipeRevision {
    let revisionID = record.id
    let media = try context.fetch(
      FetchDescriptor<RecipeMediaRecord>(
        predicate: #Predicate { $0.revisionID == revisionID }, sortBy: [SortDescriptor(\.sortIndex)]
      )
    ).map { item in
      guard let role = RecipeMedia.Role(rawValue: item.role) else {
        throw KitchenMemoryPersistenceError.invalidStoredValue(field: "media.role")
      }
      return RecipeMedia(
        id: .init(rawValue: item.id), role: role, assetName: item.assetName,
        accessibilityLabel: item.accessibilityLabel)
    }
    let equipment = try context.fetch(
      FetchDescriptor<EquipmentRecord>(
        predicate: #Predicate { $0.revisionID == revisionID }, sortBy: [SortDescriptor(\.sortIndex)]
      )
    ).map { item in
      EquipmentItem(
        id: .init(rawValue: item.id), originalText: item.originalText,
        quantity: try decodeOptional(
          QuantityExpression.self, from: item.quantityData, field: "equipment.quantity"),
        name: item.name, isOptional: item.isOptional)
    }

    let ingredientSectionRecords = try context.fetch(
      FetchDescriptor<IngredientSectionRecord>(
        predicate: #Predicate { $0.revisionID == revisionID }, sortBy: [SortDescriptor(\.sortIndex)]
      ))
    let ingredientSections = try ingredientSectionRecords.map { section in
      let sectionID = section.id
      let items = try context.fetch(
        FetchDescriptor<RecipeIngredientRecord>(
          predicate: #Predicate { $0.sectionID == sectionID }, sortBy: [SortDescriptor(\.sortIndex)]
        )
      ).map { item in
        guard let scaling = RecipeIngredient.ScalingBehavior(rawValue: item.scalingBehavior),
          let parseState = RecipeIngredient.ParseState(rawValue: item.parseState)
        else {
          throw KitchenMemoryPersistenceError.invalidStoredValue(field: "ingredient enum")
        }
        return RecipeIngredient(
          id: .init(rawValue: item.id), originalText: item.originalText,
          displayText: item.displayText,
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

    let instructionSectionRecords = try context.fetch(
      FetchDescriptor<InstructionSectionRecord>(
        predicate: #Predicate { $0.revisionID == revisionID }, sortBy: [SortDescriptor(\.sortIndex)]
      ))
    let instructionSections = try instructionSectionRecords.map { section in
      let sectionID = section.id
      let steps = try context.fetch(
        FetchDescriptor<InstructionStepRecord>(
          predicate: #Predicate { $0.sectionID == sectionID }, sortBy: [SortDescriptor(\.sortIndex)]
        )
      ).map { step in
        InstructionStep(
          id: .init(rawValue: step.id), name: step.name, text: step.text,
          duration: step.durationSeconds.map(RecipeDuration.init(seconds:)),
          temperature: try decodeOptional(
            RecipeTemperature.self, from: step.temperatureData, field: "step.temperature"))
      }
      return InstructionSection(id: .init(rawValue: section.id), title: section.title, steps: steps)
    }

    return RecipeRevision(
      id: .init(rawValue: record.id), recipeID: .init(rawValue: record.recipeID),
      revisionNumber: record.revisionNumber,
      title: record.title, summary: record.summary, authorName: record.authorName,
      source: try decodeOptional(
        RecipeSource.self, from: record.sourceData, field: "revision.source"),
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

  private func deleteRevisionRows(revisionID: UUID) throws {
    for record in try context.fetch(
      FetchDescriptor<RecipeMediaRecord>(predicate: #Predicate { $0.revisionID == revisionID }))
    { context.delete(record) }
    for record in try context.fetch(
      FetchDescriptor<EquipmentRecord>(predicate: #Predicate { $0.revisionID == revisionID }))
    { context.delete(record) }
    for section in try context.fetch(
      FetchDescriptor<IngredientSectionRecord>(
        predicate: #Predicate { $0.revisionID == revisionID }))
    {
      let sectionID = section.id
      for item in try context.fetch(
        FetchDescriptor<RecipeIngredientRecord>(predicate: #Predicate { $0.sectionID == sectionID })
      ) { context.delete(item) }
      context.delete(section)
    }
    for section in try context.fetch(
      FetchDescriptor<InstructionSectionRecord>(
        predicate: #Predicate { $0.revisionID == revisionID }))
    {
      let sectionID = section.id
      for step in try context.fetch(
        FetchDescriptor<InstructionStepRecord>(predicate: #Predicate { $0.sectionID == sectionID }))
      { context.delete(step) }
      context.delete(section)
    }
  }

  private func encodeOptional<Value: Encodable>(_ value: Value?) throws -> Data? {
    try value.map(encoder.encode)
  }

  private func decode<Value: Decodable>(_ type: Value.Type, from data: Data, field: String) throws
    -> Value
  {
    do { return try decoder.decode(type, from: data) } catch {
      throw KitchenMemoryPersistenceError.invalidStoredValue(field: field)
    }
  }

  private func decodeOptional<Value: Decodable>(_ type: Value.Type, from data: Data?, field: String)
    throws -> Value?
  {
    guard let data else { return nil }
    return try decode(type, from: data, field: field)
  }
}
