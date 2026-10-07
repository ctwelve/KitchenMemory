// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Algorithms
import Foundation

/// Maps admitted Schema.org fields to recipe metadata and normalized content.
enum SchemaOrgRecipeDraftNormalizer {
    static func consumedFieldsAreWithinLimits(
        _ object: [String: Any],
        limits: RecipeImportLimits
    ) -> Bool {
        let ordinaryFields = [
            "name", "description", "author", "publisher", "url", "mainEntityOfPage",
            "recipeYield", "prepTime", "cookTime", "totalTime", "inLanguage", "recipeCuisine",
            "recipeCategory", "keywords", "image",
        ]
        for key in ordinaryFields {
            guard ConsumedFieldPreflight.isWithinLimits(
                object[key],
                maximumNodes: 2_000,
                maximumCollectionElements: 2_000,
                maximumCharacters: limits.maximumFieldCharacters
            ) else { return false }
        }
        guard ConsumedFieldPreflight.isWithinLimits(
            object["recipeIngredient"],
            maximumNodes: saturatedProduct(limits.maximumIngredients, 16),
            maximumCollectionElements: limits.maximumIngredients,
            maximumCharacters: limits.maximumFieldCharacters
        ) else { return false }
        return ConsumedFieldPreflight.isWithinLimits(
            object["recipeInstructions"],
            maximumNodes: saturatedProduct(limits.maximumInstructionItems, 16),
            maximumCollectionElements: saturatedProduct(limits.maximumInstructionItems, 2),
            maximumCharacters: limits.maximumFieldCharacters
        )
    }

    // swiftlint:disable:next function_body_length
    static func makeDraft(
        from object: [String: Any],
        title: String,
        documentURL: URL?,
        limits: RecipeImportLimits
    ) throws(NormalizedOutputLimitExceeded) -> RecipeImportDraft {
        let canonicalURL = resolvedWebURL(
            from: object["url"],
            relativeTo: documentURL
        ) ?? resolvedMainEntityURL(
            object["mainEntityOfPage"],
            relativeTo: documentURL
        ) ?? documentURL
        let author = try authorName(
            object["author"],
            maximumCharacters: limits.maximumFieldCharacters,
            maximumUTF8Bytes: limits.maximumNormalizedUTF8Bytes
        )
        var remainingTaxonomyItems = limits.maximumTaxonomyItems
        let cuisines = try cleanedStrings(
            object["recipeCuisine"],
            remaining: &remainingTaxonomyItems
        )
        let categories = try cleanedStrings(
            object["recipeCategory"],
            remaining: &remainingTaxonomyItems
        )
        let keywords = try keywords(
            object["keywords"],
            remaining: &remainingTaxonomyItems
        )

        let draft = RecipeImportDraft(
            title: SchemaOrgValue.cleanText(title),
            summary: SchemaOrgValue.text(object["description"]).map(SchemaOrgValue.cleanText),
            authorName: author,
            contentLanguage: contentLanguage(object["inLanguage"]),
            source: RecipeSource(
                kind: .webpage,
                title: SchemaOrgValue.cleanText(title),
                authorName: author,
                publisherName: publisherName(object["publisher"]),
                canonicalURL: canonicalURL
            ),
            recipeYield: yield(object["recipeYield"]),
            prepDuration: duration(object["prepTime"]),
            cookDuration: duration(object["cookTime"]),
            totalDuration: duration(object["totalTime"]),
            cuisines: cuisines,
            categories: categories,
            keywords: keywords,
            imageURLs: try imageURLs(
                object["image"],
                relativeTo: documentURL,
                maximum: limits.maximumImageURLs
            ),
            ingredientSections: try SchemaOrgRecipeContentNormalizer.ingredientSections(
                object["recipeIngredient"],
                maximum: limits.maximumIngredients,
                maximumFieldCharacters: limits.maximumFieldCharacters,
                maximumUTF8Bytes: limits.maximumNormalizedUTF8Bytes
            ),
            instructionSections: try SchemaOrgRecipeContentNormalizer.instructionSections(
                object["recipeInstructions"],
                maximumItems: limits.maximumInstructionItems
            )
        )
        return draft
    }

}

private extension SchemaOrgRecipeDraftNormalizer {
    static func contentLanguage(_ value: Any?) -> RecipeContentLanguage? {
        if let identifier = SchemaOrgValue.text(value) {
            return RecipeContentLanguage(rawValue: identifier)
        }
        guard let object = value as? [String: Any] else { return nil }
        return SchemaOrgValue.text(object["@id"]).flatMap(RecipeContentLanguage.init(rawValue:))
            ?? SchemaOrgValue.text(object["name"]).flatMap(RecipeContentLanguage.init(rawValue:))
    }

