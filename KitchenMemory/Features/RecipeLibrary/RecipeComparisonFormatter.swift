// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit

extension RecipeComparisonField {
  var title: LocalizedStringResource {
    switch self {
    case .title: .recipeComparisonFieldTitle
    case .summary: .recipeComparisonFieldSummary
    case .author: .recipeComparisonFieldAuthor
    case .language: .recipeComparisonFieldLanguage
    case .source: .recipeComparisonFieldSource
    case .yield: .recipeComparisonFieldYield
    case .preparation: .recipeComparisonFieldPreparation
    case .cooking: .recipeComparisonFieldCooking
    case .total: .recipeComparisonFieldTotal
    case .cuisines: .recipeComparisonFieldCuisines
    case .categories: .recipeComparisonFieldCategories
    case .keywords: .recipeComparisonFieldKeywords
    case .ingredients: .recipeComparisonFieldIngredients
    case .instructions: .recipeComparisonFieldInstructions
    case .equipment: .recipeComparisonFieldEquipment
    case .media: .recipeComparisonFieldMedia
    }
  }
}

struct RecipeComparisonFormatter {
  let locale: Locale
  private var formatter: RecipePresentationFormatter { RecipePresentationFormatter(locale: locale) }
  private var unknown: String { LocalizedStringResource.recipeComparisonUnknown.localized(for: locale) }

  // Exhaustive presentation of the supported comparison fields.
  // swiftlint:disable:next cyclomatic_complexity
  func value(_ field: RecipeComparisonField, revision: RecipeRevision) -> String {
    switch field {
    case .title: revision.title
    case .summary: revision.summary ?? unknown
    case .author: revision.authorName ?? unknown
    case .language: revision.contentLanguage?.rawValue ?? unknown
    case .source: source(revision)
    case .yield: lines([revision.recipeYield?.originalText, quantity(revision.recipeYield?.quantity),
                       revision.recipeYield?.unitText,
    ])
    case .preparation: duration(revision.prepDuration)
    case .cooking: duration(revision.cookDuration)
    case .total: duration(revision.totalDuration)
    case .cuisines: lines(revision.cuisines)
    case .categories: lines(revision.categories)
    case .keywords: lines(revision.keywords)
    case .ingredients: lines(revision.ingredientSections.map {
      lines([$0.title] + $0.ingredients.map(ingredient))
    })
    case .instructions: lines(revision.instructionSections.map {
      lines([$0.title] + $0.steps.map {
        lines([$0.name, $0.text, $0.duration.map(duration), $0.temperature.map(temperature)])
      })
    })
    case .equipment: lines(revision.equipment.map {
      lines([$0.originalText, $0.name, quantity($0.quantity), $0.isOptional ? optional : nil])
    })
    case .media: lines(revision.media.map {
      lines([$0.accessibilityLabel, $0.assetName, role($0.role).localized(for: locale)])
    })
    }
  }

  func ingredient(_ value: RecipeIngredient) -> String {
    lines([value.originalText, formatter.ingredient(value), value.customDisplayText,
           quantity(value.quantity), value.unitText, value.ingredientText,
           value.package.map { lines([quantity($0.quantity), $0.unitText]) },
           value.preparation, value.note, value.isOptional ? optional : nil,
           scaling(value.scalingBehavior).localized(for: locale),
    ])
  }

  private func role(_ value: RecipeMedia.Role) -> LocalizedStringResource {
    switch value {
    case .hero: .recipeMediaHeroTitle
    case .gallery: .recipeMediaGalleryTitle
    case .thumbnail: .recipeComparisonThumbnail
    }
  }

  private func quantity(_ value: QuantityExpression?) -> String? {
    guard let value else { return nil }
    return lines([formatter.quantity(value), value.text])
  }

  private func scaling(_ value: RecipeIngredient.ScalingBehavior) -> LocalizedStringResource {
    switch value {
    case .linear: .recipeIngredientScalingLinear
    case .fixed: .recipeIngredientScalingFixed
    case .manualReview: .recipeIngredientScalingManualReview
    }
  }

  private var optional: String { LocalizedStringResource.fieldOptionalPrompt.localized(for: locale) }

  private func temperature(_ value: RecipeTemperature) -> String {
    formatter.rational(value.value) + (value.unit == .celsius ? " °C" : " °F")
  }

  private func source(_ revision: RecipeRevision) -> String {
    lines([revision.source.map { sourceKind($0.kind).localized(for: locale) },
           revision.source?.title, revision.source?.authorName, revision.source?.publisherName,
           revision.source?.canonicalURL?.absoluteString, revision.sourceCapture?.sourceURL.absoluteString,
           revision.sourceCapture?.capturedAt.formatted(.dateTime.locale(locale)),
    ])
  }

  private func sourceKind(_ kind: RecipeSource.Kind) -> LocalizedStringResource {
    switch kind {
    case .original: .recipeSourceKindOriginal
    case .webpage: .recipeSourceKindWebpage
    case .book: .recipeSourceKindBook
    case .person: .recipeSourceKindPerson
    case .imported: .recipeSourceKindImported
    }
  }

  private func duration(_ value: RecipeDuration?) -> String {
    guard let value else { return unknown }
    return value.seconds.formatted(.number.locale(locale)) + " "
      + LocalizedStringResource.recipeComparisonSecondsUnit.localized(for: locale)
  }

  private func lines(_ values: [String?]) -> String {
    let values = values.compactMap { $0 }.filter { !$0.isEmpty }
    return values.isEmpty ? unknown : values.joined(separator: "\n")
  }
}
