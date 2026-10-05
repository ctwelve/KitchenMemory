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

/// Privacy-conscious system networking for person-initiated recipe imports.
///
/// A fresh ephemeral session is used for every import. It carries no cookie or
/// cache state, streams into a bounded buffer, and never executes page scripts.
public struct URLSessionRecipeDocumentLoader: RecipeDocumentLoading, Sendable {
  /// The default response-body limit of 2 MiB, independently enforced during streaming.
  public static let defaultMaximumBytes = 2 * 1_024 * 1_024

  /// The positive response byte allowance, checked against headers and actual streamed bytes.
  public var maximumBytes: Int
  /// The nonnegative count of redirects permitted within the same finite resource deadline.
  public var maximumRedirects: Int
  /// The positive system-owned resource and idle-request deadline in seconds.
  public var timeout: TimeInterval
  private let configurationProvider: @Sendable () -> URLSessionConfiguration

  /// Configures a fresh ephemeral transport for each load.
  ///
  /// Construction requires positive byte and timeout bounds and a nonnegative redirect
  /// allowance. Mutable configuration should preserve those constraints.
  public init(
    maximumBytes: Int = Self.defaultMaximumBytes,
    maximumRedirects: Int = 5,
    timeout: TimeInterval = 20
  ) {
    self.init(
      maximumBytes: maximumBytes,
      maximumRedirects: maximumRedirects,
      timeout: timeout,
      configurationProvider: Self.ephemeralConfiguration
    )
  }

  /// Internal seam for deterministic transport tests. Production callers use
  /// the public initializer, which always creates a fresh ephemeral session.
  init(
    maximumBytes: Int,
    maximumRedirects: Int = 5,
    timeout: TimeInterval = 20,
    configurationProvider: @escaping @Sendable () -> URLSessionConfiguration
  ) {
    precondition(maximumBytes > 0)
    precondition(maximumRedirects >= 0)
    precondition(timeout > 0)
    self.maximumBytes = maximumBytes
    self.maximumRedirects = maximumRedirects
    self.timeout = timeout
    self.configurationProvider = configurationProvider
  }

  // The transport policy is intentionally visible as one linear sequence from
  // URL validation through bounded response consumption.
  // swiftlint:disable function_body_length
  /// Fetches a structurally allowed HTTPS document with a fresh bodyless GET.
  ///
  /// Rejects disallowed redirects, non-2xx responses, oversized bodies, and declared
  /// non-HTML MIME types. System transport errors propagate; Swift task cancellation
  /// becomes `CancellationError` and invalidates the ephemeral session.
  public func load(_ url: URL) async throws -> FetchedRecipeDocument {
    try Task.checkCancellation()
    guard Self.isStructurallyAllowedFetchURL(url) else {
      throw RecipeURLImportError.disallowedURL
    }

    let redirectController = RedirectController(
      maximumRedirects: maximumRedirects,
      timeout: timeout
    )
    let configuration = makeSessionConfiguration()

    let session = URLSession(
      configuration: configuration,
      delegate: redirectController,
      delegateQueue: nil
    )
    defer { session.invalidateAndCancel() }

    let request = Self.recipeRequest(for: url, timeout: timeout)

    let bytes: URLSession.AsyncBytes
    let response: URLResponse
    do {
      (bytes, response) = try await session.bytes(for: request)
    } catch {
      try Task.checkCancellation()
      throw error
    }
    if let redirectError = redirectController.error { throw redirectError }
    guard let response = response as? HTTPURLResponse,
          (200..<300).contains(response.statusCode),
          let finalURL = response.url
    else { throw RecipeURLImportError.invalidResponse }
    guard Self.isStructurallyAllowedFetchURL(finalURL) else {
      throw RecipeURLImportError.disallowedURL
    }

    if response.expectedContentLength > Int64(maximumBytes) {
      throw RecipeURLImportError.responseTooLarge(maximumBytes: maximumBytes)
    }
    if let mediaType = response.mimeType?.lowercased(),
       mediaType != "text/html",
       mediaType != "application/xhtml+xml" {
      throw RecipeURLImportError.unsupportedContentType
    }

    let dataTask = bytes.task
    let buffer: [UInt8]
    do {
      buffer = try await Self.consumeResponseBody(
        bytes,
        expectedContentLength: response.expectedContentLength,
        maximumBytes: maximumBytes,
        onCancel: dataTask.cancel
      )
    } catch {
      // Foundation may surface cancellation as `URLError.cancelled`. Preserve
      // Swift task cancellation as `CancellationError` so application code can
      // reliably suppress a user-facing failure when the sheet disappears.
      try Task.checkCancellation()
      throw error
    }

    return FetchedRecipeDocument(
      data: Data(buffer),
      finalURL: finalURL,
      mediaType: response.mimeType,
      textEncodingName: response.textEncodingName
    )
  }
  // swiftlint:enable function_body_length

