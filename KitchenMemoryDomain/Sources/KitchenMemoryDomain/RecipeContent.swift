// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation

public struct RecipeSource: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case original, webpage, book, person, imported
    }

    public var kind: Kind
    public var title: String?
    public var authorName: String?
    public var publisherName: String?
    public var canonicalURL: URL?

    public init(
        kind: Kind,
        title: String? = nil,
        authorName: String? = nil,
        publisherName: String? = nil,
        canonicalURL: URL? = nil
    ) {
        self.kind = kind
        self.title = title
        self.authorName = authorName
        self.publisherName = publisherName
        self.canonicalURL = canonicalURL
    }
}

public struct RecipeDuration: Codable, Equatable, Sendable {
    public var seconds: Int

    public init(seconds: Int) {
        self.seconds = seconds
    }
}

public struct RationalQuantity: Codable, Equatable, Sendable {
    public var numerator: Int
    public var denominator: Int

    public init(numerator: Int, denominator: Int = 1) {
        self.numerator = numerator
        self.denominator = denominator
    }
}

public extension RationalQuantity {
    var renderedText: String {
        denominator == 1 ? String(numerator) : "\(numerator)/\(denominator)"
    }
}

public struct QuantityExpression: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case none, exact, range, approximate, text
    }

    public var kind: Kind
    public var lowerBound: RationalQuantity?
    public var upperBound: RationalQuantity?
    public var text: String?

    public init(
        kind: Kind,
        lowerBound: RationalQuantity? = nil,
        upperBound: RationalQuantity? = nil,
        text: String? = nil
    ) {
        self.kind = kind
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.text = text
    }
}

public struct RecipeYield: Codable, Equatable, Sendable {
    public var quantity: QuantityExpression?
    public var unitText: String?
    public var originalText: String

    public init(quantity: QuantityExpression? = nil, unitText: String? = nil, originalText: String) {
        self.quantity = quantity
        self.unitText = unitText
        self.originalText = originalText
    }
}

public struct PackageDescription: Codable, Equatable, Sendable {
    public var quantity: QuantityExpression
    public var unitText: String

    public init(quantity: QuantityExpression, unitText: String) {
        self.quantity = quantity
        self.unitText = unitText
    }
}

public struct RecipeMedia: Codable, Equatable, Identifiable, Sendable {
    public typealias ID = StableIdentifier<RecipeMedia>

    public enum Role: String, Codable, Sendable {
        case hero
        case thumbnail
        case gallery
    }

    public let id: ID
    public var role: Role
    public var assetName: String
    public var accessibilityLabel: String?

    public init(
        id: ID = ID(),
        role: Role,
        assetName: String,
        accessibilityLabel: String? = nil
    ) {
        self.id = id
        self.role = role
        self.assetName = assetName
        self.accessibilityLabel = accessibilityLabel
    }
}

public struct IngredientSection: Codable, Equatable, Identifiable, Sendable {
    public typealias ID = StableIdentifier<IngredientSection>

    public let id: ID
    public var title: String?
    public var ingredients: [RecipeIngredient]

    public init(id: ID = ID(), title: String? = nil, ingredients: [RecipeIngredient]) {
        self.id = id
        self.title = title
        self.ingredients = ingredients
    }
}

public struct RecipeIngredient: Codable, Equatable, Identifiable, Sendable {
    public typealias ID = StableIdentifier<RecipeIngredient>

    public enum ScalingBehavior: String, Codable, Sendable {
        case linear, fixed, manualReview
    }

    public enum ParseState: String, Codable, Sendable {
        case unparsed, parsed, reviewed, edited
    }

    public enum PresentationMode: String, Codable, CaseIterable, Sendable {
        case structured, original, custom
    }

    public let id: ID
    public var originalText: String
    public var presentationMode: PresentationMode
    public var customDisplayText: String?
    public var quantity: QuantityExpression?
    public var unitText: String?
    public var package: PackageDescription?
    public var ingredientText: String?
    public var preparation: String?
    public var note: String?
    public var isOptional: Bool
    public var scalingBehavior: ScalingBehavior
    public var parseState: ParseState

