// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Intentionally conservative first-pass interpretation of display strings.
/// Anything not recognized stays useful through `originalText`.
public enum IngredientLineParser {
    private static let units: Set<String> = [
        "cup", "cups", "tablespoon", "tablespoons", "tbsp", "teaspoon",
        "teaspoons", "tsp", "ounce", "ounces", "oz", "pound", "pounds",
        "lb", "lbs", "gram", "grams", "g", "kilogram", "kilograms", "kg",
        "milliliter", "milliliters", "ml", "liter", "liters", "l",
        "pinch", "pinches", "clove", "cloves", "slice", "slices", "dl", "deciliter", "deciliters",
        "can", "cans", "package", "packages", "bunch", "bunches",
        "tasse", "tasses", "cuillère", "cuillères", "gramme", "grammes", "litre", "litres",
        "taza", "tazas", "cucharada", "cucharadas", "cucharadita", "cucharaditas", "gramo", "gramos",
        "tassen", "el", "tl", "gramm", "prise", "zehe", "zehen",
        "cucchiaio", "cucchiai", "cucchiaino", "cucchiaini", "tazza", "tazze", "grammi", "litri",
    ]

    /// Parses completed input. The authored source is never replaced by formatted values.
    public static func parse(_ source: String, locale: Locale = .current) -> RecipeIngredient {
        interpret(source, locale: locale).ingredient
    }

    /// Returns structured interpretation and UTF-16 source spans suitable for native text annotation.
    /// Call after completing/leaving a line, or once per pasted line, rather than rewriting active input.
    public static func interpret(_ source: String, locale: Locale = .current) -> IngredientLineInterpretation {
        var result = IngredientLineInterpretation(
            ingredient: RecipeIngredient(
                originalText: clean(source).isEmpty ? "" : source, presentationMode: .original),
            segments: [])
        let tokens = source.split(whereSeparator: \Character.isWhitespace)
        guard let first = tokens.first, let last = quantityEnd(tokens, locale: locale),
              let amount = quantity(String(source[first.startIndex..<last]), locale: locale)
        else { return result }
        result.ingredient.quantity = amount
        result.ingredient.parseState = .parsed
        result.append(.quantity, range: first.startIndex..<last, in: source)
        var remainder = source[last...].trimmingCharacters(in: .whitespacesAndNewlines)
        if let package = packagePrefix(remainder, locale: locale) {
            result.ingredient.package = package.value
            result.append(.package, text: package.source, in: source, after: last)
            remainder = clean(String(remainder.dropFirst(package.source.count)))
        }
        if remainder.isEmpty { return result }
        let unit = String(remainder.prefix(while: { !$0.isWhitespace }))
        if units.contains(unit.lowercased().trimmingCharacters(in: .punctuationCharacters)) {
            result.ingredient.unitText = unit
            result.append(.unit, text: unit, in: source,
                          afterUTF16: result.segments[result.segments.count - 1].utf16Range.upperBound)
            remainder = clean(String(remainder.dropFirst(unit.count)))
        }
        if remainder.isEmpty, result.ingredient.package == nil {
            return IngredientLineInterpretation(
                ingredient: RecipeIngredient(originalText: source, presentationMode: .original), segments: [])
        }
        let parts = remainder.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            .map { clean(String($0)) }
        result.ingredient.ingredientText = parts.first.flatMap { $0.isEmpty ? nil : $0 }
        result.ingredient.preparation = parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil
        if let name = result.ingredient.ingredientText {
            result.append(.ingredient, text: name, in: source,
                          afterUTF16: result.segments[result.segments.count - 1].utf16Range.upperBound)
        }
        if let preparation = result.ingredient.preparation {
            result.append(.preparation, text: preparation, in: source,
                          afterUTF16: result.segments[result.segments.count - 1].utf16Range.upperBound)
        }
        return result
    }