  /// Constructs a fresh, fully hardened configuration for each transport.
  /// Keeping construction separate makes the public initializer's ephemeral
  /// default independently verifiable without making a real network request.
  func makeSessionConfiguration() -> URLSessionConfiguration {
    Self.configuredSession(configurationProvider(), timeout: timeout)
  }

  /// Consumes an asynchronous byte stream without letting buffering bypass the
  /// response limit. The injected cancellation action lets tests exercise the
  /// transport-cleanup guarantee with a deterministic in-memory stream.
  static func consumeResponseBody<Bytes>(
    _ bytes: Bytes,
    expectedContentLength: Int64,
    maximumBytes: Int,
    onCancel: @escaping @Sendable () -> Void
  ) async throws -> [UInt8]
  where Bytes: AsyncSequence & Sendable, Bytes.Element == UInt8 {
    try await withTaskCancellationHandler {
      var buffer: [UInt8] = []
      if expectedContentLength > 0 {
        buffer.reserveCapacity(min(Int(expectedContentLength), maximumBytes))
      }
      for try await byte in bytes {
        // This periodic check stops promptly while consuming bytes already
        // buffered in memory without paying for a cancellation check on
        // every byte.
        if buffer.count.isMultiple(of: 4_096) { try Task.checkCancellation() }
        guard buffer.count < maximumBytes else {
          throw RecipeURLImportError.responseTooLarge(maximumBytes: maximumBytes)
        }
        buffer.append(byte)
      }
      try Task.checkCancellation()
      return buffer
    } onCancel: {
      // The response headers may already have arrived. Explicitly stop the
      // underlying task instead of merely abandoning byte iteration.
      onCancel()
    }
  }

  private static func ephemeralConfiguration() -> URLSessionConfiguration {
    .ephemeral
  }

  /// Applies the complete transport-lifetime policy to a session configuration.
  ///
  /// `timeoutIntervalForResource` is the authoritative whole-task limit. It is
  /// owned by URLSession, so it covers its DNS lookup, redirects, and streamed
  /// response rather than beginning only after a separate resolver returns.
  /// `timeoutIntervalForRequest` remains the idle-request safeguard. Disabling
  /// connectivity waiting ensures a person-initiated import fails within that
  /// same finite window instead of remaining parked for a network change.
  static func configuredSession(
    _ configuration: URLSessionConfiguration,
    timeout: TimeInterval
  ) -> URLSessionConfiguration {
    configuration.timeoutIntervalForRequest = timeout
    configuration.timeoutIntervalForResource = timeout
    configuration.waitsForConnectivity = false
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.urlCache = nil
    configuration.httpCookieStorage = nil
    configuration.urlCredentialStorage = nil
    configuration.httpShouldSetCookies = false
    configuration.httpMaximumConnectionsPerHost = 2
    return configuration
  }

  /// Builds the only request shape used for both initial loads and redirects.
  ///
  /// Redirect responses can cause Foundation to propose a request derived from
  /// the previous one. Recipe import does not need to preserve arbitrary
  /// headers, methods, or bodies across origins, so rebuilding from the target
  /// URL gives that boundary a short allowlist instead of a growing denylist.
  static func recipeRequest(for url: URL, timeout: TimeInterval) -> URLRequest {
    var request = URLRequest(
      url: url,
      cachePolicy: .reloadIgnoringLocalCacheData,
      timeoutInterval: timeout
    )
    request.httpMethod = "GET"
    request.httpShouldHandleCookies = false
    request.setValue(
      "text/html, application/xhtml+xml;q=0.9",
      forHTTPHeaderField: "Accept"
    )
    request.setValue("KitchenMemory/1", forHTTPHeaderField: "User-Agent")
    return request
  }

