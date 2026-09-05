// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Human-readable provenance for one recipe revision.
///
/// This describes attribution and a safe canonical link. Lossless imported
/// evidence is retained separately by ``RecipeSourceCapture``.
public struct RecipeSource: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
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

/// An authored yield that preserves its original wording alongside optional structure.
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
    /// Optional locally available bytes; authority retains the content-addressed reference.
    public var imageData: Data?
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

/// An ordered group of ingredients within one immutable recipe revision.
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

/// One authored ingredient row with lossless wording and optional parsed structure.
///
/// `originalText` remains useful when parsing is incomplete. Presentation code
/// consults ``presentationMode`` rather than assuming structured fields are more
/// authoritative than the wording a person reviewed.
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

    /// Whether this row contains authored or structured content worth saving.
    public var hasMeaningfulDisplayContent: Bool {
        switch presentationMode {
        case .original:
            return nonempty(originalText) != nil || hasStructuredDisplayContent
        case .custom:
            return nonempty(customDisplayText) != nil || hasStructuredDisplayContent
                || nonempty(originalText) != nil
        case .structured:
            return hasStructuredDisplayContent || nonempty(originalText) != nil
        }
    }

    /// Whether locale-aware presentation can compose this row from structure.
    public var hasStructuredDisplayContent: Bool {
        nonempty(ingredientText) != nil
    }

    private func nonempty(_ text: String?) -> String? {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// An ordered group of preparation steps within one immutable recipe revision.
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

/// One authored preparation step with optional structured timing and temperature.
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
