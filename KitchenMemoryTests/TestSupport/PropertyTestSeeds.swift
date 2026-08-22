// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation

enum PropertyTestSeedName: String, CaseIterable {
    case domainCodableIngredients = "domain.codable.ingredients"
    case domainRationalInverseScaling = "domain.rational.inverse-scaling"
    case domainRationalMultiplication = "domain.rational.multiplication"
    case domainRationalNormalization = "domain.rational.normalization"
    case importIngredientMixedFractions = "import.ingredient.mixed-fractions"
    case importNormalizerMarkup = "import.normalizer.markup"
    case importURLPublicHosts = "import.url.public-hosts"
}

struct PropertyTestSeed: Equatable {
    let name: String
    let hexadecimal: String
    let value: UInt64
}

struct PropertyTestSeeds {
    enum LoadError: Error, Equatable, CustomStringConvertible {
        case duplicateName(String)
        case duplicateValue(String, String)
        case emptyName
        case invalidHexadecimal(name: String, value: String)
        case malformedResource(String)
        case missingResource(String)
        case missingSeed(String)
        case unsupportedFormatVersion(Int)

        var description: String {
            switch self {
            case let .duplicateName(name):
                "Duplicate property-test seed name: \(name)"
            case let .duplicateValue(first, second):
                "Property-test seeds \(first) and \(second) have the same value"
            case .emptyName:
                "Property-test seed names must not be empty"
            case let .invalidHexadecimal(name, value):
                "Property-test seed \(name) has invalid hexadecimal value: \(value)"
            case let .malformedResource(details):
                "Malformed property-test seed resource: \(details)"
            case let .missingResource(name):
                "Missing property-test seed resource: \(name).json"
            case let .missingSeed(name):
                "Missing required property-test seed: \(name)"
            case let .unsupportedFormatVersion(version):
                "Unsupported property-test seed format version: \(version)"
            }
        }
    }

    private struct Document: Decodable {
        let formatVersion: Int
        let seeds: [Record]
    }

    private struct Record: Decodable {
        let name: String
        let hexadecimal: String
    }

    private let seedsByName: [String: PropertyTestSeed]

    init(data: Data) throws {
        let document: Document
        do {
            document = try JSONDecoder().decode(Document.self, from: data)
        } catch {
            throw LoadError.malformedResource(String(describing: error))
        }
        guard document.formatVersion == 1 else {
            throw LoadError.unsupportedFormatVersion(document.formatVersion)
        }

        var byName: [String: PropertyTestSeed] = [:]
        var namesByValue: [UInt64: String] = [:]
        for record in document.seeds {
            guard !record.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LoadError.emptyName
            }
            guard byName[record.name] == nil else {
                throw LoadError.duplicateName(record.name)
            }
            guard let value = Self.parseHexadecimal(record.hexadecimal) else {
                throw LoadError.invalidHexadecimal(name: record.name, value: record.hexadecimal)
            }
            if let existingName = namesByValue[value] {
                throw LoadError.duplicateValue(existingName, record.name)
            }

            byName[record.name] = PropertyTestSeed(
                name: record.name,
                hexadecimal: record.hexadecimal,
                value: value
            )
            namesByValue[value] = record.name
        }
        seedsByName = byName
    }

    static func bundled() throws -> PropertyTestSeeds {
        try load(resourceName: "PropertyTestSeeds", bundle: Bundle(for: PropertyTestBundleMarker.self))
    }

    static func load(resourceName: String, bundle: Bundle) throws -> PropertyTestSeeds {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw LoadError.missingResource(resourceName)
        }
        return try PropertyTestSeeds(data: Data(contentsOf: url))
    }

    func seed(named name: PropertyTestSeedName) throws -> PropertyTestSeed {
        guard let seed = seedsByName[name.rawValue] else {
            throw LoadError.missingSeed(name.rawValue)
        }
        return seed
    }

    var names: Set<String> {
        Set(seedsByName.keys)
    }

    private static func parseHexadecimal(_ text: String) -> UInt64? {
        guard text.hasPrefix("0x") else { return nil }
        let digits = text.dropFirst(2)
        guard !digits.isEmpty, digits.count <= 16 else { return nil }
        let asciiHexDigits = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        guard digits.unicodeScalars.allSatisfy(asciiHexDigits.contains) else { return nil }
        return UInt64(digits, radix: 16)
    }
}

private final class PropertyTestBundleMarker: NSObject {}
