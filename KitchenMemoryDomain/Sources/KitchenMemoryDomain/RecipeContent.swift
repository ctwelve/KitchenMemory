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

    public let id: ID
    public var originalText: String
    public var displayText: String
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
        originalText: String,
        displayText: String,
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
        self.displayText = displayText
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
