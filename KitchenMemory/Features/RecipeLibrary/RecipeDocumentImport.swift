// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit

extension RecipeLibraryModel {
  func importDocument(from url: URL) throws -> [RecipeImportOption] {
    let hasAccess = url.startAccessingSecurityScopedResource()
    defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    let maximum = RecipeImportLimits().maximumInputBytes
    var data = Data()
    while data.count <= maximum {
      guard let chunk = try handle.read(upToCount: maximum + 1 - data.count), !chunk.isEmpty else { break }
      data.append(chunk)
    }
    let options = try library.importDocument(
      data, sourceURL: url,
      format: ["html", "htm"].contains(url.pathExtension.lowercased()) ? .html : .jsonLD
    )
    try stageImports(options)
    return options
  }
}
