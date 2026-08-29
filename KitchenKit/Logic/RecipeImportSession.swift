// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

public enum RecipeImportSessionFailure: Equatable, Sendable {
  case noRecipeCandidates
  case disallowedAddress
  case pageTooLarge
  case unsupportedPage
  case networkFailure
  case unknown
}

public enum RecipeImportSessionResult: Equatable, Sendable {
  case review(RecipeImportOption)
  case choose
}

/// Pure state transitions for the person-initiated URL import workflow.
public struct RecipeImportSession: Equatable, Sendable {
  public static let maximumURLBytes = 4_096

  public var enteredURL = ""
  public private(set) var candidates: [RecipeImportOption] = []
  public private(set) var isLoading = false
  public private(set) var failure: RecipeImportSessionFailure?

  public init() {}

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

  public mutating func beginImport() -> URL? {
    guard !isLoading, let url = normalizedURL else { return nil }
    isLoading = true
    candidates = []
    failure = nil
    return url
  }

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

  public mutating func receive(error: Error) {
    isLoading = false
    candidates = []
    failure = Self.failure(for: error)
  }

  public mutating func useDifferentURL() {
    candidates = []
    failure = nil
  }

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
