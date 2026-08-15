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
        let canonicalURL = resolvedWebURL(
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
              URLSessionRecipeDocumentLoader.isStructurallyAllowed(url)
        else { return nil }
        return url
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

    private static func containsJSONLDType(
        in bytes: [UInt8],
        attributes: Range<Int>
    ) -> Bool {
        var cursor = attributes.lowerBound
        while cursor < attributes.upperBound {
            while cursor < attributes.upperBound,
                  isASCIIWhitespace(bytes[cursor]) || bytes[cursor] == ascii("/")
            {
                cursor += 1
            }
            let nameStart = cursor
            while cursor < attributes.upperBound,
                  !isASCIIWhitespace(bytes[cursor]),
                  bytes[cursor] != ascii("="),
                  bytes[cursor] != ascii("/")
            {
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
               bytes[cursor] == ascii("\"") || bytes[cursor] == ascii("'")
            {
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
                      !isASCIIWhitespace(bytes[cursor])
                {
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