    static func resolvedMainEntityURL(_ value: Any?, relativeTo baseURL: URL?) -> URL? {
        guard let object = value as? [String: Any] else {
            return resolvedWebURL(from: value, relativeTo: baseURL)
        }
        return resolvedWebURL(from: object["@id"], relativeTo: baseURL)
            ?? resolvedWebURL(from: object["url"], relativeTo: baseURL)
    }

    static func authorName(
        _ value: Any?,
        maximumCharacters: Int,
        maximumUTF8Bytes: Int
    ) throws(NormalizedOutputLimitExceeded) -> String? {
        if let direct = SchemaOrgValue.text(value) { return SchemaOrgValue.cleanText(direct) }
        if let values = value as? [Any] {
            var result = ""
            result.reserveCapacity(min(maximumCharacters, 256))
            var charactersUsed = 0
            var utf8BytesUsed = 0
            for value in values {
                guard let name = try authorName(
                    value,
                    maximumCharacters: maximumCharacters,
                    maximumUTF8Bytes: maximumUTF8Bytes
                ) else { continue }
                try SchemaOrgValue.appendBounded(
                    name,
                    to: &result,
                    separator: ", ",
                    charactersUsed: &charactersUsed,
                    utf8BytesUsed: &utf8BytesUsed,
                    maximumCharacters: maximumCharacters,
                    maximumUTF8Bytes: maximumUTF8Bytes
                )
            }
            return result.isEmpty ? nil : result
        }
        guard let object = value as? [String: Any] else { return nil }
        return SchemaOrgValue.text(object["name"]).map(SchemaOrgValue.cleanText)
    }

    static func publisherName(_ value: Any?) -> String? {
        guard let object = value as? [String: Any] else {
            return SchemaOrgValue.text(value).map(SchemaOrgValue.cleanText)
        }
        return SchemaOrgValue.text(object["name"]).map(SchemaOrgValue.cleanText)
    }

    static func yield(_ value: Any?) -> RecipeYield? {
        if let values = value as? [Any] {
            guard let first = values.firstNonNil(SchemaOrgValue.cleanedNonemptyText) else { return nil }
            return RecipeYield(originalText: first)
        }
        if let object = value as? [String: Any] {
            guard let original = SchemaOrgValue.cleanedNonemptyText(object["value"])
                ?? SchemaOrgValue.cleanedNonemptyText(object["name"])
            else { return nil }
            return RecipeYield(
                unitText: SchemaOrgValue.cleanedNonemptyText(object["unitText"]),
                originalText: original
            )
        }
        guard let original = SchemaOrgValue.cleanedNonemptyText(value) else { return nil }
        return RecipeYield(originalText: original)
    }

    static func duration(_ value: Any?) -> RecipeDuration? {
        guard let string = SchemaOrgValue.text(value)?.uppercased() else { return nil }
        let pattern = #"^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string))
        else { return nil }
        func component(_ index: Int) -> Int? {
            guard let range = Range(match.range(at: index), in: string) else { return 0 }
            return Int(string[range])
        }
        guard let days = component(1), let hours = component(2),
              let minutes = component(3), let seconds = component(4)
        else { return nil }

        // These values came from an untrusted JSON string. Swift deliberately
        // traps on integer overflow, so ordinary `days * 86_400` arithmetic
        // would let a webpage terminate the process. Checked operations turn an
        // unrepresentable duration into an omitted interpretation; the exact
        // JSON-LD remains available in the immutable source capture.
        var total = 0
        for (component, multiplier) in [
            (days, 86_400), (hours, 3_600), (minutes, 60), (seconds, 1),
        ] {
            let (subtotal, multiplyOverflow) = component.multipliedReportingOverflow(by: multiplier)
            let (newTotal, additionOverflow) = total.addingReportingOverflow(subtotal)
            guard !multiplyOverflow, !additionOverflow else { return nil }
            total = newTotal
        }
        guard total > 0, total <= ImportValueLimits.maximumDurationSeconds else { return nil }
        return RecipeDuration(seconds: total)
    }

    static func keywords(
        _ value: Any?,
        remaining: inout Int
    ) throws(NormalizedOutputLimitExceeded) -> [String] {
        if let string = SchemaOrgValue.scalarText(value) {
            var output: [String] = []
            output.reserveCapacity(min(remaining, 16))
            let scalars = string.unicodeScalars
            var pieceStart = scalars.startIndex
            var cursor = scalars.startIndex

            func appendPiece(
                endingAt end: String.UnicodeScalarView.Index
            ) throws(NormalizedOutputLimitExceeded) {
                let cleaned = SchemaOrgValue.cleanText(String(scalars[pieceStart..<end]))
                guard !cleaned.isEmpty else { return }
                guard remaining > 0 else { throw NormalizedOutputLimitExceeded() }
                remaining -= 1
                output.append(cleaned)
            }

            while cursor < scalars.endIndex {
                guard scalars[cursor].value == 0x2C else {
                    cursor = scalars.index(after: cursor)
                    continue
                }
                try appendPiece(endingAt: cursor)
                cursor = scalars.index(after: cursor)
                pieceStart = cursor
            }
            try appendPiece(endingAt: scalars.endIndex)
            return output
        }
        return try cleanedStrings(value, remaining: &remaining)
    }

