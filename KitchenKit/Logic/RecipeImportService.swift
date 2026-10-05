// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

// Import interpretation is product logic; networking and JSON-LD discovery
// remain behind KitchenKit's Import responsibility.

import Foundation

/// A review concern discovered while translating imported content into a draft.
///
/// Concerns preserve uncertainty for presentation; they are not silent repairs
/// and do not authorize saving an import into the library.
public enum RecipeImportConcern: Codable, Equatable, Sendable {
  /// No nonblank title was provided by the imported candidate.
  case missingTitle
  /// The imported candidate has no ingredient rows.
  case missingIngredients
  /// The imported candidate has no instruction steps.
  case missingInstructions
  /// Ingredient wording could not be interpreted into structured fields.
  case unparsedIngredients(count: Int)
  /// Machine-parsed ingredient fields still require human review.
  case provisionalIngredients(count: Int)
  /// Malformed or unsupported source blocks were excluded from candidate discovery.
  case ignoredSourceBlocks(count: Int)
  /// Source taxonomy was retained as authored wording rather than converted into Kitchen Tags.
  case preservedTaxonomy(cuisines: [String], categories: [String], keywords: [String])
  /// The source names images; those references do not mean private image bytes were imported.
  case referencedImages(count: Int)

  /// Whether the concern describes retained source information rather than missing or uncertain content.
  public var isInformational: Bool {
    switch self {
    case .preservedTaxonomy, .referencedImages: true
    default: false
    }
  }
}

/// One reviewable recipe candidate and the concerns a person should consider.
public struct RecipeImportOption: Codable, Equatable, Identifiable, Sendable {
  /// Candidate location within one captured document, distinct from a durable Recipe identity.
  public struct Identifier: Codable, Hashable, Sendable {
    /// Index of the source JSON-LD block that supplied the candidate.
    public var blockIndex: Int
    /// Index of the candidate object within its source block.
    public var objectIndex: Int

    /// Creates a source-location identifier without generating Recipe authority.
    public init(blockIndex: Int, objectIndex: Int) {
      self.blockIndex = blockIndex
      self.objectIndex = objectIndex
    }
  }

  /// Source-location identity within this import result.
  public var id: Identifier
  /// Editable candidate contents and retained source capture, awaiting review and explicit Save.
  public var draft: RecipeDraft
  /// Review concerns and informational source observations accompanying this candidate.
  public var concerns: [RecipeImportConcern]

  /// Creates a reviewable candidate without accepting it into draft storage or Recipe authority.
  public init(id: Identifier, draft: RecipeDraft, concerns: [RecipeImportConcern]) {
    self.id = id
    self.draft = draft
    self.concerns = concerns
  }
}

/// Product-facing access to person-initiated recipe import.
public protocol RecipeImportServing: Sendable {
  /// Retrieves bounded source content and returns candidates for explicit review.
  /// Does not persist or publish a Recipe; cancellation and import failures are thrown.
  func importRecipe(from url: URL) async throws -> [RecipeImportOption]
}

/// Product-level import failures after transport and parsing limits are classified.
public enum RecipeImportServiceError: Error, Equatable, Sendable {
  /// No supported Recipe candidate was found in the retrieved document.
  case noRecipeCandidates
  /// The requested address or redirect chain is outside the bounded fetch policy.
  case disallowedAddress
  /// Input size, candidate count, or processing limits were exceeded.
  case pageTooLarge
  /// The response or document encoding cannot be interpreted as supported recipe content.
  case unsupportedPage
  /// Retrieval failed for a reason outside the recognized policy failures.
  case networkFailure
}

/// Converts bounded URL-import results into reviewable recipe drafts.
///
/// This service maps transport and parsing failures into product-level errors
/// and records source evidence. It does not persist a selected candidate.
public struct RecipeImportService: RecipeImportServing, Sendable {
  /// Explicit parser selection for supplied document bytes.
  public enum DocumentFormat: Sendable {
    /// HTML discovers Schema.org JSON-LD in UTF-8 markup; jsonLD interprets supplied JSON-LD directly.
    case html, jsonLD
  }

