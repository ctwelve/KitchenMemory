#!/usr/bin/env swift

// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation

private struct Theme: Decodable {
    let tokens: [String: String]
}

private struct AssetContents: Decodable {
    struct Entry: Decodable {
        struct Appearance: Decodable {
            let appearance: String
            let value: String
        }

        struct Color: Decodable {
            struct Components: Decodable {
                let alpha: String
                let blue: String
                let green: String
                let red: String
            }

            let components: Components
        }

        let appearances: [Appearance]?
        let color: Color
    }

    let colors: [Entry]
}

private struct ColorValue {
    let alpha: Double
    let blue: Double
    let green: Double
    let red: Double

    var hex: String {
        func byte(_ component: Double) -> Int {
            Int((component * 255).rounded())
        }

        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    var iconComposerValue: String {
        String(
            format: "extended-srgb:%.5f,%.5f,%.5f,%.5f",
            red,
            green,
            blue,
            alpha
        )
    }
}

private struct AdaptiveColor {
    let light: ColorValue
    let dark: ColorValue
}

private struct LayerSpec {
    let filename: String
    let name: String
    let token: String
}

private enum Appearance: String, CaseIterable {
    case light
    case dark
}

private enum GenerationError: Error, CustomStringConvertible {
    case invalidComponent(String)
    case missingAppearance(String, String)
    case missingToken(String)
    case outOfDate(String)

