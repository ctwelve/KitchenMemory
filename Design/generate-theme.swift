#!/usr/bin/env swift

// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation

private struct Palette: Decodable {
    let colors: [String: ColorToken]
}

private struct ColorToken: Decodable {
    let assetName: String?
    let light: String
    let dark: String
}

private enum Appearance: String, CaseIterable {
    case light
    case dark
}

private enum GenerationError: Error, CustomStringConvertible {
    case invalidHex(String)
    case missingToken(String)
    case outOfDate(String)

    var description: String {
        switch self {
        case .invalidHex(let value):
            "Invalid six-digit RGB color: \(value)"
        case .missingToken(let name):
            "SVG template references unknown color token: \(name)"
        case .outOfDate(let path):
            "Generated file is out of date: \(path)"
        }
    }
}

private let fileManager = FileManager.default
private let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
private let paletteURL = root.appending(path: "Design/Palette.json")
private let assetCatalogURL = root.appending(path: "KitchenMemory/Assets.xcassets")
private let layerSourceURL = root.appending(path: "Design/AppIcon/Layers")
private let generatedURL = root.appending(path: "Design/AppIcon/Generated")
private let generatedLayersURL = generatedURL.appending(path: "Layers")
private let checkOnly = CommandLine.arguments.dropFirst().contains("--check")

private func components(for hex: String) throws -> (red: String, green: String, blue: String) {
    let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    guard digits.count == 6, let value = Int(digits, radix: 16) else {
        throw GenerationError.invalidHex(hex)
    }

    func component(_ shift: Int) -> String {
        let byte = (value >> shift) & 0xFF
        return String(format: "%.3f", Double(byte) / 255.0)
    }

    return (component(16), component(8), component(0))
}

private func assetContents(for token: ColorToken) throws -> String {
    let light = try components(for: token.light)
    let dark = try components(for: token.dark)

    return """
    {
      "colors" : [
        {
          "color" : {
            "color-space" : "srgb",
            "components" : {
              "alpha" : "1.000",
              "blue" : "\(light.blue)",
              "green" : "\(light.green)",
              "red" : "\(light.red)"
            }
          },
          "idiom" : "universal"
        },
        {
          "appearances" : [
            {
              "appearance" : "luminosity",
              "value" : "dark"
            }
          ],
          "color" : {
            "color-space" : "srgb",
            "components" : {
              "alpha" : "1.000",
              "blue" : "\(dark.blue)",
              "green" : "\(dark.green)",
              "red" : "\(dark.red)"
            }
          },
          "idiom" : "universal"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }

    """
}

private func rendered(
    _ template: String,
    appearance: Appearance,
    palette: Palette
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
        guard let token = palette.colors[name] else {
            throw GenerationError.missingToken(name)
        }
        guard let fullRange = Range(match.range(at: 0), in: result) else { continue }
        result.replaceSubrange(fullRange, with: appearance == .light ? token.light : token.dark)
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
        try contents.write(to: url, atomically: true, encoding: .utf8)
        print("Generated \(relativePath)")
    }
}

do {
    let paletteData = try Data(contentsOf: paletteURL)
    let palette = try JSONDecoder().decode(Palette.self, from: paletteData)
    let layerURLs = try fileManager.contentsOfDirectory(
        at: layerSourceURL,
        includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "svgpart" }.sorted { $0.lastPathComponent < $1.lastPathComponent }

    for (_, token) in palette.colors.sorted(by: { $0.key < $1.key }) {
        guard let assetName = token.assetName else { continue }
        let destination = assetCatalogURL
            .appending(path: "\(assetName).colorset")
            .appending(path: "Contents.json")
        try emit(try assetContents(for: token), to: destination)
    }

    for layerURL in layerURLs {
        let template = try String(contentsOf: layerURL, encoding: .utf8)
        let destination = generatedLayersURL
            .appending(path: layerURL.deletingPathExtension().lastPathComponent + ".svg")
        try emit(svg(containing: try rendered(template, appearance: .light, palette: palette)), to: destination)
    }

    let combinedTemplate = try layerURLs
        .map { try String(contentsOf: $0, encoding: .utf8) }
        .joined(separator: "")

    for appearance in Appearance.allCases {
        let background = palette.colors["iconBackground"].map {
            appearance == .light ? $0.light : $0.dark
        } ?? "#000000"
        let previewBody = "  <rect width=\"1024\" height=\"1024\" rx=\"224\" fill=\"\(background)\"/>\n"
            + combinedTemplate
        let destination = generatedURL.appending(path: "Preview-\(appearance.rawValue.capitalized).svg")
        try emit(svg(containing: try rendered(previewBody, appearance: appearance, palette: palette)), to: destination)
    }
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(EXIT_FAILURE)
}
