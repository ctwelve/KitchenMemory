// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain

// The deterministic parser and its bounded scanners stay together so its
// safety limits can be audited as one boundary.
// swiftlint:disable file_length

/// A deterministic importer for already-captured HTML and JSON-LD.
///
/// This type deliberately has no network or persistence dependency. Callers
/// retain control of acquisition, candidate choice, review, and saving.
public struct SchemaOrgRecipeImporter: Sendable {
    public let limits: RecipeImportLimits

    public init(limits: RecipeImportLimits = .init()) {
        self.limits = limits
    }

    public func importHTML(_ html: String, documentURL: URL? = nil) -> RecipeImportResult {
        guard html.utf8.count <= limits.maximumInputBytes else {
            return Self.limitExceededResult(.inputBytes)
        }
        let discovery = Self.jsonLDBlocks(in: html, maximum: limits.maximumJSONLDBlocks)
        guard !discovery.exceededLimit else {
            return Self.limitExceededResult(.jsonLDBlocks)
        }
        return importJSONLDBlocks(discovery.blocks, documentURL: documentURL)
    }

    public func importJSONLD(_ data: Data, documentURL: URL? = nil) -> RecipeImportResult {
        importJSONLDBlocks([data], documentURL: documentURL)
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func importJSONLDBlocks(_ blocks: [Data], documentURL: URL?) -> RecipeImportResult {
        var candidates: [RecipeImportCandidate] = []
        var diagnostics: [RecipeImportDiagnostic] = []
        var normalizedOutputBudget = NormalizedOutputBudget(
            maximumUTF8Bytes: limits.maximumNormalizedUTF8Bytes
        )

        for (blockIndex, sourceData) in blocks.enumerated() {
            let data: Data
            do {
                data = try JSONTextNormalizer.normalizedUTF8(
                    from: sourceData,
                    maximumBytes: limits.maximumInputBytes
                )
            } catch {
                switch error {
                case .tooLarge:
                    diagnostics.append(.init(
                        blockIndex: blockIndex,
                        kind: .processingLimitExceeded(.inputBytes)
                    ))
                    return RecipeImportResult(candidates: [], diagnostics: diagnostics)
                case .invalidEncoding:
                    diagnostics.append(.init(blockIndex: blockIndex, kind: .malformedJSONLD))
                    continue
                }
            }
            guard JSONStructurePreflight.isWithinLimits(data, limits: limits) else {
                diagnostics.append(.init(
                    blockIndex: blockIndex,
                    kind: .processingLimitExceeded(.jsonStructure)
                ))
                return RecipeImportResult(candidates: [], diagnostics: diagnostics)
            }
            let value: Any
            do {
                value = try JSONSerialization.jsonObject(with: data)
            } catch {
                diagnostics.append(.init(blockIndex: blockIndex, kind: .malformedJSONLD))
                continue
            }

            guard let objects = Self.topLevelObjects(
                in: value,
                maximum: limits.maximumTopLevelObjects
            ) else {
                diagnostics.append(.init(
                    blockIndex: blockIndex,
                    kind: .processingLimitExceeded(.topLevelObjects)
                ))
                return RecipeImportResult(candidates: [], diagnostics: diagnostics)
            }
            if objects.isEmpty {
                diagnostics.append(.init(blockIndex: blockIndex, kind: .unsupportedTopLevel))
                continue
            }

            for (objectIndex, object) in objects.enumerated() where Self.isRecipe(object) {
                guard candidates.count < limits.maximumCandidates else {
                    diagnostics.append(.init(
                        blockIndex: blockIndex,
                        kind: .processingLimitExceeded(.candidates)
                    ))
                    return RecipeImportResult(candidates: [], diagnostics: diagnostics)
                }
                guard Self.consumedFieldsAreWithinLimits(object, limits: limits) else {
                    diagnostics.append(.init(
                        blockIndex: blockIndex,
                        kind: .processingLimitExceeded(.consumedFields)
                    ))
                    return RecipeImportResult(candidates: [], diagnostics: diagnostics)
                }
                let title: String
                if let sourceTitle = Self.text(object["name"]) {
                    title = sourceTitle
                } else {
                    title = ""
                    diagnostics.append(.init(blockIndex: blockIndex, kind: .missingTitle))
                }
                let draft: RecipeImportDraft
                do {
                    draft = try Self.makeDraft(
                        from: object,
                        title: title,
                        documentURL: documentURL,
                        limits: limits,
                        normalizedOutputBudget: &normalizedOutputBudget
                    )
                } catch {
                    diagnostics.append(.init(
                        blockIndex: blockIndex,
                        kind: .processingLimitExceeded(.normalizedOutput)
                    ))
                    return RecipeImportResult(candidates: [], diagnostics: diagnostics)
                }
                let snapshot = RecipeImportSourceSnapshot(
                    documentURL: documentURL,
                    jsonLD: data
                )
                candidates.append(
                    RecipeImportCandidate(
                        id: .init(blockIndex: blockIndex, objectIndex: objectIndex),
                        draft: draft,
                        snapshot: snapshot
                    )
                )
            }
        }

        return RecipeImportResult(candidates: candidates, diagnostics: diagnostics)
    }

    private static func limitExceededResult(
        _ limit: RecipeImportDiagnostic.ProcessingLimit
    ) -> RecipeImportResult {
        RecipeImportResult(
            candidates: [],
            diagnostics: [.init(blockIndex: 0, kind: .processingLimitExceeded(limit))]
        )
    }
}

private extension SchemaOrgRecipeImporter {
    static func jsonLDBlocks(in html: String, maximum: Int) -> (blocks: [Data], exceededLimit: Bool) {
        HTMLJSONLDBlockScanner.scan(html, maximumBlocks: maximum)
    }

