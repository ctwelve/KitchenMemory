// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Preserves ingredient text and normalizes instruction hierarchy within finite item budgets.
enum SchemaOrgRecipeContentNormalizer {
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
            ), !text.isEmpty else { continue }
            guard ingredients.count < maximum else { throw NormalizedOutputLimitExceeded() }
            ingredients.append(IngredientLineParser.parse(text))
        }
        return ingredients.isEmpty ? [] : [IngredientSection(ingredients: ingredients)]
    }

    private static func ingredientText(
        _ value: Any,
        maximumFieldCharacters: Int,
        maximumUTF8Bytes: Int
    ) throws(NormalizedOutputLimitExceeded) -> String? {
        if SchemaOrgValue.scalarText(value) != nil { return SchemaOrgValue.cleanedNonemptyText(value) }
        guard let object = value as? [String: Any] else { return nil }
        guard let structuredValue = SchemaOrgValue.cleanedNonemptyText(object["value"]) else {
            return SchemaOrgValue.cleanedNonemptyText(object["name"])
        }
        guard let unit = SchemaOrgValue.cleanedNonemptyText(object["unitText"]) else { return structuredValue }

        var result = ""
        var charactersUsed = 0
        var utf8BytesUsed = 0
        try SchemaOrgValue.appendBounded(
            structuredValue,
            to: &result,
            separator: "",
            charactersUsed: &charactersUsed,
            utf8BytesUsed: &utf8BytesUsed,
            maximumCharacters: maximumFieldCharacters,
            maximumUTF8Bytes: maximumUTF8Bytes
        )
        try SchemaOrgValue.appendBounded(
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

    static func instructionSections(
        _ value: Any?,
        maximumItems: Int
    ) throws(NormalizedOutputLimitExceeded) -> [InstructionSection] {
        var remainingItems = maximumItems
        if let string = SchemaOrgValue.scalarText(value) {
            let steps = try splitInstructionText(string, remainingItems: &remainingItems)
            return steps.isEmpty ? [] : [InstructionSection(steps: steps)]
        }
        let values = value as? [Any] ?? value.map { [$0] } ?? []
        var looseSteps: [InstructionStep] = []
        var sections: [InstructionSection] = []

        for value in values {
            if let string = SchemaOrgValue.scalarText(value) {
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
                    sections.append(InstructionSection(
                        title: SchemaOrgValue.text(object["name"]).map(SchemaOrgValue.cleanText),
                        steps: steps
                    ))
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

    private static func instructionSteps(
        _ values: [Any],
        remainingItems: inout Int
    ) throws(NormalizedOutputLimitExceeded) -> [InstructionStep] {
        var steps: [InstructionStep] = []
        steps.reserveCapacity(min(values.count, remainingItems))
        for value in values {
            if let string = SchemaOrgValue.scalarText(value) {
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

    private static func instructionStep(
        _ object: [String: Any],
        remainingItems: inout Int
    ) throws(NormalizedOutputLimitExceeded) -> InstructionStep? {
        guard let body = SchemaOrgValue.text(object["text"]) ?? SchemaOrgValue.text(object["name"])
        else { return nil }
        return try instructionStep(
            text: body,
            name: SchemaOrgValue.text(object["name"]),
            remainingItems: &remainingItems
        )
    }

    private static func instructionStep(
        text: String,
        name: String?,
        remainingItems: inout Int
    ) throws(NormalizedOutputLimitExceeded) -> InstructionStep {
        guard remainingItems > 0 else { throw NormalizedOutputLimitExceeded() }
        remainingItems -= 1
        return InstructionStep(
            name: name.map(SchemaOrgValue.cleanText),
            text: SchemaOrgValue.cleanText(text)
        )
    }

    /// Emits newline-delimited steps incrementally so a short scalar cannot
    /// allocate thousands of model objects before the item ceiling is noticed.
    private static func splitInstructionText(
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

    private static func hasType(_ object: [String: Any], _ expected: String) -> Bool {
        SchemaOrgValue.strings(object["@type"]).contains { $0.caseInsensitiveCompare(expected) == .orderedSame }
    }

}