    public init(
        id: ID = ID(),
        originalText: String = "",
        presentationMode: PresentationMode = .structured,
        customDisplayText: String? = nil,
        quantity: QuantityExpression? = nil,
        unitText: String? = nil,
        package: PackageDescription? = nil,
        ingredientText: String? = nil,
        preparation: String? = nil,
        note: String? = nil,
        isOptional: Bool = false,
        scalingBehavior: ScalingBehavior = .linear,
        parseState: ParseState = .unparsed
    ) {
        self.id = id
        self.originalText = originalText
        self.presentationMode = presentationMode
        self.customDisplayText = customDisplayText
        self.quantity = quantity
        self.unitText = unitText
        self.package = package
        self.ingredientText = ingredientText
        self.preparation = preparation
        self.note = note
        self.isOptional = isOptional
        self.scalingBehavior = scalingBehavior
        self.parseState = parseState
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case originalText
        case presentationMode
        case customDisplayText
        case quantity
        case unitText
        case package
        case ingredientText
        case preparation
        case note
        case isOptional
        case scalingBehavior
        case parseState
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(ID.self, forKey: .id)
        originalText = try container.decodeIfPresent(String.self, forKey: .originalText) ?? ""
        quantity = try container.decodeIfPresent(QuantityExpression.self, forKey: .quantity)
        unitText = try container.decodeIfPresent(String.self, forKey: .unitText)
        package = try container.decodeIfPresent(PackageDescription.self, forKey: .package)
        ingredientText = try container.decodeIfPresent(String.self, forKey: .ingredientText)
        preparation = try container.decodeIfPresent(String.self, forKey: .preparation)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        isOptional = try container.decodeIfPresent(Bool.self, forKey: .isOptional) ?? false
        scalingBehavior = try container.decodeIfPresent(ScalingBehavior.self, forKey: .scalingBehavior) ?? .linear
        parseState = try container.decodeIfPresent(ParseState.self, forKey: .parseState) ?? .unparsed

        if let mode = try container.decodeIfPresent(PresentationMode.self, forKey: .presentationMode) {
            presentationMode = mode
            customDisplayText = try container.decodeIfPresent(String.self, forKey: .customDisplayText)
        } else {
            presentationMode = .structured
            customDisplayText = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(originalText, forKey: .originalText)
        try container.encode(presentationMode, forKey: .presentationMode)
        try container.encodeIfPresent(customDisplayText, forKey: .customDisplayText)
        try container.encodeIfPresent(quantity, forKey: .quantity)
        try container.encodeIfPresent(unitText, forKey: .unitText)
        try container.encodeIfPresent(package, forKey: .package)
        try container.encodeIfPresent(ingredientText, forKey: .ingredientText)
        try container.encodeIfPresent(preparation, forKey: .preparation)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(isOptional, forKey: .isOptional)
        try container.encode(scalingBehavior, forKey: .scalingBehavior)
        try container.encode(parseState, forKey: .parseState)
    }

    /// The text readers and cooking surfaces should present.
    ///
    /// Structured presentation is the default, but incomplete structure falls
    /// back to preserved source evidence. A custom override is explicit rather
    /// than a second stored value that can silently drift from its components.
    public var effectiveDisplayText: String {
        switch presentationMode {
        case .original:
            return nonempty(originalText) ?? structuredDisplayText ?? "Ingredient"
        case .custom:
            return nonempty(customDisplayText) ?? structuredDisplayText
                ?? nonempty(originalText) ?? "Ingredient"
        case .structured:
            return structuredDisplayText ?? nonempty(originalText) ?? "Ingredient"
        }
    }

    public var structuredDisplayText: String? {
        guard let ingredientName = nonempty(ingredientText) else { return nil }
        var components: [String] = []
        if let quantityText = quantity?.renderedText { components.append(quantityText) }
        if let package {
            let packageUnit = package.unitText.hasSuffix("s")
                ? String(package.unitText.dropLast())
                : package.unitText
            components.append("(\(package.quantity.renderedText)-\(packageUnit))")
        }
        if let unit = nonempty(unitText) { components.append(unit) }
        components.append(ingredientName)

        var result = components.joined(separator: " ")
        if let preparation = nonempty(preparation) { result += ", \(preparation)" }
        if let note = nonempty(note) { result += ", \(note)" }
        if isOptional { result += ", optional" }
        return result
    }

    private func nonempty(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension QuantityExpression {
    var renderedText: String? {
        switch kind {
        case .none:
            return nil
        case .exact:
            return lowerBound?.renderedText
        case .range:
            guard let lowerBound, let upperBound else { return text }
            return "\(lowerBound.renderedText)–\(upperBound.renderedText)"
        case .approximate:
            return lowerBound.map { "about \($0.renderedText)" } ?? text
        case .text:
            return text
        }
    }
}

public struct InstructionSection: Codable, Equatable, Identifiable, Sendable {
    public typealias ID = StableIdentifier<InstructionSection>

    public let id: ID
    public var title: String?
    public var steps: [InstructionStep]

    public init(id: ID = ID(), title: String? = nil, steps: [InstructionStep]) {
        self.id = id
        self.title = title
        self.steps = steps
    }
}

public struct InstructionStep: Codable, Equatable, Identifiable, Sendable {
    public typealias ID = StableIdentifier<InstructionStep>

    public let id: ID
    public var name: String?
    public var text: String
    public var duration: RecipeDuration?
    public var temperature: RecipeTemperature?

    public init(
        id: ID = ID(),
        name: String? = nil,
        text: String,
        duration: RecipeDuration? = nil,
        temperature: RecipeTemperature? = nil
    ) {
        self.id = id
        self.name = name
        self.text = text
        self.duration = duration
        self.temperature = temperature
    }
}

public struct RecipeTemperature: Codable, Equatable, Sendable {
    public enum Unit: String, Codable, Sendable {
        case celsius, fahrenheit
    }

    public var value: RationalQuantity
    public var unit: Unit

    public init(value: RationalQuantity, unit: Unit) {
        self.value = value
        self.unit = unit
    }
}

public struct EquipmentItem: Codable, Equatable, Identifiable, Sendable {
    public typealias ID = StableIdentifier<EquipmentItem>

    public let id: ID
    public var originalText: String
    public var quantity: QuantityExpression?
    public var name: String
    public var isOptional: Bool

    public init(
        id: ID = ID(),
        originalText: String,
        quantity: QuantityExpression? = nil,
        name: String,
        isOptional: Bool = false
    ) {
        self.id = id
        self.originalText = originalText
        self.quantity = quantity
        self.name = name
        self.isOptional = isOptional
    }
}
