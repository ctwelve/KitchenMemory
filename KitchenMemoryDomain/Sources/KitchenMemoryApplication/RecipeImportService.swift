// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain
import KitchenMemoryImport

public enum RecipeImportConcern: Equatable, Sendable {
  case missingTitle
  case missingIngredients
  case missingInstructions
  case unparsedIngredients(count: Int)
  case provisionalIngredients(count: Int)
  case ignoredSourceBlocks(count: Int)
  case preservedTaxonomy(cuisines: [String], categories: [String], keywords: [String])
  case referencedImages(count: Int)

  public var isInformational: Bool {
    switch self {
    case .preservedTaxonomy, .referencedImages: true
    default: false
    }
  }
}

public struct RecipeImportOption: Equatable, Identifiable, Sendable {
  public struct ID: Hashable, Sendable {
    public var blockIndex: Int
    public var objectIndex: Int

    public init(blockIndex: Int, objectIndex: Int) {
      self.blockIndex = blockIndex
      self.objectIndex = objectIndex
    }
  }

  public var id: ID
  public var draft: RecipeDraft
  public var concerns: [RecipeImportConcern]

  public init(id: ID, draft: RecipeDraft, concerns: [RecipeImportConcern]) {
    self.id = id
    self.draft = draft
    self.concerns = concerns
  }
}

public protocol RecipeImportServing: Sendable {
  func importRecipe(from url: URL) async throws -> [RecipeImportOption]
}

public enum RecipeImportServiceError: Error, Equatable, Sendable {
  case noRecipeCandidates
  case disallowedAddress
  case pageTooLarge
  case unsupportedPage
  case networkFailure
}

public struct RecipeImportService: RecipeImportServing, Sendable {
  private let importer: RecipeURLImporter<URLSessionRecipeDocumentLoader>

  public init(loader: URLSessionRecipeDocumentLoader = .init()) {
    importer = RecipeURLImporter(loader: loader)
  }

  public func importRecipe(from url: URL) async throws -> [RecipeImportOption] {
    let result: RecipeImportResult
    do {
      result = try await importer.importRecipe(from: url)
    } catch let error as RecipeURLImportError {
      switch error {
      case .disallowedURL, .tooManyRedirects:
        throw RecipeImportServiceError.disallowedAddress
      case .responseTooLarge, .tooManyCandidates, .processingLimitExceeded:
        throw RecipeImportServiceError.pageTooLarge
      case .unsupportedContentType, .undecodableDocument, .invalidResponse:
        throw RecipeImportServiceError.unsupportedPage
      }
    } catch is CancellationError {
      throw CancellationError()
    } catch {
      throw RecipeImportServiceError.networkFailure
    }
    return try Self.options(from: result, requestedURL: url, capturedAt: Date())
  }

  static func options(
    from result: RecipeImportResult,
    requestedURL url: URL,
    capturedAt: Date
  ) throws -> [RecipeImportOption] {
    guard !result.candidates.isEmpty else {
      throw RecipeImportServiceError.noRecipeCandidates
    }
    return result.candidates.map { candidate in
      let draft = candidate.draft
      let ingredients = draft.ingredientSections.flatMap(\.ingredients)
      var concerns: [RecipeImportConcern] = []
      if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        concerns.append(.missingTitle)
      }
      if ingredients.isEmpty { concerns.append(.missingIngredients) }
      if draft.instructionSections.flatMap(\.steps).isEmpty {
        concerns.append(.missingInstructions)
      }
      let unparsedCount = ingredients.count { $0.parseState == .unparsed }
      if unparsedCount > 0 { concerns.append(.unparsedIngredients(count: unparsedCount)) }
      // `parsed` means a deterministic machine interpretation was possible. It
      // does not mean a person confirmed the quantity, unit, or ingredient
      // boundary. Keeping that state visible prevents an apparently clean
      // import from quietly turning a parser guess into canonical truth.
      let provisionalCount = ingredients.count { $0.parseState == .parsed }
      if provisionalCount > 0 {
        concerns.append(.provisionalIngredients(count: provisionalCount))
      }
      let ignoredBlockCount = result.diagnostics.count { diagnostic in
        diagnostic.kind == .malformedJSONLD || diagnostic.kind == .unsupportedTopLevel
      }
      if ignoredBlockCount > 0 {
        concerns.append(.ignoredSourceBlocks(count: ignoredBlockCount))
      }
      if !draft.cuisines.isEmpty || !draft.categories.isEmpty || !draft.keywords.isEmpty {
        concerns.append(.preservedTaxonomy(
          cuisines: draft.cuisines,
          categories: draft.categories,
          keywords: draft.keywords
        ))
      }
      if !draft.imageURLs.isEmpty {
        concerns.append(.referencedImages(count: draft.imageURLs.count))
      }

      let sourceURL = candidate.snapshot.documentURL
        ?? draft.source.canonicalURL
        ?? url
      return RecipeImportOption(
        id: .init(
          blockIndex: candidate.id.blockIndex,
          objectIndex: candidate.id.objectIndex
        ),
        draft: RecipeDraft(
          title: draft.title,
          summary: draft.summary,
          authorName: draft.authorName,
          source: draft.source,
          sourceCapture: RecipeSourceCapture(
            kind: .schemaOrgJSONLD,
            sourceURL: sourceURL,
            capturedAt: capturedAt,
            mediaType: "application/ld+json",
            payload: candidate.snapshot.jsonLD,
            blockIndex: candidate.id.blockIndex,
            objectIndex: candidate.id.objectIndex
          ),
          recipeYield: draft.recipeYield,
          prepDuration: draft.prepDuration,
          cookDuration: draft.cookDuration,
          totalDuration: draft.totalDuration,
          cuisines: draft.cuisines,
          categories: draft.categories,
          keywords: draft.keywords,
          ingredientSections: draft.ingredientSections,
          instructionSections: draft.instructionSections
        ),
        concerns: concerns
      )
    }
  }
}
