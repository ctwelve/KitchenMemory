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
    public init() {}

    public func importHTML(_ html: String, documentURL: URL? = nil) -> RecipeImportResult {
        importJSONLDBlocks(Self.jsonLDBlocks(in: html), documentURL: documentURL)
    }

    public func importJSONLD(_ data: Data, documentURL: URL? = nil) -> RecipeImportResult {
        importJSONLDBlocks([data], documentURL: documentURL)
    }

    private func importJSONLDBlocks(_ blocks: [Data], documentURL: URL?) -> RecipeImportResult {
        var candidates: [RecipeImportCandidate] = []
        var diagnostics: [RecipeImportDiagnostic] = []

        for (blockIndex, data) in blocks.enumerated() {
            let value: Any
            do {
                value = try JSONSerialization.jsonObject(with: data)
            } catch {
                diagnostics.append(.init(blockIndex: blockIndex, kind: .malformedJSONLD))
                continue
            }

            let objects = Self.topLevelObjects(in: value)
            if objects.isEmpty {
                diagnostics.append(.init(blockIndex: blockIndex, kind: .unsupportedTopLevel))
                continue
            }

            for (objectIndex, object) in objects.enumerated() where Self.isRecipe(object) {
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
}

private extension SchemaOrgRecipeImporter {
    static func jsonLDBlocks(in html: String) -> [Data] {
        let pattern = #"(?is)<script\b(?=[^>]*\btype\s*=\s*(['\"]?)application/ld\+json\1)[^>]*>(.*?)</script\s*>"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return expression.matches(in: html, range: range).compactMap { match in
            guard let contentRange = Range(match.range(at: 2), in: html) else { return nil }
            return Data(html[contentRange].utf8)
        }
    }

    static func topLevelObjects(in value: Any) -> [[String: Any]] {
        if let array = value as? [Any] {
            return array.flatMap(topLevelObjects)
        }
        guard let object = value as? [String: Any] else { return [] }
        if let graph = object["@graph"] as? [Any] {
            return [object] + graph.flatMap(topLevelObjects)
        }
        return [object]
    }

    static func isRecipe(_ object: [String: Any]) -> Bool {
        strings(object["@type"]).contains { type in
            type.split(separator: "/").last?.caseInsensitiveCompare("Recipe") == .orderedSame
        }
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
        func component(_ index: Int) -> Int {
            guard let range = Range(match.range(at: index), in: string) else { return 0 }
            return Int(string[range]) ?? 0
        }
        let seconds = component(1) * 86_400 + component(2) * 3_600
            + component(3) * 60 + component(4)
        return seconds > 0 ? RecipeDuration(seconds: seconds) : nil
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