    private static func quantityEnd(_ tokens: [Substring], locale: Locale) -> String.Index? {
        guard let first = tokens.first else { return nil }
        // Bound language-prefix work; a longer phrase remains authored text.
        for count in (1...min(tokens.count, 7)).reversed() {
            let candidate = tokens.prefix(count).joined(separator: " ")
            guard quantity(candidate, locale: locale) != nil else { continue }
            if tokens.count > count, let next = tokens[count].first,
               next.isNumber || "-–/".contains(next) { return nil }
            return tokens[count - 1].endIndex > first.startIndex ? tokens[count - 1].endIndex : nil
        }
        return nil
    }

    private static func packagePrefix(_ source: String, locale: Locale)
        -> (value: PackageDescription, source: String)? {
        guard source.first == "(", let close = source.firstIndex(of: ")") else { return nil }
        let authored = clean(String(source[source.index(after: source.startIndex)..<close]))
        guard authored.first != "-", authored.first != "–" else { return nil }
        let inside = authored.replacingOccurrences(of: "-", with: " ")
        let parts = inside.split(whereSeparator: \Character.isWhitespace)
        guard parts.count >= 2, let unit = parts.last,
              units.contains(unit.lowercased().trimmingCharacters(in: .punctuationCharacters)),
              let amount = quantity(parts.dropLast().joined(separator: " "), locale: locale)
        else { return nil }
        return (PackageDescription(quantity: amount, unitText: String(unit)), String(source[...close]))
    }

    private static func quantity(_ token: String, locale: Locale) -> QuantityExpression? {
        if let word = numberWord(token, locale: locale) {
            return QuantityExpression(kind: .exact, lowerBound: word)
        }
        let normalized = token.replacingOccurrences(of: "-", with: "–")
        let rangeParts = normalized.split(separator: "–", maxSplits: 1, omittingEmptySubsequences: false)
            .map(String.init)
        if rangeParts.count == 2,
           let lower = number(rangeParts[0]),
           let upper = number(rangeParts[1]),
           lower.numerator * upper.denominator <= upper.numerator * lower.denominator {
            return QuantityExpression(kind: .range, lowerBound: lower, upperBound: upper)
        }
        guard let exact = number(normalized) else { return nil }
        return QuantityExpression(kind: .exact, lowerBound: exact)
    }

    private static func numberWord(_ token: String, locale: Locale) -> RationalQuantity? {
        guard token.first?.isLetter == true,
              ["en", "fr", "es", "de", "it"].contains(locale.language.languageCode?.identifier ?? "")
        else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .spellOut
        let word = token.lowercased(with: locale)
        guard let value = formatter.number(from: word),
              value.doubleValue >= 0, value.doubleValue <= 100,
              value.doubleValue == Double(value.intValue),
              formatter.string(from: value)?.lowercased(with: locale) == word
        else { return nil }
        return RationalQuantity(numerator: value.intValue)
    }

    private static func number(_ source: String) -> RationalQuantity? {
        let value = source.trimmingCharacters(in: .whitespaces)
        let pieces = value.split(whereSeparator: \Character.isWhitespace).map(String.init)
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
        if let decimal = decimal(value) { return decimal }

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

    private static func decimal(_ source: String) -> RationalQuantity? {
        let parts = source.split(omittingEmptySubsequences: false) { $0 == "." || $0 == "," }
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty,
              parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              parts[1].count <= 6,
              // A three-digit suffix could be grouping; do not invent precision.
              !(parts[1].count == 3 && parts[0] != "0"),
              let numerator = Int(parts.joined()), numerator <= ImportValueLimits.maximumQuantityComponent
        else { return nil }
        let denominator = (0..<parts[1].count).reduce(1) { value, _ in value * 10 }
        return RationalQuantity(numerator: numerator, denominator: denominator).normalized
    }

    private static func fraction(_ source: String) -> RationalQuantity? {
        let parts = source.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
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