    var description: String {
        switch self {
        case .invalidComponent(let value):
            "Invalid asset-catalog color component: \(value)"
        case .missingAppearance(let asset, let appearance):
            "Color asset \(asset) has no \(appearance) appearance"
        case .missingToken(let name):
            "SVG template references unknown color token: \(name)"
        case .outOfDate(let path):
            "Generated file is out of date: \(path)"
        }
    }
}

private let fileManager = FileManager.default
private let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
private let themeURL = root.appending(path: "Design/Palette.json")
private let assetCatalogURL = root.appending(path: "KitchenMemory/Assets.xcassets")
private let layerSourceURL = root.appending(path: "Design/AppIcon/Layers")
private let generatedURL = root.appending(path: "Design/AppIcon/Generated")
private let generatedLayersURL = generatedURL.appending(path: "Layers")
private let appIconURL = root.appending(path: "KitchenMemory/AppIcon.icon")
private let appIconAssetsURL = appIconURL.appending(path: "Assets")
private let checkOnly = CommandLine.arguments.dropFirst().contains("--check")

private let layerSpecs = [
    LayerSpec(filename: "01-RearCard", name: "Rear Card", token: "iconCardRear"),
    LayerSpec(filename: "02-MiddleCard", name: "Middle Card", token: "iconCardMiddle"),
    LayerSpec(filename: "03-FeaturedCard", name: "Featured Card", token: "iconCardFront"),
    LayerSpec(filename: "04-RecipeMarks", name: "Recipe Marks", token: "iconMark"),
    LayerSpec(filename: "05-LowTray", name: "Low Tray", token: "iconTray"),
]

private func value(from components: AssetContents.Entry.Color.Components) throws -> ColorValue {
    func number(_ string: String) throws -> Double {
        guard let value = Double(string) else {
            throw GenerationError.invalidComponent(string)
        }
        return value
    }

    return try ColorValue(
        alpha: number(components.alpha),
        blue: number(components.blue),
        green: number(components.green),
        red: number(components.red)
    )
}

private func loadColor(named assetName: String) throws -> AdaptiveColor {
    let url = assetCatalogURL
        .appending(path: "\(assetName).colorset")
        .appending(path: "Contents.json")
    let data = try Data(contentsOf: url)
    let contents = try JSONDecoder().decode(AssetContents.self, from: data)

    guard let lightEntry = contents.colors.first(where: { $0.appearances == nil }) else {
        throw GenerationError.missingAppearance(assetName, Appearance.light.rawValue)
    }
    guard let darkEntry = contents.colors.first(where: { entry in
        entry.appearances?.contains {
            $0.appearance == "luminosity" && $0.value == Appearance.dark.rawValue
        } == true
    }) else {
        throw GenerationError.missingAppearance(assetName, Appearance.dark.rawValue)
    }

    return try AdaptiveColor(
        light: value(from: lightEntry.color.components),
        dark: value(from: darkEntry.color.components)
    )
}

private func rendered(
    _ template: String,
    appearance: Appearance,
    colors: [String: AdaptiveColor]
) throws -> String {
    let expression = try NSRegularExpression(pattern: #"\{\{([A-Za-z][A-Za-z0-9]*)\}\}"#)
    let matches = expression.matches(
        in: template,
        range: NSRange(template.startIndex..., in: template)
    ).reversed()
    var result = template

    for match in matches {
        guard let range = Range(match.range(at: 1), in: result) else { continue }
        let name = String(result[range])
        guard let color = colors[name] else {
            throw GenerationError.missingToken(name)
        }
        guard let fullRange = Range(match.range(at: 0), in: result) else { continue }
        result.replaceSubrange(
            fullRange,
            with: appearance == .light ? color.light.hex : color.dark.hex
        )
    }

    return result
}

private func svg(containing body: String) -> String {
    """
    <!-- Copyright © 2026 the Kitchen Memory contributors. SPDX-License-Identifier: GPL-3.0-only -->
    <svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
    \(body)
    </svg>

    """
}

private func emit(_ contents: String, to url: URL) throws {
    let relativePath = url.path.replacingOccurrences(of: root.path + "/", with: "")

    if checkOnly {
        let existing = try String(contentsOf: url, encoding: .utf8)
        guard existing == contents else {
            throw GenerationError.outOfDate(relativePath)
        }
    } else {
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let existing = try? String(contentsOf: url, encoding: .utf8)
        guard existing != contents else { return }
        try contents.write(to: url, atomically: true, encoding: .utf8)
        print("Generated \(relativePath)")
    }
}

private func fillSpecializations(for color: AdaptiveColor) -> [[String: Any]] {
    [
        ["value": ["solid": color.light.iconComposerValue]],
        [
            "appearance": "dark",
            "value": ["solid": color.dark.iconComposerValue],
        ],
    ]
}

private func iconLayer(_ spec: LayerSpec, colors: [String: AdaptiveColor]) throws -> [String: Any] {
    guard let color = colors[spec.token] else {
        throw GenerationError.missingToken(spec.token)
    }

    var layer: [String: Any] = [
        "fill-specializations": fillSpecializations(for: color),
        "image-name": "\(spec.filename).svg",
        "name": spec.name,
        "position": [
            "scale": 1,
            "translation-in-points": [0, -30],
        ],
    ]
    if spec.token == "iconMark" {
        layer["glass"] = false
        layer["hidden"] = false
    }
    return layer
}

private func iconDocument(colors: [String: AdaptiveColor]) throws -> String {
    guard let background = colors["iconBackground"] else {
        throw GenerationError.missingToken("iconBackground")
    }

    let layers = try Dictionary(uniqueKeysWithValues: layerSpecs.map {
        ($0.token, try iconLayer($0, colors: colors))
    })
    let document: [String: Any] = [
        "fill-specializations": fillSpecializations(for: background),
        "groups": [
            [
                "layers": [layers["iconTray"]!],
                "shadow": ["kind": "neutral", "opacity": 0.35],
                "translucency": ["enabled": true, "value": 0.18],
            ],
            [
                "layers": [layers["iconMark"]!],
                "shadow": ["kind": "neutral", "opacity": 0.12],
                "translucency": ["enabled": false, "value": 0.0],
            ],
            [
                "layers": [
                    layers["iconCardFront"]!,
                    layers["iconCardMiddle"]!,
                    layers["iconCardRear"]!,
                ],
                "shadow": ["kind": "neutral", "opacity": 0.25],
                "translucency": ["enabled": true, "value": 0.08],
            ],
        ],
        "supported-platforms": ["squares": "shared"],
    ]

    let data = try JSONSerialization.data(
        withJSONObject: document,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    return String(decoding: data, as: UTF8.self) + "\n"
}

do {
    let themeData = try Data(contentsOf: themeURL)
    let theme = try JSONDecoder().decode(Theme.self, from: themeData)
    let colors = try Dictionary(uniqueKeysWithValues: theme.tokens.map {
        ($0.key, try loadColor(named: $0.value))
    })
    let layerURLs = try fileManager.contentsOfDirectory(
        at: layerSourceURL,
        includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "svgpart" }.sorted { $0.lastPathComponent < $1.lastPathComponent }

    for layerURL in layerURLs {
        let template = try String(contentsOf: layerURL, encoding: .utf8)
        let filename = layerURL.deletingPathExtension().lastPathComponent + ".svg"
        let contents = svg(containing: try rendered(template, appearance: .light, colors: colors))
        try emit(contents, to: generatedLayersURL.appending(path: filename))
        try emit(contents, to: appIconAssetsURL.appending(path: filename))
    }

    let combinedTemplate = try layerURLs
        .map { try String(contentsOf: $0, encoding: .utf8) }
        .joined(separator: "")

    for appearance in Appearance.allCases {
        guard let background = colors["iconBackground"] else {
            throw GenerationError.missingToken("iconBackground")
        }
        let backgroundValue = appearance == .light ? background.light : background.dark
        let previewBody = "  <rect width=\"1024\" height=\"1024\" rx=\"224\" fill=\"\(backgroundValue.hex)\"/>\n"
            + combinedTemplate
        let destination = generatedURL.appending(path: "Preview-\(appearance.rawValue.capitalized).svg")
        try emit(svg(containing: try rendered(previewBody, appearance: appearance, colors: colors)), to: destination)
    }

    try emit(try iconDocument(colors: colors), to: appIconURL.appending(path: "icon.json"))
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(EXIT_FAILURE)
}
