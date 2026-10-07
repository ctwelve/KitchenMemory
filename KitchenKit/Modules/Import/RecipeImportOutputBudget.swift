// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Marker error used when normalized values would exceed a model-output limit.
struct NormalizedOutputLimitExceeded: Error {}

/// Accounts for every variable-length value retained by an import draft.
///
/// JSON tree limits alone cannot bound the normalized model: one scalar can be
/// split into thousands of steps, and several individually valid fields can be
/// joined into a much larger value. This second, independent budget is debited
/// only after normalization, using UTF-8 byte counts because `String.count`
/// measures grapheme clusters rather than storage. Every debit compares against
/// the remaining allowance before subtraction, so hostile sizes cannot overflow
/// integer arithmetic.
struct NormalizedOutputBudget {
    private var remainingUTF8Bytes: Int

    init(maximumUTF8Bytes: Int) {
        remainingUTF8Bytes = maximumUTF8Bytes
    }

    mutating func validate(
        _ draft: RecipeImportDraft
    ) throws(NormalizedOutputLimitExceeded) {
        try consume(draft.title)
        try consume(draft.summary)
        try consume(draft.authorName)

        try consume(draft.source.title)
        try consume(draft.source.authorName)
        try consume(draft.source.publisherName)
        try consume(draft.source.canonicalURL)

        if let recipeYield = draft.recipeYield {
            try consume(recipeYield.quantity?.text)
            try consume(recipeYield.unitText)
            try consume(recipeYield.originalText)
        }

        try consume(draft.cuisines)
        try consume(draft.categories)
        try consume(draft.keywords)
        for imageURL in draft.imageURLs {
            try consume(imageURL)
        }

        for section in draft.ingredientSections {
            try consume(section.title)
            for ingredient in section.ingredients {
                try consume(ingredient.originalText)
                try consume(ingredient.customDisplayText)
                try consume(ingredient.quantity?.text)
                try consume(ingredient.unitText)
                try consume(ingredient.package?.quantity.text)
                try consume(ingredient.package?.unitText)
                try consume(ingredient.ingredientText)
                try consume(ingredient.preparation)
                try consume(ingredient.note)
            }
        }

        for section in draft.instructionSections {
            try consume(section.title)
            for step in section.steps {
                try consume(step.name)
                try consume(step.text)
            }
        }
    }

    private mutating func consume(
        _ values: [String]
    ) throws(NormalizedOutputLimitExceeded) {
        for value in values {
            try consume(value)
        }
    }

    private mutating func consume(
        _ value: URL?
    ) throws(NormalizedOutputLimitExceeded) {
        guard let value else { return }
        try consume(value.absoluteString)
    }

    private mutating func consume(
        _ value: String?
    ) throws(NormalizedOutputLimitExceeded) {
        guard let value else { return }
        let byteCount = value.utf8.count
        guard byteCount <= remainingUTF8Bytes else {
            throw NormalizedOutputLimitExceeded()
        }
        remainingUTF8Bytes -= byteCount
    }
}

/// Semantic limits keep syntactically valid web values within recipe-scale
/// ranges. They are deliberately generous rather than claims about what a
/// recipe "should" contain. Values outside them remain losslessly recoverable
/// from source evidence but are not promoted into trusted structured fields.
enum ImportValueLimits {
    static let maximumDurationSeconds = 366 * 24 * 60 * 60
    static let maximumQuantityComponent = 1_000_000
}