  /// Interprets already supplied bytes as reviewable import candidates without fetching or saving.
  /// Enforces parser input limits and retains source evidence at `capturedAt`. File URLs
  /// become imported attribution without an actionable canonical link. Throws on oversized,
  /// unsupported, or candidate-free content.
  public static func documentOptions(
    from data: Data, sourceURL: URL, format: DocumentFormat,
    capturedAt: Date = Date()
  ) throws -> [RecipeImportOption] {
    let parser = SchemaOrgRecipeImporter()
    guard data.count <= parser.limits.maximumInputBytes else {
      throw RecipeImportServiceError.pageTooLarge
    }
    let result: RecipeImportResult
    switch format {
    case .html:
      guard let html = String(data: data, encoding: .utf8) else {
        throw RecipeImportServiceError.unsupportedPage
      }
      result = parser.importHTML(html, documentURL: sourceURL)
    case .jsonLD:
      result = parser.importJSONLD(data, documentURL: sourceURL)
    }
    return try options(from: result, requestedURL: sourceURL, capturedAt: capturedAt).map { option in
      var option = option
      if sourceURL.isFileURL {
        option.draft.source?.kind = .imported
        option.draft.source?.canonicalURL = nil
        option.draft.source?.title = sourceURL.lastPathComponent
      }
      return option
    }
  }

  private let importer: any RecipeURLImporting
  private let now: @Sendable () -> Date

  /// Uses the bounded URL importer backed by the supplied document loader.
  public init(loader: URLSessionRecipeDocumentLoader = .init()) {
    self.init(importer: RecipeURLImporter(loader: loader))
  }

  /// Injects bounded retrieval and a capture clock for deterministic import workflows.
  public init(
    importer: any RecipeURLImporting,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.importer = importer
    self.now = now
  }

  /// Retrieves and interprets candidates, recording capture time after retrieval.
  /// Throws classified ``RecipeImportServiceError`` failures and preserves cancellation.
  /// Returned candidates remain unpublished and require explicit review.
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
    return try Self.options(from: result, requestedURL: url, capturedAt: now())
  }

  static func options(
    from result: RecipeImportResult,
    requestedURL url: URL,
    capturedAt: Date
  ) throws -> [RecipeImportOption] {
    guard !result.candidates.isEmpty else {
      throw RecipeImportServiceError.noRecipeCandidates
    }
    let ignoredBlockCount = result.diagnostics.count { diagnostic in
      diagnostic.kind == .malformedJSONLD || diagnostic.kind == .unsupportedTopLevel
    }
    return result.candidates.map {
      option(
        from: $0,
        requestedURL: url,
        capturedAt: capturedAt,
        ignoredBlockCount: ignoredBlockCount
      )
    }
  }

  private static func concerns(
    for draft: RecipeImportDraft,
    ignoredBlockCount: Int
  ) -> [RecipeImportConcern] {
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
    return concerns
  }

  private static func option(
    from candidate: RecipeImportCandidate,
    requestedURL: URL,
    capturedAt: Date,
    ignoredBlockCount: Int
  ) -> RecipeImportOption {
    let draft = candidate.draft
    let sourceURL = candidate.snapshot.documentURL
      ?? draft.source.canonicalURL
      ?? requestedURL
    // Publisher-declared canonical URLs are useful evidence, but they are
    // untrusted fields inside the downloaded JSON-LD and may point to a
    // different origin. The final URL that URLSession actually fetched is
    // the honest active attribution for this import. The bounded raw capture
    // still preserves the publisher value for inspection or future parsing.
    var attributedSource = draft.source
    attributedSource.canonicalURL = sourceURL
    return RecipeImportOption(
      id: .init(
        blockIndex: candidate.id.blockIndex,
        objectIndex: candidate.id.objectIndex
      ),
      draft: RecipeDraft(
        title: draft.title,
        summary: draft.summary,
        authorName: draft.authorName,
        contentLanguage: draft.contentLanguage,
        source: attributedSource,
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
      concerns: concerns(for: draft, ignoredBlockCount: ignoredBlockCount)
    )
  }
}
