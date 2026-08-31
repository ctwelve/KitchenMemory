// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import XCTest

final class LocalizationCatalogTests: XCTestCase {
  private let supportedLocales = ["en-US", "es-MX", "fr-CA"]
  private let localizedProductNames = [
    "en-US": "Kitchen Memory",
    "es-MX": "Memoria de cocina",
    "fr-CA": "Mémoire de cuisine",
  ]

  func testStableInterfaceCatalogIsCompleteAndTranslatorReady() throws {
    let catalog = try loadCatalog()
    XCTAssertEqual(catalog["sourceLanguage"] as? String, "en-US")
    let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
    XCTAssertFalse(strings.isEmpty)

    for (key, rawEntry) in strings {
      let entry = try XCTUnwrap(rawEntry as? [String: Any], "Malformed entry for \(key)")
      XCTAssertTrue(isSemanticKey(key), "English copy is not a stable key: \(key)")
      XCTAssertEqual(entry["extractionState"] as? String, "manual", "Unmanaged key: \(key)")
      XCTAssertFalse(
        (entry["comment"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          ?? true,
        "Missing translator context: \(key)"
      )

      let localizations = try XCTUnwrap(
        entry["localizations"] as? [String: Any],
        "Missing localizations for \(key)"
      )
      XCTAssertEqual(Set(localizations.keys), Set(supportedLocales), "Locale mismatch for \(key)")
      try assertCompleteLocalizations(localizations, key: key)
    }
  }

  func testStableInterfaceLocalizesEveryProductNameMention() throws {
    let catalog = try loadCatalog()
    let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])

    for (key, rawEntry) in strings {
      let entry = try XCTUnwrap(rawEntry as? [String: Any])
      let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any])
      let english = try XCTUnwrap(localizations["en-US"])
      let englishMentionsProduct = stringUnits(in: english).contains { unit in
        (unit["value"] as? String)?.contains("Kitchen Memory") == true
      }
      guard englishMentionsProduct else { continue }