    static func cleanedStrings(
        _ value: Any?,
        remaining: inout Int
    ) throws(NormalizedOutputLimitExceeded) -> [String] {
        var output: [String] = []
        var stack = value.map { [$0] } ?? []
        while let next = stack.popLast() {
            if let string = next as? String {
                let cleaned = SchemaOrgValue.cleanText(string)
                guard !cleaned.isEmpty else { continue }
                guard remaining > 0 else { throw NormalizedOutputLimitExceeded() }
                remaining -= 1
                output.append(cleaned)
            } else if let number = next as? NSNumber {
                let cleaned = SchemaOrgValue.cleanText(number.stringValue)
                guard !cleaned.isEmpty else { continue }
                guard remaining > 0 else { throw NormalizedOutputLimitExceeded() }
                remaining -= 1
                output.append(cleaned)
            } else if let array = next as? [Any] {
                stack.append(contentsOf: array.reversed())
            }
        }
        return output
    }

    static func imageURLs(
        _ value: Any?,
        relativeTo baseURL: URL?,
        maximum: Int
    ) throws(NormalizedOutputLimitExceeded) -> [URL] {
        if let array = value as? [Any] {
            var output: [URL] = []
            output.reserveCapacity(min(array.count, maximum))
            for item in array {
                guard let url = resolvedImageURL(item, relativeTo: baseURL) else { continue }
                guard output.count < maximum else { throw NormalizedOutputLimitExceeded() }
                output.append(url)
            }
            return output
        }
        return resolvedImageURL(value, relativeTo: baseURL).map { [$0] } ?? []
    }

    static func resolvedImageURL(_ value: Any?, relativeTo baseURL: URL?) -> URL? {
        if let object = value as? [String: Any] {
            return resolvedWebURL(
                from: object["url"] ?? object["contentUrl"],
                relativeTo: baseURL
            )
        }
        return resolvedWebURL(from: value, relativeTo: baseURL)
    }

    /// Resolves a publisher-provided link without promoting arbitrary URL
    /// schemes into an active application link.
    ///
    /// JSON-LD is untrusted data. `URL(string:)` also accepts `file:`, custom
    /// application schemes, credentials, and private literal destinations.
    /// Keeping only structurally public HTTP(S) URLs prevents a recipe from
    /// turning passive metadata into a surprising local or inter-app action.
    /// The untouched value remains in the captured JSON-LD if future correction
    /// or parser improvements need it.
    static func resolvedWebURL(from value: Any?, relativeTo baseURL: URL?) -> URL? {
        guard let string = SchemaOrgValue.text(value)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !string.isEmpty
        else { return nil }
        guard let url = URL(string: string, relativeTo: baseURL)?.absoluteURL,
              URLSessionRecipeDocumentLoader.isStructurallyAllowedSourceURL(url)
        else { return nil }
        return url
    }

    /// Multiplies a caller-selected model ceiling without letting an extreme
    /// (but otherwise valid) configuration trap before untrusted input is read.
    static func saturatedProduct(_ value: Int, _ multiplier: Int) -> Int {
        let (product, overflow) = value.multipliedReportingOverflow(by: multiplier)
        return overflow ? Int.max : product
    }

}

private enum ConsumedFieldPreflight {
    /// Bounds only values that Kitchen Memory interprets. Large unknown fields
    /// remain available in source evidence and do not make an otherwise useful
    /// recipe fail simply because the publisher included unrelated metadata.
    static func isWithinLimits(
        _ root: Any?,
        maximumNodes: Int,
        maximumCollectionElements: Int,
        maximumCharacters: Int
    ) -> Bool {
        guard let root else { return true }
        var remainingNodes = maximumNodes
        var remainingCollectionElements = maximumCollectionElements
        var stack: [Any] = [root]
        while let value = stack.popLast() {
            guard remainingNodes > 0 else { return false }
            remainingNodes -= 1
            if let text = value as? String {
                guard text.count <= maximumCharacters else { return false }
            } else if let array = value as? [Any] {
                guard array.count <= remainingCollectionElements else { return false }
                remainingCollectionElements -= array.count
                stack.append(contentsOf: array)
            } else if let object = value as? [String: Any] {
                stack.append(contentsOf: object.values)
            }
        }
        return true
    }
}
