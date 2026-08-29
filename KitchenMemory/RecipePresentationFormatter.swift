// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenKit

/// Locale-aware rendering for semantic recipe values.
///
/// Authored wording stays in the domain. This adapter owns only wording that
/// Kitchen Memory generates while presenting that content.
nonisolated struct RecipePresentationFormatter {
  let locale: Locale

  init(locale: Locale = .current) {
    self.locale = locale
  }

  func ingredient(_ ingredient: RecipeIngredient) -> String {
    let structured = structuredIngredient(ingredient)
    switch ingredient.presentationMode {
    case .original:
      return nonempty(ingredient.originalText) ?? structured ?? ingredientFallback
    case .custom:
      return nonempty(ingredient.customDisplayText) ?? structured
        ?? nonempty(ingredient.originalText) ?? ingredientFallback
    case .structured:
      return structured ?? nonempty(ingredient.originalText) ?? ingredientFallback
    }
  }

  func quantity(_ quantity: QuantityExpression?) -> String? {
    guard let quantity else { return nil }
    switch quantity.kind {
    case .none:
      return nil
    case .exact:
      return quantity.lowerBound.map(rational)
    case .range:
      guard let lower = quantity.lowerBound, let upper = quantity.upperBound else {
        return nonempty(quantity.text)
      }
      return "\(rational(lower))–\(rational(upper))"
    case .approximate:
      guard let value = quantity.lowerBound.map(rational) else {
        return nonempty(quantity.text)
      }
      return LocalizedStringResource.recipePresentationQuantityApproximate(value: value)
        .localized(for: locale)
    case .text:
      return nonempty(quantity.text)
    }
  }

  func rational(_ quantity: RationalQuantity) -> String {
    let value = quantity.normalized ?? quantity
    guard value.denominator != 1 else { return integer(value.numerator) }
    let whole = value.numerator / value.denominator
    let remainder = value.numerator % value.denominator
    let fraction = "\(integer(remainder))/\(integer(value.denominator))"
    return whole == 0 ? fraction : "\(integer(whole)) \(fraction)"
  }

  func yield(quantity: RationalQuantity, unitText: String?) -> String {
    [rational(quantity), nonempty(unitText)].compactMap { $0 }.joined(separator: " ")
  }

  func duration(_ duration: RecipeDuration) -> String {
    let hours = duration.seconds / 3_600
    let minutes = (duration.seconds % 3_600) / 60
    if hours > 0, minutes > 0 {
      return LocalizedStringResource.recipePresentationDurationHoursMinutes(
        hours: hours,
        minutes: minutes
      ).localized(for: locale)
    }
    if hours > 0 {
      return LocalizedStringResource.recipePresentationDurationHours(hours: hours)
        .localized(for: locale)
    }
    return LocalizedStringResource.recipePresentationDurationMinutes(minutes: minutes)
      .localized(for: locale)
  }

  private var ingredientFallback: String {
    LocalizedStringResource.recipeIngredientFallbackName.localized(for: locale)
  }

  private func structuredIngredient(_ ingredient: RecipeIngredient) -> String? {
    guard let name = nonempty(ingredient.ingredientText) else { return nil }
    var components: [String] = []
    if let amount = quantity(ingredient.quantity) { components.append(amount) }
    if let package = ingredient.package,
       let amount = quantity(package.quantity),
       let unit = nonempty(package.unitText) {
      components.append("(\(amount) \(unit))")
    }
    if let unit = nonempty(ingredient.unitText) { components.append(unit) }
    components.append(name)

    var result = components.joined(separator: " ")
    if let preparation = nonempty(ingredient.preparation) { result += ", \(preparation)" }
    if let note = nonempty(ingredient.note) { result += ", \(note)" }
    if ingredient.isOptional {
      result = LocalizedStringResource.recipePresentationIngredientOptional(ingredient: result)
        .localized(for: locale)
    }
    return result
  }

  private func integer(_ value: Int) -> String {
    value.formatted(.number.grouping(.never).locale(locale))
  }

  private func nonempty(_ text: String?) -> String? {
    let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? nil : trimmed
  }
}
