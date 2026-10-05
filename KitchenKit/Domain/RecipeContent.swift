// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

// These related public values and their caller contracts form one domain boundary.
// Keep their documentation beside the declarations rather than splitting the contract.
// swiftlint:disable file_length

/// Human-readable provenance for one recipe revision.
///
/// This describes editable attribution and optional provenance links. URLs must
/// be validated before activation, including after editing or legacy decoding.
/// Lossless imported evidence is retained separately by ``RecipeSourceCapture``.
public struct RecipeSource: Codable, Equatable, Sendable {
    /// The attribution category; it does not determine storage or link-activation policy.
    public enum Kind: String, Codable, CaseIterable, Sendable {
        /// Content authored directly, with no imported-source claim.
        case original
        /// Content attributed to a web document; its editable URL still requires activation checks.
        case webpage
        /// Content attributed to a book, independent of web-link availability.
        case book
        /// Content attributed to a person whose name is descriptive rather than account identity.
        case person
        /// Content acquired through another import source without claiming a more specific category.
        case imported
    }

    /// The authored attribution category.
    public var kind: Kind
    /// Human-readable source title, independent of the Recipe title and destination host.
    public var title: String?
    /// Human-readable source attribution, independent of Kitchen ownership.
    public var authorName: String?
    /// Human-readable publisher attribution, when available.
    public var publisherName: String?
    /// An editable provenance URL.
    ///
    /// Construction does not validate it; activation must apply the source-link policy
    /// again, including for legacy or edited values.
    public var canonicalURL: URL?

    /// Retains attribution as supplied, without fetching or validating the source.
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

/// A duration in whole seconds, independent of localized display wording.
///
/// Construction preserves the supplied integer; callers own validity checks.
public struct RecipeDuration: Codable, Equatable, Sendable {
    /// Whole seconds retained without inferring prep-plus-cook totals.
    public var seconds: Int

    /// Retains the supplied duration; construction does not reject zero or negative values.
    public init(seconds: Int) {
        self.seconds = seconds
    }
}

/// An exact integer ratio that preserves authored precision without floating-point rounding.
///
/// Construction does not reduce the ratio or reject invalid signs and denominators.
/// Use `normalized` before arithmetic.
public struct RationalQuantity: Codable, Equatable, Sendable {
    /// The integer count represented over `denominator`; construction preserves its sign.
    public var numerator: Int
    /// The divisor, which must be positive for normalized arithmetic.
    public var denominator: Int

    /// Retains the exact supplied ratio without normalization or validity checks.
    public init(numerator: Int, denominator: Int = 1) {
        self.numerator = numerator
        self.denominator = denominator
    }
}

/// An authored amount whose interpretation may be exact, ranged, approximate, absent, or textual.
///
/// The kind and optional fields are preserved without enforcing consistency. Arithmetic
/// uses only the numeric fields appropriate to the kind and never guesses from text.
public struct QuantityExpression: Codable, Equatable, Sendable {
    /// How numeric bounds and retained wording should be interpreted.
    public enum Kind: String, Codable, Sendable {
        /// No numeric amount is asserted; scaling preserves the expression unchanged.
        case none
        /// One exact amount carried in `lowerBound`; arithmetic requires that bound to be valid.
        case exact
        /// An authored lower/upper interval; scaling requires both bounds and preserves the range.
        case range
        /// A qualified approximate amount carried in `lowerBound`, preserving the qualification when scaled.
        case approximate
        /// Free-form amount wording that scaling never guesses into a numeric value.
        case text
    }

    /// The interpretation governing which optional numeric fields are meaningful.
    public var kind: Kind
    /// The exact or approximate amount, or the lower endpoint of a range.
    public var lowerBound: RationalQuantity?
    /// The upper endpoint when the interpretation is a range.
    public var upperBound: RationalQuantity?
    /// Retained authored wording, including textual amounts that cannot honestly be scaled.
    public var text: String?

    /// Retains kind, bounds, and wording without enforcing their consistency.
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
    /// Optional structured output amount; textual yields can remain unparsed.
    public var quantity: QuantityExpression?
    /// Authored output unit such as servings or loaves, without canonical unit conversion.
    public var unitText: String?
    /// The retained authored yield wording, including unknown or ranged output.
    public var originalText: String

