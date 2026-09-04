// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import CryptoKit

struct RecipeEditingRecord: Codable, Equatable {
  let id: UUID
  let original: StoredRecipe?
  let concerns: [RecipeImportConcern]
  var session: RecipeEditSession
  var observedSelectionIDs: [RecipeSelectionCommand.ID]
  var pendingSave: RecipeSaveCommand?
  var isImportCandidate: Bool?
  var importIdentifier: String?
}

@MainActor
protocol RecipeEditingStoring {
  func load() throws -> [RecipeEditingRecord]
  func save(_ drafts: [RecipeEditingRecord]) throws
}

@MainActor
final class VolatileRecipeEditingStore: RecipeEditingStoring {
  private var drafts: [RecipeEditingRecord] = []
  func load() throws -> [RecipeEditingRecord] { drafts }
  func save(_ drafts: [RecipeEditingRecord]) throws { self.drafts = drafts }
}

/// A device-local atomic document, never registered in the CloudKit schema.
@MainActor
struct FileRecipeEditingStore: RecipeEditingStoring {
  let url: URL

  static func deviceLocal(ownerID: KitchenOwner.ID) throws -> Self {
    let directory = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask,
      appropriateFor: nil, create: true
    ).appendingPathComponent("RecipeDrafts", isDirectory: true)
    let owner = SHA256.hash(data: Data(ownerID.rawValue.utf8))
      .map { String(format: "%02x", $0) }.joined()
    return Self(url: directory.appendingPathComponent("\(owner).json"))
  }

  private struct Document: Codable {
    var version = 1
    let drafts: [RecipeEditingRecord]
  }

  enum Failure: Error { case invalidDocument }

  func load() throws -> [RecipeEditingRecord] {
    guard FileManager.default.fileExists(atPath: url.path) else { return [] }
    let document = try JSONDecoder().decode(Document.self, from: Data(contentsOf: url))
    let existing = document.drafts.compactMap { $0.original?.id }
    guard document.version == 1,
          Set(document.drafts.map(\.id)).count == document.drafts.count,
          Set(existing).count == existing.count else { throw Failure.invalidDocument }
    return document.drafts
  }

  func save(_ drafts: [RecipeEditingRecord]) throws {
    let data = try JSONEncoder().encode(Document(drafts: drafts))
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
  }
}
