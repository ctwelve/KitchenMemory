// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Lossless completed-line or paste reconciliation for one existing IngredientSection.
///
/// Callers retain line identities across text edits. Unchanged identified lines retain their entire value.
/// Changed rows keep authored wording and retain explicit fields until the caller accepts a
/// proposal. This value is Codable so unresolved proposals can accompany a local editing draft.
public struct IngredientTextReconciliation: Codable, Equatable, Sendable {
    public struct Conflict: Codable, Equatable, Identifiable, Sendable {
        public var id: RecipeIngredient.ID { proposed.id }
        public let proposed: RecipeIngredient
    }

    public let section: IngredientSection
    public let conflicts: [Conflict]

    public struct Line: Codable, Equatable, Sendable {
        public let ingredientID: RecipeIngredient.ID?
        public let source: String

        public init(ingredientID: RecipeIngredient.ID? = nil, source: String) {
            self.ingredientID = ingredientID
            self.source = source
        }
    }

    /// Existing rows must carry their identity. New pasted lines have no identity; this method
    /// never guesses a correspondence from similar wording or position. Duplicate/unknown IDs
    /// are treated as new rows, so they cannot steal an existing ingredient's precise fields.
    public static func reconcile(lines: [Line], with section: IngredientSection,
                                 locale: Locale = .current) -> Self {
        let existing = Dictionary(uniqueKeysWithValues: section.ingredients.map { ($0.id, $0) })
        var used: Set<RecipeIngredient.ID> = []
        var ingredients: [RecipeIngredient] = []
        var conflicts: [Conflict] = []
        for line in lines {
            let source = line.source
            let original = line.ingredientID.flatMap { used.insert($0).inserted ? existing[$0] : nil }
            if let original, original.originalText == source { ingredients.append(original); continue }
            guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            let parsed = IngredientLineParser.parse(source, locale: locale)
            guard var previous = original else { ingredients.append(parsed); continue }
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
