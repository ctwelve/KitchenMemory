// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Presentation-friendly classification of a URL import failure, without underlying transport details.
public enum RecipeImportSessionFailure: Equatable, Sendable {
  /// No supported Recipe candidate was returned.
  case noRecipeCandidates
  /// Fetch policy rejected the address or redirect chain.
  case disallowedAddress
  /// Bounded retrieval or parsing limits were exceeded.
  case pageTooLarge
  /// The retrieved response could not supply supported recipe content.
  case unsupportedPage
  /// The source could not be retrieved.
  case networkFailure
  /// The failure was not a recognized product import error.
  case unknown
}

/// Next explicit review step after candidate retrieval succeeds.
public enum RecipeImportSessionResult: Equatable, Sendable {
  /// One candidate can proceed directly to review without a chooser.
  case review(RecipeImportOption)
  /// Several retained candidates need an explicit selection.
  case choose
}

/// Pure state transitions for the person-initiated URL import workflow.
public struct RecipeImportSession: Equatable, Sendable {
  /// Maximum UTF-8 byte length admitted by the URL entry workflow.
  public static let maximumURLBytes = 4_096

  /// Person-entered URL text; a missing scheme is interpreted as HTTPS.
  public var enteredURL = ""
  /// Candidates awaiting selection when an import returns more than one option.
  public private(set) var candidates: [RecipeImportOption] = []
  /// Whether the workflow has begun an import and awaits completion or cancellation.
  public private(set) var isLoading = false
  /// Classified failure for presentation, cleared when another import begins.
  public private(set) var failure: RecipeImportSessionFailure?

  /// Creates an idle import workflow with empty input and no candidates.
  public init() {}

  /// Trimmed HTTPS URL with a nonempty host and no credentials, or nil for invalid input.
  /// Validation performs no network request and does not replace the bounded fetch policy.
  public var normalizedURL: URL? {
    let trimmed = enteredURL.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, trimmed.utf8.count <= Self.maximumURLBytes else { return nil }
    let parsed = URL(string: trimmed)
    let url = parsed?.scheme == nil ? URL(string: "https://\(trimmed)") : parsed
    guard let url,
          url.scheme?.lowercased() == "https",
          let host = url.host,
          !host.isEmpty,
          url.user == nil,
          url.password == nil
    else { return nil }
    return url
  }

  /// Marks a valid idle request loading and clears prior review state.
  /// Returns nil without mutation for invalid input or an already loading request.
  public mutating func beginImport() -> URL? {
    guard !isLoading, let url = normalizedURL else { return nil }
    isLoading = true
    candidates = []
    failure = nil
    return url
  }

  /// Ends loading and chooses direct review or retained candidate selection.
  /// An empty result records a missing-candidates failure; no Recipe is saved.
  public mutating func receive(_ options: [RecipeImportOption]) -> RecipeImportSessionResult? {
    isLoading = false
    guard !options.isEmpty else {
      failure = .noRecipeCandidates
      candidates = []
      return nil
    }
    failure = nil
    if options.count == 1, let option = options.first {
      candidates = []
      return .review(option)
    }
    candidates = options
    return .choose
  }

  /// Ends loading and classifies the failure; cancellation leaves no displayed failure.
  public mutating func receive(error: Error) {
    isLoading = false
    candidates = []
    failure = Self.failure(for: error)
  }

  /// Clears candidates and failure while retaining the entered URL and loading state.
  public mutating func useDifferentURL() {
    candidates = []
    failure = nil
  }

  /// Clears loading state; the caller remains responsible for cancelling its retrieval task.
  public mutating func cancel() {
    isLoading = false
  }

  private static func failure(for error: Error) -> RecipeImportSessionFailure? {
    if error is CancellationError { return nil }
    switch error as? RecipeImportServiceError {
    case .noRecipeCandidates: return .noRecipeCandidates
    case .disallowedAddress: return .disallowedAddress
    case .pageTooLarge: return .pageTooLarge
    case .unsupportedPage: return .unsupportedPage
    case .networkFailure: return .networkFailure
    case nil: return .unknown
    }
  }
}
