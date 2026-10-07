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

// These related public values and their caller contracts form one domain boundary.
// Keep their documentation beside the declarations rather than splitting the contract.
// swiftlint:disable file_length

/// Bounded transport bytes and final response metadata before text interpretation.
///
/// The final URL records redirects; constructing this value does not validate the
/// destination, content type, or encoding.
public struct FetchedRecipeDocument: Equatable, Sendable {
  /// The acquired response body before character decoding and JSON-LD discovery.
  public var data: Data
  /// The actual final document location after accepted redirects, used as acquired provenance.
  public var finalURL: URL
  /// The response MIME type, if supplied; absence does not itself prove non-HTML content.
  public var mediaType: String?
  /// The declared response charset used by the coordinator’s supported decoder choices.
  public var textEncodingName: String?

  /// Retains transport bytes and metadata without enforcing loader or parser budgets.
  public init(
    data: Data,
    finalURL: URL,
    mediaType: String? = nil,
    textEncodingName: String? = nil
  ) {
    self.data = data
    self.finalURL = finalURL
    self.mediaType = mediaType
    self.textEncodingName = textEncodingName
  }
}

/// Acquires a document separately from deterministic Recipe parsing and review.
public protocol RecipeDocumentLoading: Sendable {
  /// Asynchronously acquires response bytes and final metadata for deterministic parsing.
  ///
  /// Implementations own destination policy, resource bounds, and cancellation; the
  /// protocol itself performs no validation or Recipe publication.
  func load(_ url: URL) async throws -> FetchedRecipeDocument
}

/// A transport, decoding, or parser-budget failure for a URL import.
///
/// Underlying system network errors and cancellation may also escape the operation.
public enum RecipeURLImportError: Error, Equatable, Sendable {
  /// The initial, redirect, or final URL fails the structural HTTPS destination policy.
  case disallowedURL
  /// The loader’s accepted redirect allowance was exceeded.
  case tooManyRedirects
  /// The response is not a successful 2xx HTTP response with a final URL.
  case invalidResponse
  /// Declared or streamed response bytes exceed the loader’s configured maximum.
  case responseTooLarge(maximumBytes: Int)
  /// A supplied response MIME type is neither HTML nor XHTML.
  case unsupportedContentType
  /// The response cannot decode using its declared supported charset or the UTF-8 fallback.
  case undecodableDocument
  /// Recipe discovery exceeded the coordinator’s positive candidate allowance.
  case tooManyCandidates(maximum: Int)
  /// A non-candidate parser resource budget was exhausted.
  case processingLimitExceeded
}
