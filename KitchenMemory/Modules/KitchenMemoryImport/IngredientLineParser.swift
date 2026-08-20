// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain

/// Intentionally conservative first-pass interpretation of display strings.
/// Anything not recognized stays useful through `originalText`.
enum IngredientLineParser {
    private static let units: Set<String> = [
        "cup", "cups", "tablespoon", "tablespoons", "tbsp", "teaspoon",
        "teaspoons", "tsp", "ounce", "ounces", "oz", "pound", "pounds",
        "lb", "lbs", "gram", "grams", "g", "kilogram", "kilograms", "kg",
        "milliliter", "milliliters", "ml", "liter", "liters", "l",
        "pinch", "pinches", "clove", "cloves", "slice", "slices",
    ]

    static func parse(_ source: String) -> RecipeIngredient {
        let original = clean(source)
        let tokens = original.split(maxSplits: 2, whereSeparator: \Character.isWhitespace).map(String.init)
        guard !tokens.isEmpty else {
            return RecipeIngredient(originalText: original, presentationMode: .original)
        }

        var quantityToken = tokens[0]
        var consumedTokens = 1
        if tokens.count > 1, let whole = Int(tokens[0]), fraction(tokens[1]) != nil {
            quantityToken = "\(whole) \(tokens[1])"
            consumedTokens = 2
        }
        guard let quantity = quantity(quantityToken) else {
            return RecipeIngredient(originalText: original, presentationMode: .original)
        }

        let remainder = original.split(whereSeparator: \Character.isWhitespace)
            .dropFirst(consumedTokens).map(String.init)
        guard !remainder.isEmpty else {
            return RecipeIngredient(
                originalText: original,
                presentationMode: .original,
                quantity: quantity,
                parseState: .parsed
            )
        }

        let possibleUnit = remainder[0].lowercased().trimmingCharacters(in: .punctuationCharacters)
        let hasUnit = units.contains(possibleUnit)
        let nameAndPreparation = remainder.dropFirst(hasUnit ? 1 : 0).joined(separator: " ")
        let parts = nameAndPreparation.split(separator: ",", maxSplits: 1).map {
            clean(String($0))
        }
        guard let ingredientName = parts.first, !ingredientName.isEmpty else {
            return RecipeIngredient(originalText: original, presentationMode: .original)
        }

        return RecipeIngredient(
            originalText: original,
            presentationMode: .original,
            quantity: quantity,
            unitText: hasUnit ? remainder[0] : nil,
            ingredientText: ingredientName,
            preparation: parts.count > 1 ? parts[1] : nil,
            parseState: .parsed
        )
    }

    private static func quantity(_ token: String) -> QuantityExpression? {
        let normalized = token.replacingOccurrences(of: "-", with: "–")
        let rangeParts = normalized.split(separator: "–", maxSplits: 1).map(String.init)
        if rangeParts.count == 2,
           let lower = number(rangeParts[0]),
           let upper = number(rangeParts[1]) {
            return QuantityExpression(kind: .range, lowerBound: lower, upperBound: upper)
        }
        guard let exact = number(normalized) else { return nil }
        return QuantityExpression(kind: .exact, lowerBound: exact)
    }

    private static func number(_ source: String) -> RationalQuantity? {
        let value = source.trimmingCharacters(in: .whitespaces)
        let pieces = value.split(separator: " ", maxSplits: 1).map(String.init)
        if pieces.count == 2, let whole = Int(pieces[0]), let part = fraction(pieces[1]) {
            guard whole >= 0, whole <= ImportValueLimits.maximumQuantityComponent else { return nil }
            let (scaledWhole, multiplyOverflow) = whole.multipliedReportingOverflow(
                by: part.denominator
            )
            let (numerator, additionOverflow) = scaledWhole.addingReportingOverflow(part.numerator)
            guard !multiplyOverflow, !additionOverflow,
                  numerator <= ImportValueLimits.maximumQuantityComponent
            else { return nil }
            return RationalQuantity(
                numerator: numerator,
                denominator: part.denominator
            )
        }
        if let integer = Int(value),
           integer >= 0, integer <= ImportValueLimits.maximumQuantityComponent {
            return RationalQuantity(numerator: integer)
        }
        if let part = fraction(value) { return part }

        let unicodeFractions: [Character: RationalQuantity] = [
            "½": .init(numerator: 1, denominator: 2),
            "⅓": .init(numerator: 1, denominator: 3),
            "⅔": .init(numerator: 2, denominator: 3),
            "¼": .init(numerator: 1, denominator: 4),
            "¾": .init(numerator: 3, denominator: 4),
            "⅛": .init(numerator: 1, denominator: 8),
            "⅜": .init(numerator: 3, denominator: 8),
            "⅝": .init(numerator: 5, denominator: 8),
            "⅞": .init(numerator: 7, denominator: 8),
        ]
        guard let last = value.last, let fraction = unicodeFractions[last] else { return nil }
        let wholeText = String(value.dropLast())
        let whole = wholeText.isEmpty ? 0 : Int(wholeText)
        guard let whole, whole >= 0, whole <= ImportValueLimits.maximumQuantityComponent else {
            return nil
        }
        let (scaledWhole, multiplyOverflow) = whole.multipliedReportingOverflow(
            by: fraction.denominator
        )
        let (numerator, additionOverflow) = scaledWhole.addingReportingOverflow(fraction.numerator)
        guard !multiplyOverflow, !additionOverflow,
              numerator <= ImportValueLimits.maximumQuantityComponent
        else { return nil }
        return RationalQuantity(
            numerator: numerator,
            denominator: fraction.denominator
        )
    }

    private static func fraction(_ source: String) -> RationalQuantity? {
        let parts = source.split(separator: "/", maxSplits: 1)
        guard parts.count == 2,
              let numerator = Int(parts[0]),
              let denominator = Int(parts[1]),
              numerator >= 0,
              denominator > 0,
              numerator <= ImportValueLimits.maximumQuantityComponent,
              denominator <= ImportValueLimits.maximumQuantityComponent
        else { return nil }
        return RationalQuantity(numerator: numerator, denominator: denominator)
    }

    private static func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
