// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain

func makeRichCodableRevision() -> RecipeRevision {
    RecipeRevision(
        id: stableID("3792B579-C24B-4A69-9B6A-E9019B320EEB"),
        recipeID: stableID("B83A8738-E2BA-462F-A95E-C7C9C9CE51A3"),
        revisionNumber: 7,
        title: "Tomato Supper",
        summary: "A complete Codable fixture",
        authorName: "Kitchen Memory",
        source: makeCodableSource(),
        sourceCapture: makeCodableSourceCapture(),
        recipeYield: RecipeYield(
            quantity: QuantityExpression(
                kind: .approximate,
                lowerBound: RationalQuantity(numerator: 6)
            ),
            unitText: "servings",
            originalText: "About 6 servings"
        ),
        prepDuration: RecipeDuration(seconds: 900),
        cookDuration: RecipeDuration(seconds: 2_700),
        totalDuration: RecipeDuration(seconds: 3_600),
        cuisines: ["Italian American"],
        categories: ["Dinner"],
        keywords: ["tomato", "make-ahead"],
        media: [makeCodableMedia()],
        equipment: [makeCodableEquipment()],
        ingredientSections: [
            IngredientSection(
                id: stableID("0292D9D4-7536-47E0-9CB7-D27F041A52CD"),
                title: "Main",
                ingredients: [makeRichCodableIngredient()]
            ),
        ],
        instructionSections: [makeCodableInstructionSection()]
    )
}

private func makeRichCodableIngredient() -> RecipeIngredient {
    RecipeIngredient(
        id: stableID("ABEF8C4F-F51A-42A8-AC68-CB1B62B3ED04"),
        originalText: "2 (14-ounce) cans tomatoes, drained",
        presentationMode: .custom,
        customDisplayText: "Two cans of drained tomatoes",
        quantity: QuantityExpression(
            kind: .range,
            lowerBound: RationalQuantity(numerator: 2),
            upperBound: RationalQuantity(numerator: 3),
            text: "2 to 3"
        ),
        unitText: "cans",
        package: PackageDescription(
            quantity: QuantityExpression(
                kind: .exact,
                lowerBound: RationalQuantity(numerator: 14)
            ),
            unitText: "ounces"
        ),
        ingredientText: "tomatoes",
        preparation: "drained",
        note: "prefer fire-roasted",
        isOptional: true,
        scalingBehavior: .manualReview,
        parseState: .edited
    )
}

private func makeCodableSource() -> RecipeSource {
    RecipeSource(
        kind: .webpage,
        title: "Source recipe",
        authorName: "Example Author",
        publisherName: "Example Publisher",
        canonicalURL: URL(string: "https://example.com/recipes/tomato-supper")
    )
}

private func makeCodableSourceCapture() -> RecipeSourceCapture {
    RecipeSourceCapture(
        kind: .schemaOrgJSONLD,
        sourceURL: URL(string: "https://example.com/recipes/tomato-supper")!,
        capturedAt: Date(timeIntervalSinceReferenceDate: 123_456_789),
        mediaType: "application/ld+json",
        payload: Data(#"{"@type":"Recipe"}"#.utf8),
        blockIndex: 2,
        objectIndex: 1
    )
}

private func makeCodableMedia() -> RecipeMedia {
    RecipeMedia(
        id: stableID("6F1053F0-38A4-4AB2-A48B-9F74DAD18911"),
        role: .hero,
        assetName: "tomato-supper",
        accessibilityLabel: "Tomato supper in a blue bowl"
    )
}

private func makeCodableEquipment() -> EquipmentItem {
    EquipmentItem(
        id: stableID("B2FB6958-BD6E-40E7-A2A7-4F3514871553"),
        originalText: "1 Dutch oven",
        quantity: QuantityExpression(
            kind: .exact,
            lowerBound: RationalQuantity(numerator: 1)
        ),
        name: "Dutch oven",
        isOptional: false
    )
}

private func makeCodableInstructionSection() -> InstructionSection {
    InstructionSection(
        id: stableID("09258C85-F1F1-4E19-A26B-63B84FC4BE76"),
        title: "Cook",
        steps: [
            InstructionStep(
                id: stableID("8A741516-B51F-462D-9FF9-69ED8A69B24D"),
                name: "Simmer",
                text: "Simmer until thickened.",
                duration: RecipeDuration(seconds: 1_200),
                temperature: RecipeTemperature(
                    value: RationalQuantity(numerator: 350),
                    unit: .fahrenheit
                )
            ),
        ]
    )
}

private func stableID<Entity>(_ uuidString: String) -> StableIdentifier<Entity> {
    StableIdentifier(rawValue: UUID(uuidString: uuidString)!)
}
