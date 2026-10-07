// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Coordinates document acquisition, text decoding, and bounded Schema.org discovery.
///
/// The supplied loader owns transport policy. This type preserves the fetched URL
/// and promotes parser resource diagnostics to operation failures.
public struct RecipeURLImporter<Loader: RecipeDocumentLoading>: Sendable {
  private let loader: Loader
  private let importer: SchemaOrgRecipeImporter
  private let maximumCandidates: Int

  /// Combines a loader with parser limits tightened to the positive candidate allowance.
  ///
  /// A nonpositive candidate allowance traps. A custom loader must enforce its own
  /// transport policy; this initializer does not replace it.
  public init(
    loader: Loader,
    importer: SchemaOrgRecipeImporter = .init(),
    maximumCandidates: Int = 25
  ) {
    precondition(maximumCandidates > 0)
    self.loader = loader
    self.importer = SchemaOrgRecipeImporter(
      limits: importer.limits.limitingCandidates(to: maximumCandidates)
    )
    self.maximumCandidates = maximumCandidates
  }

  /// Loads, decodes, and discovers reviewable Recipes using the actual final document URL.
  ///
  /// UTF-8 is the fallback; Latin-1, Windows-1252, and UTF-16 declarations are supported.
  /// Parser limit diagnostics become typed operation errors; malformed sibling blocks
  /// and missing titles remain in otherwise successful review results.
  public func importRecipe(from url: URL) async throws -> RecipeImportResult {
    let document = try await loader.load(url)
    guard let html = Self.decode(document) else {
      throw RecipeURLImportError.undecodableDocument
    }
    let result = importer.importHTML(html, documentURL: document.finalURL)
    if result.diagnostics.contains(where: { diagnostic in
      if case .processingLimitExceeded(.candidates) = diagnostic.kind { return true }
      return false
    }) {
      throw RecipeURLImportError.tooManyCandidates(maximum: maximumCandidates)
    }
    if result.diagnostics.contains(where: { diagnostic in
      if case .processingLimitExceeded = diagnostic.kind { return true }
      return false
    }) {
      throw RecipeURLImportError.processingLimitExceeded
    }
    return result
  }

  private static func decode(_ document: FetchedRecipeDocument) -> String? {
    let encoding: String.Encoding
    switch document.textEncodingName?.lowercased() {
    case "iso-8859-1", "latin1": encoding = .isoLatin1
    case "windows-1252", "cp1252": encoding = .windowsCP1252
    case "utf-16": encoding = .utf16
    default: encoding = .utf8
    }
    return String(data: document.data, encoding: encoding)
  }
}

extension RecipeURLImporter: RecipeURLImporting {}
