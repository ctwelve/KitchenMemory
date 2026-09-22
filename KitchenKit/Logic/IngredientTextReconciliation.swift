// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Lossless completed-line or paste reconciliation for one existing IngredientSection.
///
/// Exact source matches retain their entire value, including identity and explicit precision.
/// Changed rows keep authored wording and retain explicit fields until the caller accepts a
/// proposal. This value is Codable so unresolved proposals can accompany a local editing draft.
public struct IngredientTextReconciliation: Codable, Equatable, Sendable {
    public struct Conflict: Codable, Equatable, Identifiable, Sendable {
        public var id: RecipeIngredient.ID { proposed.id }
        public let proposed: RecipeIngredient
    }

    public let section: IngredientSection
    public let conflicts: [Conflict]

    public static func reconcile(lines: [String], with section: IngredientSection,
                                 locale: Locale = .current) -> Self {
        var available = Dictionary(grouping: section.ingredients, by: \.originalText)
        var used: Set<RecipeIngredient.ID> = []
        let matched = lines.map { source -> RecipeIngredient? in
            guard var candidates = available[source], !candidates.isEmpty else { return nil }
            let ingredient = candidates.removeFirst()
            available[source] = candidates
            used.insert(ingredient.id)
            return ingredient
        }
        var remaining = section.ingredients.filter { !used.contains($0.id) }.makeIterator()
        var ingredients: [RecipeIngredient] = []
        var conflicts: [Conflict] = []
        for (index, source) in lines.enumerated() {
            if let unchanged = matched[index] { ingredients.append(unchanged); continue }
            guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let parsed = IngredientLineParser.parse(source, locale: locale)
            guard var previous = remaining.next() else { ingredients.append(parsed); continue }
            let protected = preservesPrecision(previous, locale: locale)
            var proposed = previous
            proposed.originalText = source
            proposed.quantity = parsed.quantity
            proposed.unitText = parsed.unitText
            proposed.package = parsed.package
            proposed.ingredientText = parsed.ingredientText
            proposed.preparation = parsed.preparation
            proposed.parseState = protected ? .reviewed : parsed.parseState
            if protected {
                previous.originalText = source
                ingredients.append(previous)
                conflicts.append(Conflict(proposed: proposed))
            } else {
                ingredients.append(proposed)
            }
        }
        return Self(section: IngredientSection(id: section.id, title: section.title, ingredients: ingredients),
                    conflicts: conflicts)
    }

    private static func preservesPrecision(_ ingredient: RecipeIngredient, locale: Locale) -> Bool {
        if ingredient.parseState == .reviewed || ingredient.parseState == .edited
            || ingredient.presentationMode != .original || ingredient.customDisplayText != nil
            || ingredient.note != nil || ingredient.isOptional || ingredient.scalingBehavior != .linear { return true }
        let automatic = IngredientLineParser.parse(ingredient.originalText, locale: locale)
        return ingredient.quantity != automatic.quantity || ingredient.unitText != automatic.unitText
            || ingredient.package != automatic.package || ingredient.ingredientText != automatic.ingredientText
            || ingredient.preparation != automatic.preparation
    }
}
