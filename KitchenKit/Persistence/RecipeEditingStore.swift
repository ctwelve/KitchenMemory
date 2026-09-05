// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

public struct RecipeEditingRecord: Codable, Equatable {
  public let id: UUID
  public let original: StoredRecipe?
  public let concerns: [RecipeImportConcern]
  public var session: RecipeEditSession
  public var observedSelectionIDs: [RecipeSelectionCommand.ID]
  public var pendingSave: RecipeSaveCommand?
  public var isImportCandidate: Bool?
  public var importIdentifier: String?
  public var phase: RecipeAuthoringPhase?

  public init(id: UUID, original: StoredRecipe?, concerns: [RecipeImportConcern], session: RecipeEditSession,
              observedSelectionIDs: [RecipeSelectionCommand.ID], pendingSave: RecipeSaveCommand? = nil,
              isImportCandidate: Bool? = nil, importIdentifier: String? = nil, phase: RecipeAuthoringPhase? = nil) {
    self.id = id
    self.original = original
    self.concerns = concerns
    self.session = session
    self.observedSelectionIDs = observedSelectionIDs
    self.pendingSave = pendingSave
    self.isImportCandidate = isImportCandidate
    self.importIdentifier = importIdentifier
    self.phase = phase
  }
}

@MainActor
public protocol RecipeEditingStoring {
  func load() throws -> [RecipeEditingRecord]
  func save(_ drafts: [RecipeEditingRecord]) throws
}

@MainActor
public final class VolatileRecipeEditingStore: RecipeEditingStoring {
  public init() {}
  private var drafts: [RecipeEditingRecord] = []
  public func load() throws -> [RecipeEditingRecord] { drafts }
  public func save(_ drafts: [RecipeEditingRecord]) throws { self.drafts = drafts }
}

/// A device-local atomic document, never registered in the CloudKit schema.
@MainActor
public struct FileRecipeEditingStore: RecipeEditingStoring {
  public let url: URL

  public init(url: URL) { self.url = url }

  private struct Document: Codable {
    var version = 1
    let drafts: [RecipeEditingRecord]
  }

  public enum Failure: Error { case invalidDocument }

  public func load() throws -> [RecipeEditingRecord] {
    guard FileManager.default.fileExists(atPath: url.path) else { return [] }
    let document = try JSONDecoder().decode(Document.self, from: Data(contentsOf: url))
    let existing = document.drafts.compactMap { $0.original?.id }
    guard document.version == 1,
          Set(document.drafts.map(\.id)).count == document.drafts.count,
          Set(existing).count == existing.count else { throw Failure.invalidDocument }
    return document.drafts
  }

  public func save(_ drafts: [RecipeEditingRecord]) throws {
    let data = try JSONEncoder().encode(Document(drafts: drafts))
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
  }
}
