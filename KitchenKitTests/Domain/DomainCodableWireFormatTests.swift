// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import XCTest

final class DomainCodableWireFormatTests: XCTestCase {
    func testRichRevisionMatchesPinnedJSONWireFormat() throws {
        let fixture = Data(richRevisionWireJSON.utf8)
        let expected = makeRichCodableRevision()

        XCTAssertEqual(
            try JSONDecoder().decode(RecipeRevision.self, from: fixture),
            expected
        )

        // Comparing canonical JSON makes key order irrelevant while preserving
        // the authored fixture as an independent contract for every key/value.
        XCTAssertEqual(
            try canonicalJSON(JSONEncoder().encode(expected)),
            try canonicalJSON(fixture)
        )
    }

    private func canonicalJSON(_ data: Data) throws -> Data {
        let object = try JSONSerialization.jsonObject(with: data)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}

// Hand-authored rather than emitted by JSONEncoder so coordinated encoder and
// decoder drift cannot silently rewrite the expected durable representation.
private let richRevisionWireJSON = #"""
{
  "id": "3792B579-C24B-4A69-9B6A-E9019B320EEB",
  "recipeID": "B83A8738-E2BA-462F-A95E-C7C9C9CE51A3",
  "revisionNumber": 7,
  "title": "Tomato Supper",
  "summary": "A complete Codable fixture",
  "authorName": "Kitchen Memory",
  "source": {
    "kind": "webpage",
    "title": "Source recipe",
    "authorName": "Example Author",
    "publisherName": "Example Publisher",
    "canonicalURL": "https://example.com/recipes/tomato-supper"
  },
  "sourceCapture": {
    "kind": "schemaOrgJSONLD",
    "sourceURL": "https://example.com/recipes/tomato-supper",
    "capturedAt": 123456789,
    "mediaType": "application/ld+json",
    "payload": "eyJAdHlwZSI6IlJlY2lwZSJ9",
    "blockIndex": 2,
    "objectIndex": 1
  },
  "recipeYield": {
    "quantity": {
      "kind": "approximate",
      "lowerBound": {"numerator": 6, "denominator": 1}
    },
    "unitText": "servings",
    "originalText": "About 6 servings"
  },
  "prepDuration": {"seconds": 900},
  "cookDuration": {"seconds": 2700},
  "totalDuration": {"seconds": 3600},
  "cuisines": ["Italian American"],
  "categories": ["Dinner"],
  "keywords": ["tomato", "make-ahead"],
  "media": [
    {
      "id": "6F1053F0-38A4-4AB2-A48B-9F74DAD18911",
      "role": "hero",
      "assetName": "tomato-supper",
      "accessibilityLabel": "Tomato supper in a blue bowl"
    }
  ],
  "equipment": [
    {
      "id": "B2FB6958-BD6E-40E7-A2A7-4F3514871553",
      "originalText": "1 Dutch oven",
      "quantity": {
        "kind": "exact",
        "lowerBound": {"numerator": 1, "denominator": 1}
      },
      "name": "Dutch oven",
      "isOptional": false
    }
  ],
  "ingredientSections": [
    {
      "id": "0292D9D4-7536-47E0-9CB7-D27F041A52CD",
      "title": "Main",
      "ingredients": [
        {
          "id": "ABEF8C4F-F51A-42A8-AC68-CB1B62B3ED04",
          "originalText": "2 (14-ounce) cans tomatoes, drained",
          "presentationMode": "custom",
          "customDisplayText": "Two cans of drained tomatoes",
          "quantity": {
            "kind": "range",
            "lowerBound": {"numerator": 2, "denominator": 1},
            "upperBound": {"numerator": 3, "denominator": 1},
            "text": "2 to 3"
          },
          "unitText": "cans",
          "package": {
            "quantity": {
              "kind": "exact",
              "lowerBound": {"numerator": 14, "denominator": 1}
            },
            "unitText": "ounces"
          },
          "ingredientText": "tomatoes",
          "preparation": "drained",
          "note": "prefer fire-roasted",
          "isOptional": true,
          "scalingBehavior": "manualReview",
          "parseState": "edited"
        }
      ]
    }
  ],
  "instructionSections": [
    {
      "id": "09258C85-F1F1-4E19-A26B-63B84FC4BE76",
      "title": "Cook",
      "steps": [
        {
          "id": "8A741516-B51F-462D-9FF9-69ED8A69B24D",
          "name": "Simmer",
          "text": "Simmer until thickened.",
          "duration": {"seconds": 1200},
          "temperature": {
            "value": {"numerator": 350, "denominator": 1},
            "unit": "fahrenheit"
          }
        }
      ]
    }
  ]
}
"""#