      for locale in supportedLocales {
        let localization = try XCTUnwrap(localizations[locale])
        let expectedName = try XCTUnwrap(localizedProductNames[locale])
        XCTAssertTrue(
          stringUnits(in: localization).contains { unit in
            (unit["value"] as? String)?.contains(expectedName) == true
          },
          "Product name is not localized for \(key) in \(locale)"
        )
      }
    }
  }

  func testSystemProductNameCatalogMatchesFilesystemAndLocalizedNames() throws {
    let catalog = try loadCatalog(named: "InfoPlistLocalizationCatalog")
    XCTAssertEqual(catalog["sourceLanguage"] as? String, "en-US")
    let strings = try XCTUnwrap(catalog["strings"] as? [String: Any])
    XCTAssertEqual(
      Set(strings.keys),
      Set(["CFBundleDisplayName", "CFBundleName", "NSHumanReadableCopyright"])
    )

    for key in ["CFBundleDisplayName", "CFBundleName"] {
      let entry = try XCTUnwrap(strings[key] as? [String: Any])
      let localizations = try XCTUnwrap(entry["localizations"] as? [String: Any])
      XCTAssertEqual(Set(localizations.keys), Set(supportedLocales))

      for locale in supportedLocales {
        let localization = try XCTUnwrap(localizations[locale])
        let unit = try XCTUnwrap(stringUnits(in: localization).first)
        XCTAssertEqual(unit["state"] as? String, "translated")
        XCTAssertEqual(unit["value"] as? String, localizedProductNames[locale])
      }
    }

    let copyright = try XCTUnwrap(strings["NSHumanReadableCopyright"] as? [String: Any])
    let copyrightLocalizations = try XCTUnwrap(
      copyright["localizations"] as? [String: Any]
    )
    for locale in supportedLocales {
      let localization = try XCTUnwrap(copyrightLocalizations[locale])
      let unit = try XCTUnwrap(stringUnits(in: localization).first)
      let expectedName = try XCTUnwrap(localizedProductNames[locale])
      XCTAssertEqual((unit["value"] as? String)?.contains(expectedName), true)
    }
  }

  private func assertCompleteLocalizations(
    _ localizations: [String: Any],
    key: String
  ) throws {
    let english = try XCTUnwrap(localizations["en-US"])
    let englishUnits = stringUnits(in: english)
    XCTAssertFalse(englishUnits.isEmpty, "Missing English value for \(key)")
    let expectedPlaceholders = try placeholderSignature(in: englishUnits[0], key: key)
    let expectsPlurals = containsPluralVariation(english)

    for locale in supportedLocales {
      let localization = try XCTUnwrap(localizations[locale], "Missing \(locale) value for \(key)")
      let units = stringUnits(in: localization)
      XCTAssertFalse(units.isEmpty, "Missing \(locale) string unit for \(key)")
      XCTAssertEqual(
        containsPluralVariation(localization),
        expectsPlurals,
        "Plural structure differs for \(key) in \(locale)"
      )
      if expectsPlurals {
        XCTAssertTrue(hasRequiredPluralCategories(localization), "Incomplete plurals for \(key) in \(locale)")
      }

      for unit in units {
        XCTAssertEqual(unit["state"] as? String, "translated", "Unreviewed \(key) in \(locale)")
        let value = try XCTUnwrap(unit["value"] as? String, "Missing value for \(key) in \(locale)")
        XCTAssertFalse(value.isEmpty, "Empty value for \(key) in \(locale)")
        XCTAssertEqual(
          try placeholderSignature(in: unit, key: key),
          expectedPlaceholders,
          "Placeholder mismatch for \(key) in \(locale)"
        )
      }
    }
  }

  private func loadCatalog(named resource: String = "LocalizationCatalog") throws -> [String: Any] {
    let catalogURL = try XCTUnwrap(
      Bundle(for: Self.self).url(
        forResource: resource,
        withExtension: "json"
      ),
      "The raw String Catalog contract was not embedded in the test bundle."
    )
    let data = try Data(contentsOf: catalogURL)
    return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  private func isSemanticKey(_ key: String) -> Bool {
    key.range(
      of: #"^[a-z][a-z0-9]*(?:\.[a-z0-9][a-z0-9-]*)+$"#,
      options: .regularExpression
    ) != nil
  }

  private func stringUnits(in value: Any) -> [[String: Any]] {
    if let dictionary = value as? [String: Any] {
      var units: [[String: Any]] = []
      if let unit = dictionary["stringUnit"] as? [String: Any] {
        units.append(unit)
      }
      for child in dictionary.values {
        units.append(contentsOf: stringUnits(in: child))
      }
      return units
    }
    if let array = value as? [Any] {
      return array.flatMap(stringUnits)
    }
    return []
  }

  private func containsPluralVariation(_ value: Any) -> Bool {
    guard let dictionary = value as? [String: Any] else { return false }
    if let variations = dictionary["variations"] as? [String: Any],
       variations["plural"] != nil {
      return true
    }
    return dictionary.values.contains(where: containsPluralVariation)
  }

  private func hasRequiredPluralCategories(_ value: Any) -> Bool {
    guard let dictionary = value as? [String: Any] else { return false }
    if let variations = dictionary["variations"] as? [String: Any],
       let plural = variations["plural"] as? [String: Any] {
      return plural["one"] != nil && plural["other"] != nil
    }
    return dictionary.values.contains(where: hasRequiredPluralCategories)
  }

  private func placeholderSignature(
    in unit: [String: Any],
    key: String
  ) throws -> Set<String> {
    let value = try XCTUnwrap(unit["value"] as? String)
    let namedPattern = #"%(\d+)\$\(([^)]+)\)(ll)?([@d])"#
    let namedExpression = try NSRegularExpression(pattern: namedPattern)
    let fullRange = NSRange(value.startIndex..., in: value)
    let matches = namedExpression.matches(in: value, range: fullRange)
    let placeholders = Set(matches.compactMap { match -> String? in
      guard let position = Range(match.range(at: 1), in: value),
            let name = Range(match.range(at: 2), in: value),
            let kind = Range(match.range(at: 4), in: value) else {
        return nil
      }
      let length = Range(match.range(at: 3), in: value).map { String(value[$0]) } ?? ""
      return "\(value[position]):\(value[name]):\(length)\(value[kind])"
    })

    let stripped = namedExpression.stringByReplacingMatches(
      in: value,
      range: fullRange,
      withTemplate: ""
    )
    XCTAssertNil(
      stripped.range(of: #"%(?:(?:\d+)\$)?(?:ll)?[@d]"#, options: .regularExpression),
      "Unnamed placeholder in \(key): \(value)"
    )
    return placeholders
  }
}
