// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct FetchedRecipeDocument: Equatable, Sendable {
  public var data: Data
  public var finalURL: URL
  public var mediaType: String?
  public var textEncodingName: String?

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

public protocol RecipeDocumentLoading: Sendable {
  func load(_ url: URL) async throws -> FetchedRecipeDocument
}

public enum RecipeURLImportError: Error, Equatable, Sendable {
  case disallowedURL
  case tooManyRedirects
  case invalidResponse
  case responseTooLarge(maximumBytes: Int)
  case unsupportedContentType
  case undecodableDocument
  case tooManyCandidates(maximum: Int)
  case processingLimitExceeded
}

/// Privacy-conscious system networking for person-initiated recipe imports.
///
/// A fresh ephemeral session is used for every import. It carries no cookie or
/// cache state, streams into a bounded buffer, and never executes page scripts.
public struct URLSessionRecipeDocumentLoader: RecipeDocumentLoading, Sendable {
  public static let defaultMaximumBytes = 2 * 1_024 * 1_024

  public var maximumBytes: Int
  public var maximumRedirects: Int
  public var timeout: TimeInterval

  public init(
    maximumBytes: Int = Self.defaultMaximumBytes,
    maximumRedirects: Int = 5,
    timeout: TimeInterval = 20
  ) {
    precondition(maximumBytes > 0)
    precondition(maximumRedirects >= 0)
    precondition(timeout > 0)
    self.maximumBytes = maximumBytes
    self.maximumRedirects = maximumRedirects
    self.timeout = timeout
  }

  public func load(_ url: URL) async throws -> FetchedRecipeDocument {
    try Task.checkCancellation()
    guard Self.isStructurallyAllowedFetchURL(url) else {
      throw RecipeURLImportError.disallowedURL
    }

    let redirectController = RedirectController(
      maximumRedirects: maximumRedirects
    )
    let configuration = Self.configuredSession(
      .ephemeral,
      timeout: timeout
    )

    let session = URLSession(
      configuration: configuration,
      delegate: redirectController,
      delegateQueue: nil
    )
    defer { session.invalidateAndCancel() }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.timeoutInterval = timeout
    request.setValue(
      "text/html, application/xhtml+xml;q=0.9",
      forHTTPHeaderField: "Accept"
    )
    request.setValue("KitchenMemory/1", forHTTPHeaderField: "User-Agent")

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
       mediaType != "application/xhtml+xml"
    {
      throw RecipeURLImportError.unsupportedContentType
    }

    let dataTask = bytes.task
    let buffer: [UInt8]
    do {
      buffer = try await withTaskCancellationHandler {
        var buffer: [UInt8] = []
        if response.expectedContentLength > 0 {
          buffer.reserveCapacity(min(Int(response.expectedContentLength), maximumBytes))
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
        // `bytes(for:)` has already returned once headers arrive. Explicitly
        // cancel its underlying task so closing the import sheet also stops a
        // slow or stalled response body rather than merely abandoning iteration.
        dataTask.cancel()
      }
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
    configuration.httpShouldSetCookies = false
    configuration.httpMaximumConnectionsPerHost = 2
    return configuration
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

public struct RecipeURLImporter<Loader: RecipeDocumentLoading>: Sendable {
  private let loader: Loader
  private let importer: SchemaOrgRecipeImporter
  private let maximumCandidates: Int

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
    guard result.candidates.count <= maximumCandidates else {
      throw RecipeURLImportError.tooManyCandidates(maximum: maximumCandidates)
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

private extension URLSessionRecipeDocumentLoader {
  static func isIPAddressLiteral(_ source: String) -> Bool {
    let host = source.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
    var v4 = in_addr()
    if host.withCString({ inet_pton(AF_INET, $0, &v4) }) == 1 {
      return true
    }

    var v6 = in6_addr()
    if host.withCString({ inet_pton(AF_INET6, $0, &v6) }) == 1 {
      return true
    }
    return false
  }
}

private final class RedirectController: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  private let maximumRedirects: Int
  private let lock = NSLock()
  private var redirectCount = 0
  private var storedError: RecipeURLImportError?

  init(maximumRedirects: Int) {
    self.maximumRedirects = maximumRedirects
  }

  var error: RecipeURLImportError? {
    lock.withLock { storedError }
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    let shouldFollow = lock.withLock {
      redirectCount += 1
      guard redirectCount <= maximumRedirects else {
        storedError = .tooManyRedirects
        return false
      }
      // A redirect is a new network destination, not merely part of the first
      // URL. Validate it before handing it back to URLSession; approving first
      // and inspecting only the final response would allow an intermediate GET
      // to reach a private service. This delegate runs on URLSession's operation
      // queue, but the validation itself is deliberately pure string/URL work;
      // URLSession retains ownership of cancellable system DNS.
      guard let url = request.url,
            URLSessionRecipeDocumentLoader.isStructurallyAllowedFetchURL(url)
      else {
        storedError = .disallowedURL
        return false
      }
      if task.currentRequest?.url?.scheme?.lowercased() == "https",
         url.scheme?.lowercased() != "https"
      {
        storedError = .disallowedURL
        return false
      }
      return true
    }
    completionHandler(shouldFollow ? request : nil)
  }
}
