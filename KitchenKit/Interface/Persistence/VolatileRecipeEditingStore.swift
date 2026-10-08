// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

/// Process-local draft store for disposable graphs; it provides no relaunch durability.
@MainActor
public final class VolatileRecipeEditingStore: RecipeEditingStoring {
  /// Creates an empty process-local draft store.
  public init() {}
  private var drafts: [RecipeEditingRecord] = []
  /// Returns the currently retained in-memory draft collection.
  public func load() throws -> [RecipeEditingRecord] { drafts }
  /// Replaces the process-local collection without file or cloud persistence.
  public func save(_ drafts: [RecipeEditingRecord]) throws { self.drafts = drafts }
}
