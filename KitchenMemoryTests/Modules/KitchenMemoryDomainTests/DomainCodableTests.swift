// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain
import XCTest

final class DomainCodableTests: XCTestCase {
    func testRichRevisionRoundTripsWithoutLosingDomainContent() throws {
        let revision = makeRichCodableRevision()

        let encoded = try JSONEncoder().encode(revision)
        let decoded = try JSONDecoder().decode(RecipeRevision.self, from: encoded)

        XCTAssertEqual(decoded, revision)
    }

    func testLegacyIngredientPayloadReceivesDocumentedDefaults() throws {
        let data = Data(
            #"{"id":"ABEF8C4F-F51A-42A8-AC68-CB1B62B3ED04","customDisplayText":"discard me"}"#.utf8
        )

        let ingredient = try JSONDecoder().decode(RecipeIngredient.self, from: data)

        XCTAssertEqual(ingredient.originalText, "")
        XCTAssertEqual(ingredient.presentationMode, .structured)
        XCTAssertNil(ingredient.customDisplayText)
        XCTAssertFalse(ingredient.isOptional)
        XCTAssertEqual(ingredient.scalingBehavior, .linear)
        XCTAssertEqual(ingredient.parseState, .unparsed)
    }

    func testSeededIngredientsRoundTripAcrossIndependentDimensions() throws {
        let seed = try PropertyTestSeeds.bundled().seed(named: .domainCodableIngredients)
        var generator = SeededGenerator(seed: seed.value)
        let parseStates: [RecipeIngredient.ParseState] = [.unparsed, .parsed, .reviewed, .edited]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let dimensions = ingredientDimensions()

        // The bounded Cartesian product makes these four durable dimensions
        // independent. Seeded values vary the remaining optional payloads.
        for (caseIndex, dimension) in dimensions.enumerated() {
            let context = dimension.context(seed: seed.hexadecimal, caseIndex: caseIndex)
            let ingredient = RecipeIngredient(
                id: RecipeIngredient.ID(rawValue: generator.uuid()),
                originalText: "source \(generator.int(in: 0...9_999))",
                presentationMode: dimension.mode,
                customDisplayText: generator.bool() ? "custom \(caseIndex)" : nil,
                quantity: quantity(
                    dimension.quantity, caseIndex: caseIndex, generator: &generator),
                unitText: generator.bool() ? "cups" : nil,
                package: package(isPresent: dimension.hasPackage, generator: &generator),
                ingredientText: generator.bool() ? "ingredient \(caseIndex)" : nil,
                preparation: generator.bool() ? "prepared \(caseIndex)" : nil,
                note: generator.bool() ? "note \(caseIndex)" : nil,
                isOptional: generator.bool(),
                scalingBehavior: dimension.scaling,
                parseState: parseStates[generator.int(in: 0...(parseStates.count - 1))]
            )

            guard let data = generatedValue(
                operation: "Ingredient encode", context: context,
                body: { try encoder.encode(ingredient) }
            ) else { continue }
            guard let decoded = generatedValue(
                operation: "Ingredient decode", context: context,
                body: { try decoder.decode(RecipeIngredient.self, from: data) }
            ) else { continue }

            XCTAssertEqual(decoded, ingredient, context)
        }

        XCTAssertEqual(dimensions.count, 3 * 3 * QuantityFixture.allCases.count * 2)
    }

    private func ingredientDimensions() -> [IngredientDimensions] {
        let modes: [RecipeIngredient.PresentationMode] = [.structured, .original, .custom]
        let scaling: [RecipeIngredient.ScalingBehavior] = [.linear, .fixed, .manualReview]
        return modes.flatMap { mode in
            scaling.flatMap { behavior in
                QuantityFixture.allCases.flatMap { quantity in
                    [false, true].map {
                        IngredientDimensions(
                            mode: mode, scaling: behavior, quantity: quantity, hasPackage: $0)
                    }
                }
            }
        }
    }

    private func quantity(
        _ fixture: QuantityFixture,
        caseIndex: Int,
        generator: inout SeededGenerator
    ) -> QuantityExpression? {
        let lower = RationalQuantity(
            numerator: generator.int(in: 0...50),
            denominator: generator.int(in: 1...12)
        )
        switch fixture {
        case .absent:
            return nil
        case .none:
            return QuantityExpression(kind: .none)
        case .exact:
            return QuantityExpression(kind: .exact, lowerBound: lower)
        case .range:
            return QuantityExpression(
                kind: .range,
                lowerBound: lower,
                upperBound: RationalQuantity(numerator: generator.int(in: 51...100))
            )
        case .approximate:
            return QuantityExpression(kind: .approximate, lowerBound: lower, text: "about")
        case .text:
            return QuantityExpression(kind: .text, text: "to taste \(caseIndex)")
        }
    }

    private func package(
        isPresent: Bool,
        generator: inout SeededGenerator
    ) -> PackageDescription? {
        guard isPresent else { return nil }
        return PackageDescription(
            quantity: QuantityExpression(
                kind: .exact,
                lowerBound: RationalQuantity(numerator: generator.int(in: 1...32))
            ),
            unitText: "ounces"
        )
    }

    private func generatedValue<Value>(
        operation: String,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        body: () throws -> Value
    ) -> Value? {
        do {
            return try body()
        } catch {
            XCTFail("\(operation) failed; \(context); error=\(error)", file: file, line: line)
            return nil
        }
    }
}

private enum QuantityFixture: String, CaseIterable {
    case absent, none, exact, range, approximate, text
}

private struct IngredientDimensions {
    let mode: RecipeIngredient.PresentationMode
    let scaling: RecipeIngredient.ScalingBehavior
    let quantity: QuantityFixture
    let hasPackage: Bool

    func context(seed: String, caseIndex: Int) -> String {
        [
            "seed=\(seed)", "case=\(caseIndex)", "mode=\(mode)", "scaling=\(scaling)",
            "quantity=\(quantity.rawValue)", "package=\(hasPackage)",
        ].joined(separator: " ")
    }
}