    /// Keeps source wording alongside optional structure; it does not choose a scaling basis.
    public init(quantity: QuantityExpression? = nil, unitText: String? = nil, originalText: String) {
        self.quantity = quantity
        self.unitText = unitText
        self.originalText = originalText
    }
}

/// The size of each package, kept separate from the number of packages required.
///
/// For “2 (400 g) cans”, the row quantity is two and this value describes 400 g.
public struct PackageDescription: Codable, Equatable, Sendable {
    /// The amount in each package, independent of the row’s package count.
    public var quantity: QuantityExpression
    /// The authored package-size unit, without conversion to a canonical unit.
    public var unitText: String

    /// Retains the package-size interpretation separately from the ingredient row quantity.
    public init(quantity: QuantityExpression, unitText: String) {
        self.quantity = quantity
        self.unitText = unitText
    }
}

/// An authored image reference with a stable identity and optional local bytes.
///
/// Bundled images use resource names; private images use a content-addressed reference.
/// Byte availability is excluded from canonical Recipe authority.
public struct RecipeMedia: Codable, Equatable, Identifiable, Sendable {
    /// A domain-typed stable UUID identity, independent of persistence record identity.
    public typealias ID = StableIdentifier<RecipeMedia>

    /// The authored presentation purpose of an image reference.
    public enum Role: String, Codable, Sendable {
        /// The image explicitly chosen for prominent Recipe presentation.
        case hero
        /// An image intended for compact Recipe presentation.
        case thumbnail
        /// One image in the authored gallery sequence.
        case gallery
    }

    /// The authored content identity retained with this value, independently of position or wording.
    public let id: ID
    /// The authored presentation purpose, independent of byte availability.
    public var role: Role
    /// A bundled resource name or `private-image:sha256:` content-addressed reference.
    public var assetName: String
    /// Optional locally available bytes; authority retains the content-addressed reference.
    public var imageData: Data?
    /// An authored description available even when image bytes cannot be resolved.
    public var accessibilityLabel: String?

    /// Creates a media reference without loading or checking its image bytes.
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
    /// A domain-typed stable UUID identity, independent of persistence record identity.
    public typealias ID = StableIdentifier<IngredientSection>

    /// The authored content identity retained with this value, independently of position or wording.
    public let id: ID
    /// The optional authored group heading; nil represents an untitled group.
    public var title: String?
    /// Ingredient rows in authored order; identities and wording remain attached to each row.
    public var ingredients: [RecipeIngredient]

    /// Creates a group retaining its identity, optional heading, and authored row order.
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
    /// A domain-typed stable UUID identity, independent of persistence record identity.
    public typealias ID = StableIdentifier<RecipeIngredient>

    /// The authored rule controlling transient quantity scaling.
    public enum ScalingBehavior: String, Codable, Sendable {
        /// Permits exact arithmetic when the row’s quantity and presentation can support it.
        case linear
        /// Preserves this row’s amount regardless of the selected yield multiplier.
        case fixed
        /// Preserves this row for a person to reconsider rather than scaling it automatically.
        case manualReview
    }

    /// Whether structure is absent, machine-proposed, person-reviewed, or explicitly edited.
    public enum ParseState: String, Codable, Sendable {
        /// The retained source has no accepted machine interpretation.
        case unparsed
        /// Structure is a provisional machine interpretation that text reconciliation may replace.
        case parsed
        /// A person reviewed the row; text reconciliation protects its retained structured precision.
        case reviewed
        /// A person explicitly edited the row; text reconciliation protects those structured choices.
        case edited
    }

    /// The person’s choice of structured, original, or custom ingredient presentation.
    public enum PresentationMode: String, Codable, CaseIterable, Sendable {
        /// Prefers composition from structured fields, falling back to original wording when incomplete.
        case structured
        /// Prefers the retained authored line, while keeping optional structure available.
        case original
        /// Prefers an explicit display override; transient scaling preserves the row unchanged.
        case custom
    }