  /// Performs the non-network portion of the recipe-fetch destination policy.
  ///
  /// Recipe import deliberately accepts HTTPS only. An HTTP page or redirect
  /// would expose both the requested path and the returned recipe document to
  /// modification in transit. This check also rejects credentials, local
  /// names, ambiguous or literal IP spellings, and nonstandard ports. DNS and
  /// connection policy remain with URLSession so resolution observes the same
  /// cancellation and resource deadline as the request itself.
  public static func isStructurallyAllowedFetchURL(_ url: URL) -> Bool {
    isStructurallyAllowedHTTPSURL(url)
  }

  /// Whether untrusted recipe metadata may become a retained web link.
  ///
  /// This is intentionally named separately from fetch policy. Retaining a URL
  /// for later person-initiated navigation and issuing a background request are
  /// different trust boundaries, even though this release chooses the same
  /// local-destination rules for both. Source metadata may retain ordinary
  /// HTTP provenance for display and correction, but the fetcher never issues
  /// an HTTP request and the UI must revalidate a URL before activating it.
  static func isStructurallyAllowedSourceURL(_ url: URL) -> Bool {
    isStructurallyAllowedWebURL(url, allowsHTTP: true)
  }

  private static func isStructurallyAllowedHTTPSURL(_ url: URL) -> Bool {
    isStructurallyAllowedWebURL(url, allowsHTTP: false)
  }

  private static func isStructurallyAllowedWebURL(_ url: URL, allowsHTTP: Bool) -> Bool {
    guard let scheme = url.scheme?.lowercased(),
          scheme == "https" || (allowsHTTP && scheme == "http"),
          url.user == nil,
          url.password == nil,
          url.port == nil || (scheme == "https" ? url.port == 443 : url.port == 80),
          url.absoluteString.utf8.count <= 4_096,
          let rawHost = url.host?.lowercased(),
          !rawHost.isEmpty
    else { return false }

    let host = rawHost.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    guard !host.isEmpty,
          host != "localhost",
          !host.hasSuffix(".localhost"),
          !host.hasSuffix(".local"),
          !isAmbiguousNumericHost(host)
    else { return false }

    // Keep URLSession on its normal hostname/TLS path. Accepting literal IP
    // addresses adds no useful recipe-site compatibility and makes it much
    // easier for pasted metadata to target a particular local or reserved
    // endpoint.
    if isIPAddressLiteral(host) { return false }
    return host.contains(".")
  }

  private static func isAmbiguousNumericHost(_ host: String) -> Bool {
    let labels = host.split(separator: ".", omittingEmptySubsequences: false)
    guard !labels.isEmpty else { return false }
    let decimalLabelsOnly = labels.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
    if decimalLabelsOnly {
      guard labels.count == 4 else { return true }
      return labels.contains { label in
        guard let value = UInt8(label) else { return true }
        return String(value) != label
      }
    }
    return labels.allSatisfy { label in
      let isDecimal = !label.isEmpty && label.allSatisfy(\.isNumber)
      let isHexadecimal = label.lowercased().hasPrefix("0x")
        && !label.dropFirst(2).isEmpty && label.dropFirst(2).allSatisfy(\.isHexDigit)
      return isDecimal || isHexadecimal
    }
  }
}

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

private extension URLSessionRecipeDocumentLoader {
  static func isIPAddressLiteral(_ source: String) -> Bool {
    let host = source.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
    var ipv4Address = in_addr()
    if host.withCString({ inet_pton(AF_INET, $0, &ipv4Address) }) == 1 {
      return true
    }

    var ipv6Address = in6_addr()
    if host.withCString({ inet_pton(AF_INET6, $0, &ipv6Address) }) == 1 {
      return true
    }
    return false
  }
}

// swiftlint:enable file_length
