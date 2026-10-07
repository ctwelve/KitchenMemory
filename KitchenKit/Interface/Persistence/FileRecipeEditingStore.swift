// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// A device-local atomic document, never registered in the CloudKit schema.
@MainActor
public struct FileRecipeEditingStore: RecipeEditingStoring {
  /// Device-local document location; this document is never registered with CloudKit.
  public let url: URL

  /// Selects the local draft document location without reading or creating the file.
  public init(url: URL) { self.url = url }

  private struct Document: Codable {
    var version = 1
    let drafts: [RecipeEditingRecord]
  }

  /// Structural draft-document failures that prevent safe restoration.
  public enum Failure: Error {
    /// Unsupported document version or repeated draft/edited-Recipe identities prevent safe restoration.
    case invalidDocument
  }

  /// Decodes a version-1 local document and verifies unique draft and edited-Recipe identities.
  /// An absent file returns an empty collection; unsupported or inconsistent documents,
  /// decode failures, and filesystem failures throw without replacing stored evidence.
  public func load() throws -> [RecipeEditingRecord] {
    guard FileManager.default.fileExists(atPath: url.path) else { return [] }
    let document = try JSONDecoder().decode(Document.self, from: Data(contentsOf: url))
    let existing = document.drafts.compactMap { $0.original?.id }
    guard document.version == 1,
          Set(document.drafts.map(\.id)).count == document.drafts.count,
          Set(existing).count == existing.count else { throw Failure.invalidDocument }
    return document.drafts
  }

  /// Encodes the complete version-1 collection and atomically replaces the local document.
  /// Creates its parent directory if needed; encoding and filesystem failures propagate.
  public func save(_ drafts: [RecipeEditingRecord]) throws {
    let data = try JSONEncoder().encode(Document(drafts: drafts))
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
  }
}