    /// The authored content identity retained with this value, independently of position or wording.
    public let id: ID
    /// The retained authored line, independent of its provisional structured interpretation.
    public var originalText: String
    /// The presentation choice; it does not remove the original or structured fields.
    public var presentationMode: PresentationMode
    /// An optional explicit display override used by custom presentation.
    public var customDisplayText: String?
    /// Optional interpreted row amount; package size is retained separately.
    public var quantity: QuantityExpression?
    /// Optional authored amount unit or container wording, without canonical conversion.
    public var unitText: String?
    /// Optional size of each package, separate from the row’s amount or package count.
    public var package: PackageDescription?
    /// The interpreted ingredient name; nonempty wording enables structured presentation.
    public var ingredientText: String?
    /// Authored preparation guidance associated with the row.
    public var preparation: String?
    /// Additional authored guidance retained independently of parse interpretation.
    public var note: String?
    /// Whether the authored row is optional, without making a pantry decision.
    public var isOptional: Bool
    /// The authored policy for transient scaling of this row.
    public var scalingBehavior: ScalingBehavior
    /// The provenance of this row’s structured interpretation.
    public var parseState: ParseState

    /// Retains wording, presentation, and structure without requiring parsing to succeed.
    ///
    /// Empty or incomplete rows can be represented while an editing draft is in progress.
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

    /// Decodes retained ingredient content with compatibility defaults for older documents.
    ///
    /// Absent source text, optionality, scaling behavior, and parse state use their
    /// original defaults. A missing presentation mode becomes structured and discards
    /// any legacy custom override; malformed required identity or fields throw.
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

    /// Encodes authored wording, structured precision, and presentation choices together.
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
    /// A domain-typed stable UUID identity, independent of persistence record identity.
    public typealias ID = StableIdentifier<InstructionSection>

    /// The authored content identity retained with this value, independently of position or wording.
    public let id: ID
    /// The optional authored group heading; nil represents an untitled group.
    public var title: String?
    /// Instruction values in authored order, independent of cooking progress.
    public var steps: [InstructionStep]

    /// Creates a group preserving the supplied heading and step sequence.
    public init(id: ID = ID(), title: String? = nil, steps: [InstructionStep]) {
        self.id = id
        self.title = title
        self.steps = steps
    }
}

/// One authored preparation step with optional structured timing and temperature.
public struct InstructionStep: Codable, Equatable, Identifiable, Sendable {
    /// A domain-typed stable UUID identity, independent of persistence record identity.
    public typealias ID = StableIdentifier<InstructionStep>

    /// The authored content identity retained with this value, independently of position or wording.
    public let id: ID
    /// An optional short authored step heading, independent of its body.
    public var name: String?
    /// The authored instruction body; construction preserves it without validation.
    public var text: String
    /// Optional structured timing for this step, without creating a running timer.
    public var duration: RecipeDuration?
    /// Optional structured temperature, with its authored scale.
    public var temperature: RecipeTemperature?

    /// Creates an instruction value without inferring timing, temperature, or completion.
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

/// An exact temperature and its authored scale; construction performs no conversion.
public struct RecipeTemperature: Codable, Equatable, Sendable {
    /// The scale in which the authored temperature is expressed.
    public enum Unit: String, Codable, Sendable {
        /// The authored value is on the Celsius scale; construction does not convert it.
        case celsius
        /// The authored value is on the Fahrenheit scale; construction does not convert it.
        case fahrenheit
    }

    /// The exact authored temperature ratio, without rounding.
    public var value: RationalQuantity
    /// The authored temperature scale.
    public var unit: Unit

    /// Retains the exact value and scale without normalizing or converting them.
    public init(value: RationalQuantity, unit: Unit) {
        self.value = value
        self.unit = unit
    }
}

/// One ordered tool requirement retaining source wording and optional quantity.
public struct EquipmentItem: Codable, Equatable, Identifiable, Sendable {
    /// A domain-typed stable UUID identity, independent of persistence record identity.
    public typealias ID = StableIdentifier<EquipmentItem>

    /// The authored content identity retained with this value, independently of position or wording.
    public let id: ID
    /// The authored tool wording retained alongside any interpretation.
    public var originalText: String
    /// Optional interpreted number of tools, without inferring a count from the name.
    public var quantity: QuantityExpression?
    /// The tool’s authored or interpreted display name.
    public var name: String
    /// Whether the authored tool requirement is optional.
    public var isOptional: Bool

    /// Creates a tool row retaining source wording and supplied optional structure.
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

// swiftlint:enable file_length