    static func topLevelObjects(in value: Any, maximum: Int) -> [[String: Any]]? {
        var objects: [[String: Any]] = []
        var stack: [Any] = [value]
        while let next = stack.popLast() {
            if let array = next as? [Any] {
                stack.append(contentsOf: array.reversed())
                continue
            }
            guard let object = next as? [String: Any] else { continue }
            guard objects.count < maximum else { return nil }
            objects.append(object)
            if let graph = object["@graph"] as? [Any] {
                stack.append(contentsOf: graph.reversed())
            }
        }
        return objects
    }

    static func isRecipe(_ object: [String: Any]) -> Bool {
        strings(object["@type"]).contains { type in
            type.split(separator: "/").last?.caseInsensitiveCompare("Recipe") == .orderedSame
        }
    }

    static func consumedFieldsAreWithinLimits(
        _ object: [String: Any],
        limits: RecipeImportLimits
    ) -> Bool {
        let ordinaryFields = [
            "name", "description", "author", "publisher", "url", "mainEntityOfPage",
            "recipeYield", "prepTime", "cookTime", "totalTime", "recipeCuisine",
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
        limits: RecipeImportLimits,
        normalizedOutputBudget: inout NormalizedOutputBudget
    ) throws(NormalizedOutputLimitExceeded) -> RecipeImportDraft {
        let canonicalURL = resolvedWebURL(
            from: object["url"] ?? mainEntityURL(object["mainEntityOfPage"]),
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
            title: cleanText(title),
            summary: text(object["description"]).map(cleanText),
            authorName: author,
            source: RecipeSource(
                kind: .webpage,
                title: cleanText(title),
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
            ingredientSections: try ingredientSections(
                object["recipeIngredient"],
                maximum: limits.maximumIngredients,
                maximumFieldCharacters: limits.maximumFieldCharacters,
                maximumUTF8Bytes: limits.maximumNormalizedUTF8Bytes
            ),
            instructionSections: try instructionSections(
                object["recipeInstructions"],
                maximumItems: limits.maximumInstructionItems
            )
        )
        try normalizedOutputBudget.validate(draft)
        return draft
    }

    static func mainEntityURL(_ value: Any?) -> Any? {
        guard let object = value as? [String: Any] else { return value }
        return object["@id"] ?? object["url"]
    }

    static func authorName(
        _ value: Any?,
        maximumCharacters: Int,
        maximumUTF8Bytes: Int
    ) throws(NormalizedOutputLimitExceeded) -> String? {
        if let direct = text(value) { return cleanText(direct) }
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
                try appendBounded(
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
        return text(object["name"]).map(cleanText)
    }

    static func publisherName(_ value: Any?) -> String? {
        guard let object = value as? [String: Any] else { return text(value).map(cleanText) }
        return text(object["name"]).map(cleanText)
    }

    static func yield(_ value: Any?) -> RecipeYield? {
        if let original = text(value) {
            return RecipeYield(originalText: cleanText(original))
        }
        if let first = (value as? [Any])?.compactMap(text).first {
            return RecipeYield(originalText: cleanText(first))
        }
        guard let object = value as? [String: Any] else { return nil }
        let original = text(object["value"]) ?? text(object["name"])
        guard let original else { return nil }
        return RecipeYield(unitText: text(object["unitText"]), originalText: cleanText(original))
    }

    static func duration(_ value: Any?) -> RecipeDuration? {
        guard let string = text(value)?.uppercased() else { return nil }
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
        if let string = scalarText(value) {
            var output: [String] = []
            output.reserveCapacity(min(remaining, 16))
            let scalars = string.unicodeScalars
            var pieceStart = scalars.startIndex
            var cursor = scalars.startIndex

            func appendPiece(
                endingAt end: String.UnicodeScalarView.Index
            ) throws(NormalizedOutputLimitExceeded) {
                let cleaned = cleanText(String(scalars[pieceStart..<end]))
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
                let cleaned = cleanText(string)
                guard !cleaned.isEmpty else { continue }
                guard remaining > 0 else { throw NormalizedOutputLimitExceeded() }
                remaining -= 1
                output.append(cleaned)
            } else if let number = next as? NSNumber {
                let cleaned = cleanText(number.stringValue)
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
        guard let string = text(value) else { return nil }
        guard let url = URL(string: string, relativeTo: baseURL)?.absoluteURL,
              URLSessionRecipeDocumentLoader.isStructurallyAllowedSourceURL(url)
        else { return nil }
        return url
    }

    static func ingredientSections(
        _ value: Any?,
        maximum: Int,
        maximumFieldCharacters: Int,
        maximumUTF8Bytes: Int
    ) throws(NormalizedOutputLimitExceeded) -> [IngredientSection] {
        let values = value as? [Any] ?? value.map { [$0] } ?? []
        guard values.count <= maximum else { throw NormalizedOutputLimitExceeded() }
        var ingredients: [RecipeIngredient] = []
        ingredients.reserveCapacity(values.count)
        for value in values {
            guard let text = try ingredientText(
                value,
                maximumFieldCharacters: maximumFieldCharacters,
                maximumUTF8Bytes: maximumUTF8Bytes
            ) else { continue }
            guard ingredients.count < maximum else { throw NormalizedOutputLimitExceeded() }
            ingredients.append(IngredientLineParser.parse(text))
        }
        return ingredients.isEmpty ? [] : [IngredientSection(ingredients: ingredients)]
    }

    static func ingredientText(
        _ value: Any,
        maximumFieldCharacters: Int,
        maximumUTF8Bytes: Int
    ) throws(NormalizedOutputLimitExceeded) -> String? {
        if let string = scalarText(value) { return string }
        guard let object = value as? [String: Any] else { return nil }
        if let value = text(object["value"]), let unit = text(object["unitText"]) {
            var result = ""
            var charactersUsed = 0
            var utf8BytesUsed = 0
            try appendBounded(
                value,
                to: &result,
                separator: "",
                charactersUsed: &charactersUsed,
                utf8BytesUsed: &utf8BytesUsed,
                maximumCharacters: maximumFieldCharacters,
                maximumUTF8Bytes: maximumUTF8Bytes
            )
            try appendBounded(
                unit,
                to: &result,
                separator: " ",
                charactersUsed: &charactersUsed,
                utf8BytesUsed: &utf8BytesUsed,
                maximumCharacters: maximumFieldCharacters,
                maximumUTF8Bytes: maximumUTF8Bytes
            )
            return result
        }
        return text(object["value"]) ?? text(object["name"])
    }

    static func instructionSections(
        _ value: Any?,
        maximumItems: Int
    ) throws(NormalizedOutputLimitExceeded) -> [InstructionSection] {
        var remainingItems = maximumItems
        if let string = scalarText(value) {
            let steps = try splitInstructionText(string, remainingItems: &remainingItems)
            return steps.isEmpty ? [] : [InstructionSection(steps: steps)]
        }
        let values = value as? [Any] ?? value.map { [$0] } ?? []
        var looseSteps: [InstructionStep] = []
        var sections: [InstructionSection] = []

        for value in values {
            if let string = scalarText(value) {
                looseSteps.append(try instructionStep(
                    text: string,
                    name: nil,
                    remainingItems: &remainingItems
                ))
                continue
            }
            guard let object = value as? [String: Any] else { continue }
            if hasType(object, "HowToSection") {
                let childValues = object["itemListElement"] as? [Any] ?? []
                let steps = try instructionSteps(
                    childValues,
                    remainingItems: &remainingItems
                )
                if !steps.isEmpty {
                    sections.append(InstructionSection(title: text(object["name"]).map(cleanText), steps: steps))
                }
            } else if let step = try instructionStep(
                object,
                remainingItems: &remainingItems
            ) {
                looseSteps.append(step)
            }
        }
        if !looseSteps.isEmpty { sections.insert(InstructionSection(steps: looseSteps), at: 0) }
        return sections
    }

    static func instructionSteps(
        _ values: [Any],
        remainingItems: inout Int
    ) throws(NormalizedOutputLimitExceeded) -> [InstructionStep] {
        var steps: [InstructionStep] = []
        steps.reserveCapacity(min(values.count, remainingItems))
        for value in values {
            if let string = scalarText(value) {
                steps.append(try instructionStep(
                    text: string,
                    name: nil,
                    remainingItems: &remainingItems
                ))
                continue
            }
            guard let object = value as? [String: Any] else { continue }
            if hasType(object, "HowToSection") {
                steps.append(contentsOf: try instructionSteps(
                    object["itemListElement"] as? [Any] ?? [],
                    remainingItems: &remainingItems
                ))
            } else if let step = try instructionStep(
                object,
                remainingItems: &remainingItems
            ) {
                steps.append(step)
            }
        }
        return steps
    }

    static func instructionStep(
        _ object: [String: Any],
        remainingItems: inout Int
    ) throws(NormalizedOutputLimitExceeded) -> InstructionStep? {
        guard let body = text(object["text"]) ?? text(object["name"]) else { return nil }
        return try instructionStep(
            text: body,
            name: text(object["name"]),
            remainingItems: &remainingItems
        )
    }

    static func instructionStep(
        text: String,
        name: String?,
        remainingItems: inout Int
    ) throws(NormalizedOutputLimitExceeded) -> InstructionStep {
        guard remainingItems > 0 else { throw NormalizedOutputLimitExceeded() }
        remainingItems -= 1
        return InstructionStep(
            name: name.map(cleanText),
            text: cleanText(text)
        )
    }

    /// Emits newline-delimited steps incrementally so a short scalar cannot
    /// allocate thousands of model objects before the item ceiling is noticed.
    static func splitInstructionText(
        _ value: String,
        remainingItems: inout Int
    ) throws(NormalizedOutputLimitExceeded) -> [InstructionStep] {
        var steps: [InstructionStep] = []
        steps.reserveCapacity(min(remainingItems, 32))
        let scalars = value.unicodeScalars
        var lineStart = scalars.startIndex
        var cursor = scalars.startIndex

        func appendLine(
            endingAt end: String.UnicodeScalarView.Index
        ) throws(NormalizedOutputLimitExceeded) {
            let line = String(scalars[lineStart..<end])
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            steps.append(try instructionStep(
                text: line,
                name: nil,
                remainingItems: &remainingItems
            ))
        }

        while cursor < scalars.endIndex {
            let scalar = scalars[cursor]
            guard CharacterSet.newlines.contains(scalar) else {
                cursor = scalars.index(after: cursor)
                continue
            }
            try appendLine(endingAt: cursor)
            var next = scalars.index(after: cursor)
            if scalar.value == 0x0D,
               next < scalars.endIndex,
               scalars[next].value == 0x0A {
                next = scalars.index(after: next)
            }
            cursor = next
            lineStart = next
        }
        try appendLine(endingAt: scalars.endIndex)
        return steps
    }

    static func hasType(_ object: [String: Any], _ expected: String) -> Bool {
        strings(object["@type"]).contains { $0.caseInsensitiveCompare(expected) == .orderedSame }
    }

    static func strings(_ value: Any?) -> [String] {
        if let string = value as? String { return [string] }
        if let number = value as? NSNumber { return [number.stringValue] }
        if let array = value as? [Any] { return array.flatMap(strings) }
        return []
    }

    static func text(_ value: Any?) -> String? {
        strings(value).first
    }

    static func scalarText(_ value: Any?) -> String? {
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    // The explicit arguments make every independently bounded collection clear
    // at the call site.
    // swiftlint:disable function_parameter_count
    /// Appends a joined field without first allocating an unbounded temporary.
    /// Both counters are maintained by the caller so repeated appends never
    /// recompute `String.count` over an ever-growing result.
    static func appendBounded(
        _ value: String,
        to output: inout String,
        separator: String,
        charactersUsed: inout Int,
        utf8BytesUsed: inout Int,
        maximumCharacters: Int,
        maximumUTF8Bytes: Int
    ) throws(NormalizedOutputLimitExceeded) {
        guard charactersUsed >= 0,
              charactersUsed <= maximumCharacters,
              utf8BytesUsed >= 0,
              utf8BytesUsed <= maximumUTF8Bytes
        else { throw NormalizedOutputLimitExceeded() }
        let actualSeparator = output.isEmpty ? "" : separator
        let separatorCharacters = actualSeparator.count
        let separatorBytes = actualSeparator.utf8.count
        let valueCharacters = value.count
        let valueBytes = value.utf8.count
        guard separatorCharacters <= maximumCharacters - charactersUsed,
              valueCharacters <= maximumCharacters - charactersUsed - separatorCharacters,
              separatorBytes <= maximumUTF8Bytes - utf8BytesUsed,
              valueBytes <= maximumUTF8Bytes - utf8BytesUsed - separatorBytes
        else { throw NormalizedOutputLimitExceeded() }

        output.append(actualSeparator)
        output.append(value)
        charactersUsed += separatorCharacters + valueCharacters
        utf8BytesUsed += separatorBytes + valueBytes
    }
    // swiftlint:enable function_parameter_count

    /// Multiplies a caller-selected model ceiling without letting an extreme
    /// (but otherwise valid) configuration trap before untrusted input is read.
    static func saturatedProduct(_ value: Int, _ multiplier: Int) -> Int {
        let (product, overflow) = value.multipliedReportingOverflow(by: multiplier)
        return overflow ? Int.max : product
    }

    static func cleanText(_ value: String) -> String {
        ImportedPlainTextNormalizer.normalize(value)
    }
}

/// Marker error used when normalized values would exceed a model-output limit.
private struct NormalizedOutputLimitExceeded: Error {}

/// Accounts for every variable-length value retained by an import draft.
///
/// JSON tree limits alone cannot bound the normalized model: one scalar can be
/// split into thousands of steps, and several individually valid fields can be
/// joined into a much larger value. This second, independent budget is debited
/// only after normalization, using UTF-8 byte counts because `String.count`
/// measures grapheme clusters rather than storage. Every debit compares against
/// the remaining allowance before subtraction, so hostile sizes cannot overflow
/// integer arithmetic.
private struct NormalizedOutputBudget {
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

/// A bounded-work scanner for JSON-LD script elements in untrusted HTML.
///
/// A regular expression that searches from every plausible opening tag to a
/// later closing tag can revisit the same suffix once per malformed opener.
/// That turns a bounded network response into quadratic CPU work. This scanner
/// instead advances monotonically: every byte is examined only while locating
/// its enclosing tag or script body, and a completed element is never searched
/// again. It is intentionally a small HTML recognizer rather than a general HTML
/// parser; the importer needs only script boundaries and one ASCII attribute.
private enum HTMLJSONLDBlockScanner {
    private static let script = Array("script".utf8)
    private static let type = Array("type".utf8)
    private static let jsonLDMediaType = Array("application/ld+json".utf8)
    private static let commentOpening = Array("<!--".utf8)
    private static let commentClosing = Array("-->".utf8)

    static func scan(
        _ html: String,
        maximumBlocks: Int
    ) -> (blocks: [Data], exceededLimit: Bool) {
        // The URL path already bounds the document to 2 MiB. One contiguous
        // UTF-8 copy gives this security boundary integer indices and predictable
        // constant-time access instead of repeatedly traversing String graphemes.
        let bytes = Array(html.utf8)
        var blocks: [Data] = []
        var cursor = 0

        while cursor < bytes.count {
            guard bytes[cursor] == ascii("<") else {
                cursor += 1
                continue
            }

            // Script-looking text inside an HTML comment is inert. Skipping the
            // entire comment also prevents it from manufacturing false candidates.
            if matches(commentOpening, in: bytes, at: cursor, caseInsensitive: false) {
                guard let end = firstOccurrence(
                    of: commentClosing,
                    in: bytes,
                    startingAt: cursor + commentOpening.count,
                    caseInsensitive: false
                ) else { break }
                cursor = end + commentClosing.count
                continue
            }

            let nameStart = cursor + 1
            guard matches(script, in: bytes, at: nameStart, caseInsensitive: true) else {
                cursor += 1
                continue
            }
            let afterName = nameStart + script.count
            guard afterName < bytes.count, isTagBoundary(bytes[afterName]) else {
                cursor += 1
                continue
            }
            guard let openingEnd = tagEnd(in: bytes, startingAt: afterName) else { break }

            let isJSONLD = containsJSONLDType(
                in: bytes,
                attributes: afterName..<openingEnd
            )
            let contentStart = openingEnd + 1
            guard let closing = closingScriptTag(in: bytes, startingAt: contentStart) else {
                // Under HTML parsing rules an unclosed script consumes the rest of
                // the document. Stopping here is both faithful and strictly linear.
                break
            }

            if isJSONLD {
                guard blocks.count < maximumBlocks else {
                    return (blocks, true)
                }
                blocks.append(Data(bytes[contentStart..<closing.start]))
            }
            cursor = closing.end + 1
        }

        return (blocks, false)
    }

    private static func closingScriptTag(
        in bytes: [UInt8],
        startingAt start: Int
    ) -> (start: Int, end: Int)? {
        var cursor = start
        while cursor < bytes.count {
            guard bytes[cursor] == ascii("<"),
                  cursor + 2 < bytes.count,
                  bytes[cursor + 1] == ascii("/"),
                  matches(script, in: bytes, at: cursor + 2, caseInsensitive: true)
            else {
                cursor += 1
                continue
            }
            let afterName = cursor + 2 + script.count
            guard afterName < bytes.count, isTagBoundary(bytes[afterName]),
                  let end = tagEnd(in: bytes, startingAt: afterName)
            else {
                cursor += 1
                continue
            }
            return (cursor, end)
        }
        return nil
    }

    /// Finds `>` without mistaking a greater-than sign inside a quoted
    /// attribute for the end of the tag. Unterminated quotes make the tag
    /// malformed, so the caller stops instead of searching the same bytes again.
    private static func tagEnd(in bytes: [UInt8], startingAt start: Int) -> Int? {
        var quote: UInt8?
        var cursor = start
        while cursor < bytes.count {
            let byte = bytes[cursor]
            if let activeQuote = quote {
                if byte == activeQuote { quote = nil }
            } else if byte == ascii("\"") || byte == ascii("'") {
                quote = byte
            } else if byte == ascii(">") {
                return cursor
            }
            cursor += 1
        }
        return nil
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private static func containsJSONLDType(
        in bytes: [UInt8],
        attributes: Range<Int>
    ) -> Bool {
        var cursor = attributes.lowerBound
        while cursor < attributes.upperBound {
            while cursor < attributes.upperBound,
                  isASCIIWhitespace(bytes[cursor]) || bytes[cursor] == ascii("/") {
                cursor += 1
            }
            let nameStart = cursor
            while cursor < attributes.upperBound,
                  !isASCIIWhitespace(bytes[cursor]),
                  bytes[cursor] != ascii("="),
                  bytes[cursor] != ascii("/") {
                cursor += 1
            }
            guard nameStart < cursor else {
                cursor += 1
                continue
            }
            let nameRange = nameStart..<cursor
            let isTypeAttribute = equals(
                type,
                bytes: bytes,
                range: nameRange,
                caseInsensitive: true
            )
            while cursor < attributes.upperBound, isASCIIWhitespace(bytes[cursor]) {
                cursor += 1
            }
            guard cursor < attributes.upperBound, bytes[cursor] == ascii("=") else {
                // HTML resolves duplicate attributes to the first occurrence.
                // Treating a later type as authoritative would make extraction
                // disagree with the document model a browser exposes.
                if isTypeAttribute { return false }
                continue
            }
            cursor += 1
            while cursor < attributes.upperBound, isASCIIWhitespace(bytes[cursor]) {
                cursor += 1
            }

            let valueRange: Range<Int>
            if cursor < attributes.upperBound,
               bytes[cursor] == ascii("\"") || bytes[cursor] == ascii("'") {
                let quote = bytes[cursor]
                cursor += 1
                let valueStart = cursor
                while cursor < attributes.upperBound, bytes[cursor] != quote {
                    cursor += 1
                }
                valueRange = valueStart..<cursor
                if cursor < attributes.upperBound { cursor += 1 }
            } else {
                let valueStart = cursor
                while cursor < attributes.upperBound,
                      !isASCIIWhitespace(bytes[cursor]) {
                    cursor += 1
                }
                valueRange = valueStart..<cursor
            }

            if isTypeAttribute {
                return equals(
                    jsonLDMediaType,
                    bytes: bytes,
                    range: valueRange,
                    caseInsensitive: true
                )
            }
        }
        return false
    }

    private static func firstOccurrence(
        of needle: [UInt8],
        in bytes: [UInt8],
        startingAt start: Int,
        caseInsensitive: Bool
    ) -> Int? {
        var cursor = start
        while cursor + needle.count <= bytes.count {
            if matches(needle, in: bytes, at: cursor, caseInsensitive: caseInsensitive) {
                return cursor
            }
            cursor += 1
        }
        return nil
    }

    private static func matches(
        _ needle: [UInt8],
        in bytes: [UInt8],
        at start: Int,
        caseInsensitive: Bool
    ) -> Bool {
        guard start >= 0, start + needle.count <= bytes.count else { return false }
        for offset in needle.indices {
            let candidate = bytes[start + offset]
            let expected = needle[offset]
            if caseInsensitive {
                guard lowercaseASCII(candidate) == lowercaseASCII(expected) else { return false }
            } else if candidate != expected {
                return false
            }
        }
        return true
    }

    private static func equals(
        _ expected: [UInt8],
        bytes: [UInt8],
        range: Range<Int>,
        caseInsensitive: Bool
    ) -> Bool {
        guard range.count == expected.count else { return false }
        return matches(expected, in: bytes, at: range.lowerBound, caseInsensitive: caseInsensitive)
    }

    private static func isTagBoundary(_ byte: UInt8) -> Bool {
        isASCIIWhitespace(byte) || byte == ascii(">") || byte == ascii("/")
    }

    private static func isASCIIWhitespace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D || byte == 0x0C
    }

    private static func lowercaseASCII(_ byte: UInt8) -> UInt8 {
        (0x41...0x5A).contains(byte) ? byte + 0x20 : byte
    }

    private static func ascii(_ character: Character) -> UInt8 {
        character.asciiValue!
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

private enum JSONTextNormalizationError: Error {
    case tooLarge
    case invalidEncoding
}

/// Converts a bounded JSON text into the one encoding understood by preflight.
///
/// `JSONSerialization` accepts UTF-8, UTF-16, and UTF-32, but a byte scanner
/// cannot safely infer quotes and brackets until it knows the encoding. In
/// particular, an ordinary UTF-16 code unit can contain `0x22`, the UTF-8 quote
/// byte, in either half. Normalizing first keeps structural accounting and
/// Foundation parsing in agreement. BOM-less input is intentionally required
/// to be UTF-8; guessing legacy encodings at this trust boundary would make the
/// accepted language ambiguous.
private enum JSONTextNormalizer {
    static func normalizedUTF8(
        from source: Data,
        maximumBytes: Int
    ) throws(JSONTextNormalizationError) -> Data {
        guard source.count <= maximumBytes else { throw .tooLarge }

        let encoding: String.Encoding
        let byteOrderMarkLength: Int
        let codeUnitWidth: Int
        if source.starts(with: [0x00, 0x00, 0xFE, 0xFF]) {
            encoding = .utf32BigEndian
            byteOrderMarkLength = 4
            codeUnitWidth = 4
        } else if source.starts(with: [0xFF, 0xFE, 0x00, 0x00]) {
            encoding = .utf32LittleEndian
            byteOrderMarkLength = 4
            codeUnitWidth = 4
        } else if source.starts(with: [0xEF, 0xBB, 0xBF]) {
            encoding = .utf8
            byteOrderMarkLength = 3
            codeUnitWidth = 1
        } else if source.starts(with: [0xFE, 0xFF]) {
            encoding = .utf16BigEndian
            byteOrderMarkLength = 2
            codeUnitWidth = 2
        } else if source.starts(with: [0xFF, 0xFE]) {
            encoding = .utf16LittleEndian
            byteOrderMarkLength = 2
            codeUnitWidth = 2
        } else {
            encoding = .utf8
            byteOrderMarkLength = 0
            codeUnitWidth = 1
        }

        // Literal NUL is never valid JSON text; a valid null character must be
        // escaped as `\u0000`. At a BOM-less boundary, NUL bytes are also the
        // reliable signature left by UTF-16/32 encodings of JSON's ASCII
        // punctuation. Rejecting them prevents Foundation from later guessing a
        // different encoding than the one used by this preflight.
        if byteOrderMarkLength == 0, source.contains(0x00) {
            throw .invalidEncoding
        }

        // Foundation may decode a valid prefix and silently ignore an
        // incomplete trailing UTF-16/32 code unit. Check alignment ourselves so
        // source bytes are never discarded before evidence is retained.
        let encodedByteCount = source.count - byteOrderMarkLength
        guard encodedByteCount.isMultiple(of: codeUnitWidth) else {
            throw .invalidEncoding
        }

        // After the explicit alignment check, `String(data:encoding:)` rejects
        // malformed sequences; unlike `String(decoding:as:)`, it does not
        // silently insert replacement characters that would change the
        // publisher's JSON text.
        let encodedText = source.dropFirst(byteOrderMarkLength)
        guard let text = String(data: Data(encodedText), encoding: encoding) else {
            throw .invalidEncoding
        }
        let normalized = Data(text.utf8)
        guard normalized.count <= maximumBytes else { throw .tooLarge }
        return normalized
    }
}

private enum JSONStructurePreflight {
    // swiftlint:disable cyclomatic_complexity
    /// Scans raw JSON before `JSONSerialization` builds Foundation containers.
    ///
    /// A transport byte limit alone does not prevent a compact document from
    /// containing extreme nesting or hundreds of thousands of tiny values. This
    /// scanner recognizes JSON string escaping and counts structural tokens
    /// without allocating a second object graph. Malformed syntax is still left
    /// to `JSONSerialization`; this pass exists only to enforce resource limits.
    static func isWithinLimits(_ data: Data, limits: RecipeImportLimits) -> Bool {
        var depth = 0
        var tokens = 0
        var isInsideString = false
        var isEscaped = false

        for byte in data {
            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if byte == 0x5C {
                    isEscaped = true
                } else if byte == 0x22 {
                    isInsideString = false
                }
                continue
            }

            switch byte {
            case 0x22:
                isInsideString = true
                tokens += 1
            case 0x7B, 0x5B:
                depth += 1
                tokens += 1
                if depth > limits.maximumJSONDepth { return false }
            case 0x7D, 0x5D:
                // A mismatched closer is JSONSerialization's syntax concern,
                // but it must not end this resource scan early. Continue from a
                // zero floor so a deeply nested suffix still meets the limit.
                if depth > 0 { depth -= 1 }
            case 0x2C, 0x3A:
                tokens += 1
            default:
                break
            }
            if tokens > limits.maximumJSONTokens { return false }
        }
        return true
    }
    // swiftlint:enable cyclomatic_complexity
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

// swiftlint:enable file_length
