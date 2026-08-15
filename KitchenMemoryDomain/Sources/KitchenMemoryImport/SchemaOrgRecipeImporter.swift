// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain

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
        let discovery = Self.jsonLDBlocks(in: html, maximum: limits.maximumJSONLDBlocks)
        guard !discovery.exceededLimit else {
            return Self.limitExceededResult(.jsonLDBlocks)
        }
        return importJSONLDBlocks(discovery.blocks, documentURL: documentURL)
    }

    public func importJSONLD(_ data: Data, documentURL: URL? = nil) -> RecipeImportResult {
        importJSONLDBlocks([data], documentURL: documentURL)
    }

    private func importJSONLDBlocks(_ blocks: [Data], documentURL: URL?) -> RecipeImportResult {
        var candidates: [RecipeImportCandidate] = []
        var diagnostics: [RecipeImportDiagnostic] = []

        for (blockIndex, data) in blocks.enumerated() {
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
                guard let snapshotData = try? JSONSerialization.data(
                    withJSONObject: object,
                    options: [.sortedKeys]
                ) else { continue }

                let snapshot = RecipeImportSourceSnapshot(
                    documentURL: documentURL,
                    jsonLD: data,
                    candidateJSONLD: snapshotData
                )
                let draft = Self.makeDraft(from: object, title: title, documentURL: documentURL)
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
        let pattern = #"(?is)<script\b(?=[^>]*\btype\s*=\s*(['\"]?)application/ld\+json\1)[^>]*>(.*?)</script\s*>"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return ([], false) }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        var blocks: [Data] = []
        var exceededLimit = false
        expression.enumerateMatches(in: html, range: range) { match, _, stop in
            guard let match, let contentRange = Range(match.range(at: 2), in: html) else { return }
            guard blocks.count < maximum else {
                exceededLimit = true
                stop.pointee = true
                return
            }
            blocks.append(Data(html[contentRange].utf8))
        }
        return (blocks, exceededLimit)
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
            maximumNodes: limits.maximumIngredients * 16,
            maximumCollectionElements: limits.maximumIngredients,
            maximumCharacters: limits.maximumFieldCharacters
        ) else { return false }
        return ConsumedFieldPreflight.isWithinLimits(
            object["recipeInstructions"],
            maximumNodes: limits.maximumInstructionItems * 16,
            maximumCollectionElements: limits.maximumInstructionItems * 2,
            maximumCharacters: limits.maximumFieldCharacters
        )
    }

    static func makeDraft(
        from object: [String: Any],
        title: String,
        documentURL: URL?
    ) -> RecipeImportDraft {
        let canonicalURL = resolvedURL(
            from: object["url"] ?? mainEntityURL(object["mainEntityOfPage"]),
            relativeTo: documentURL
        ) ?? documentURL
        let author = authorName(object["author"])

        return RecipeImportDraft(
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
            cuisines: strings(object["recipeCuisine"]).map(cleanText),
            categories: strings(object["recipeCategory"]).map(cleanText),
            keywords: keywords(object["keywords"]),
            imageURLs: imageURLs(object["image"], relativeTo: documentURL),
            ingredientSections: ingredientSections(object["recipeIngredient"]),
            instructionSections: instructionSections(object["recipeInstructions"])
        )
    }

    static func mainEntityURL(_ value: Any?) -> Any? {
        guard let object = value as? [String: Any] else { return value }
        return object["@id"] ?? object["url"]
    }

    static func authorName(_ value: Any?) -> String? {
        if let direct = text(value) { return cleanText(direct) }
        if let values = value as? [Any] {
            let names = values.compactMap(authorName)
            return names.isEmpty ? nil : names.joined(separator: ", ")
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

    static func keywords(_ value: Any?) -> [String] {
        if let string = text(value) {
            return string.split(separator: ",").map { cleanText(String($0)) }.filter { !$0.isEmpty }
        }
        return strings(value).map(cleanText)
    }

    static func imageURLs(_ value: Any?, relativeTo baseURL: URL?) -> [URL] {
        if let array = value as? [Any] {
            return array.compactMap { resolvedImageURL($0, relativeTo: baseURL) }
        }
        return resolvedImageURL(value, relativeTo: baseURL).map { [$0] } ?? []
    }

    static func resolvedImageURL(_ value: Any?, relativeTo baseURL: URL?) -> URL? {
        if let object = value as? [String: Any] {
            return resolvedURL(from: object["url"] ?? object["contentUrl"], relativeTo: baseURL)
        }
        return resolvedURL(from: value, relativeTo: baseURL)
    }

    static func resolvedURL(from value: Any?, relativeTo baseURL: URL?) -> URL? {
        guard let string = text(value) else { return nil }
        return URL(string: string, relativeTo: baseURL)?.absoluteURL
    }

    static func ingredientSections(_ value: Any?) -> [IngredientSection] {
        let values = value as? [Any] ?? value.map { [$0] } ?? []
        let ingredients = values.compactMap { ingredientText($0) }.map(IngredientLineParser.parse)
        return ingredients.isEmpty ? [] : [IngredientSection(ingredients: ingredients)]
    }

    static func ingredientText(_ value: Any) -> String? {
        if let string = text(value) { return string }
        guard let object = value as? [String: Any] else { return nil }
        if let value = text(object["value"]), let unit = text(object["unitText"]) {
            return "\(value) \(unit)"
        }
        return text(object["value"]) ?? text(object["name"])
    }

    static func instructionSections(_ value: Any?) -> [InstructionSection] {
        if let string = text(value) {
            let steps = splitInstructionText(string).map { InstructionStep(text: cleanText($0)) }
            return steps.isEmpty ? [] : [InstructionSection(steps: steps)]
        }
        let values = value as? [Any] ?? value.map { [$0] } ?? []
        var looseSteps: [InstructionStep] = []
        var sections: [InstructionSection] = []

        for value in values {
            if let string = text(value) {
                looseSteps.append(InstructionStep(text: cleanText(string)))
                continue
            }
            guard let object = value as? [String: Any] else { continue }
            if hasType(object, "HowToSection") {
                let childValues = object["itemListElement"] as? [Any] ?? []
                let steps = instructionSteps(childValues)
                if !steps.isEmpty {
                    sections.append(InstructionSection(title: text(object["name"]).map(cleanText), steps: steps))
                }
            } else if let step = instructionStep(object) {
                looseSteps.append(step)
            }
        }
        if !looseSteps.isEmpty { sections.insert(InstructionSection(steps: looseSteps), at: 0) }
        return sections
    }

    static func instructionSteps(_ values: [Any]) -> [InstructionStep] {
        values.flatMap { value -> [InstructionStep] in
            if let string = text(value) { return [InstructionStep(text: cleanText(string))] }
            guard let object = value as? [String: Any] else { return [] }
            if hasType(object, "HowToSection") {
                return instructionSteps(object["itemListElement"] as? [Any] ?? [])
            }
            return instructionStep(object).map { [$0] } ?? []
        }
    }

    static func instructionStep(_ object: [String: Any]) -> InstructionStep? {
        guard let body = text(object["text"]) ?? text(object["name"]) else { return nil }
        return InstructionStep(
            name: text(object["name"]).map(cleanText),
            text: cleanText(body)
        )
    }

    static func splitInstructionText(_ value: String) -> [String] {
        value.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
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

    static func cleanText(_ value: String) -> String {
        let decoded = value
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        let withoutExecutableContent = decoded.replacingOccurrences(
            of: #"(?is)<(script|style)\b[^>]*>.*?</\1\s*>"#,
            with: " ",
            options: .regularExpression
        )
        let withoutTags = withoutExecutableContent.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: " ",
            options: .regularExpression
        )
        return withoutTags.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
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

private enum JSONStructurePreflight {
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
                depth -= 1
                if depth < 0 { return true }
            case 0x2C, 0x3A:
                tokens += 1
            default:
                break
            }
            if tokens > limits.maximumJSONTokens { return false }
        }
        return true
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
