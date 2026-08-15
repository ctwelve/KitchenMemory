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
  private let hostResolver: any RecipeHostResolving

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
    hostResolver = SystemRecipeHostResolver()
  }

  init(
    maximumBytes: Int = Self.defaultMaximumBytes,
    maximumRedirects: Int = 5,
    timeout: TimeInterval = 20,
    hostResolver: any RecipeHostResolving
  ) {
    precondition(maximumBytes > 0)
    precondition(maximumRedirects >= 0)
    precondition(timeout > 0)
    self.maximumBytes = maximumBytes
    self.maximumRedirects = maximumRedirects
    self.timeout = timeout
    self.hostResolver = hostResolver
  }

  public func load(_ url: URL) async throws -> FetchedRecipeDocument {
    try await validateDestination(url)

    let redirectController = RedirectController(
      maximumRedirects: maximumRedirects,
      hostResolver: hostResolver
    )
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = timeout
    configuration.timeoutIntervalForResource = timeout
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    configuration.urlCache = nil
    configuration.httpCookieStorage = nil
    configuration.httpShouldSetCookies = false
    configuration.httpMaximumConnectionsPerHost = 2

    let session = URLSession(
      configuration: configuration,
      delegate: redirectController,
      delegateQueue: nil
    )
    defer { session.invalidateAndCancel() }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue(
      "text/html, application/xhtml+xml;q=0.9",
      forHTTPHeaderField: "Accept"
    )
    request.setValue("KitchenMemory/1", forHTTPHeaderField: "User-Agent")

    let (bytes, response) = try await session.bytes(for: request)
    if let redirectError = redirectController.error { throw redirectError }
    guard let response = response as? HTTPURLResponse,
          (200..<300).contains(response.statusCode),
          let finalURL = response.url
    else { throw RecipeURLImportError.invalidResponse }
    try await validateDestination(finalURL)

    if response.expectedContentLength > Int64(maximumBytes) {
      throw RecipeURLImportError.responseTooLarge(maximumBytes: maximumBytes)
    }
    if let mediaType = response.mimeType?.lowercased(),
       mediaType != "text/html",
       mediaType != "application/xhtml+xml"
    {
      throw RecipeURLImportError.unsupportedContentType
    }

    var buffer: [UInt8] = []
    if response.expectedContentLength > 0 {
      buffer.reserveCapacity(min(Int(response.expectedContentLength), maximumBytes))
    }
    for try await byte in bytes {
      guard buffer.count < maximumBytes else {
        throw RecipeURLImportError.responseTooLarge(maximumBytes: maximumBytes)
      }
      buffer.append(byte)
    }

    return FetchedRecipeDocument(
      data: Data(buffer),
      finalURL: finalURL,
      mediaType: response.mimeType,
      textEncodingName: response.textEncodingName
    )
  }

  /// Performs the non-network portion of the recipe-fetch destination policy.
  ///
  /// Recipe import deliberately accepts HTTPS only. An HTTP page or redirect
  /// would expose both the requested path and the returned recipe document to
  /// modification in transit. This check also rejects credentials, local
  /// names, ambiguous IP spellings, and nonstandard ports. A caller that will
  /// perform a request must additionally resolve the hostname and validate
  /// every returned IP address; a public-looking hostname can still resolve to
  /// a private host.
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
          !host.isEmpty,
          host != "localhost",
          !host.hasSuffix(".localhost"),
          !host.hasSuffix(".local"),
          !isAmbiguousNumericHost(host)
    else { return false }

    // Keep URLSession on its normal hostname/TLS path. Accepting literal IP
    // addresses adds no useful recipe-site compatibility and makes it much
    // easier for pasted metadata to target a particular local or reserved
    // endpoint.
    if IPAddress(host) != nil { return false }
    return host.contains(".")
  }

  private func validateDestination(_ url: URL) async throws {
    guard Self.isStructurallyAllowedFetchURL(url), let host = url.host else {
      throw RecipeURLImportError.disallowedURL
    }
    if IPAddress(host) != nil { return }

    // DNS APIs are synchronous. Keeping resolution off the caller's actor is
    // important because imports begin from a SwiftUI task on the main actor.
    let resolver = hostResolver
    let addresses = try await Task.detached(priority: .userInitiated) {
      try resolver.resolve(host)
    }.value
    guard !addresses.isEmpty, addresses.allSatisfy(\.isPublic) else {
      throw RecipeURLImportError.disallowedURL
    }
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

protocol RecipeHostResolving: Sendable {
  func resolve(_ host: String) throws -> [IPAddress]
}

struct SystemRecipeHostResolver: RecipeHostResolving {
  func resolve(_ host: String) throws -> [IPAddress] {
    var hints = addrinfo()
    hints.ai_family = AF_UNSPEC
    hints.ai_socktype = SOCK_STREAM
    hints.ai_protocol = IPPROTO_TCP

    var firstResult: UnsafeMutablePointer<addrinfo>?
    let status = getaddrinfo(host, nil, &hints, &firstResult)
    guard status == 0 else { throw URLError(.cannotFindHost) }
    defer { if let firstResult { freeaddrinfo(firstResult) } }

    var addresses: [IPAddress] = []
    var cursor = firstResult
    while let result = cursor?.pointee {
      if let address = IPAddress(result) { addresses.append(address) }
      cursor = result.ai_next
    }
    return Array(Set(addresses))
  }
}

struct IPAddress: Hashable, Sendable {
  enum Family: Hashable, Sendable {
    case v4
    case v6
  }

  let family: Family
  let bytes: [UInt8]

  init?(_ source: String) {
    let host = source.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
    var v4 = in_addr()
    if host.withCString({ inet_pton(AF_INET, $0, &v4) }) == 1 {
      family = .v4
      bytes = withUnsafeBytes(of: v4) { Array($0) }
      return
    }

    var v6 = in6_addr()
    if host.withCString({ inet_pton(AF_INET6, $0, &v6) }) == 1 {
      family = .v6
      bytes = withUnsafeBytes(of: v6) { Array($0) }
      return
    }
    return nil
  }

  init?(_ result: addrinfo) {
    guard let socketAddress = result.ai_addr else { return nil }
    switch result.ai_family {
    case AF_INET:
      let address = socketAddress.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
        $0.pointee.sin_addr
      }
      family = .v4
      bytes = withUnsafeBytes(of: address) { Array($0) }
    case AF_INET6:
      let address = socketAddress.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) {
        $0.pointee.sin6_addr
      }
      family = .v6
      bytes = withUnsafeBytes(of: address) { Array($0) }
    default:
      return nil
    }
  }

  /// Whether this address is suitable for an arbitrary public-web request.
  ///
  /// "Public" is intentionally narrower than "not RFC 1918." Loopback,
  /// link-local, carrier-grade NAT, documentation, benchmarking, multicast,
  /// reserved, and IPv4-mapped IPv6 addresses are all rejected. Recipe import
  /// has no reason to contact any of those networks.
  var isPublic: Bool {
    switch family {
    case .v4: isPublicIPv4
    case .v6: isPublicIPv6
    }
  }

  private var isPublicIPv4: Bool {
    guard bytes.count == 4 else { return false }
    let first = bytes[0]
    let second = bytes[1]
    switch (first, second) {
    case (0, _), (10, _), (127, _): return false
    case (100, 64...127): return false
    case (169, 254): return false
    case (172, 16...31): return false
    case (192, 0), (192, 168): return false
    case (192, 88) where bytes[2] == 99: return false
    case (192, 0) where bytes[2] == 2: return false
    case (198, 18...19): return false
    case (198, 51) where bytes[2] == 100: return false
    case (203, 0) where bytes[2] == 113: return false
    case (224...255, _): return false
    default: return true
    }
  }

  private var isPublicIPv6: Bool {
    guard bytes.count == 16 else { return false }
    // IPv4-mapped addresses need IPv4 policy, not an IPv6 prefix shortcut.
    if bytes.prefix(10).allSatisfy({ $0 == 0 }), bytes[10] == 0xFF, bytes[11] == 0xFF {
      return false
    }
    // Global unicast currently occupies 2000::/3. Explicitly remove ranges
    // within it that are reserved for documentation or benchmarking.
    guard bytes[0] & 0xE0 == 0x20 else { return false }
    if Array(bytes[0...3]) == [0x20, 0x01, 0x0D, 0xB8] { return false }
    if Array(bytes[0...5]) == [0x20, 0x01, 0x00, 0x02, 0x00, 0x00] { return false }
    return true
  }
}

private final class RedirectController: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  private let maximumRedirects: Int
  private let hostResolver: any RecipeHostResolving
  private let lock = NSLock()
  private var redirectCount = 0
  private var storedError: RecipeURLImportError?

  init(maximumRedirects: Int, hostResolver: any RecipeHostResolving) {
    self.maximumRedirects = maximumRedirects
    self.hostResolver = hostResolver
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
      // queue, so synchronous system DNS resolution does not block SwiftUI.
      guard let url = request.url,
            URLSessionRecipeDocumentLoader.isStructurallyAllowedFetchURL(url),
            Self.resolvesOnlyToPublicAddresses(url, using: hostResolver)
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

  private static func resolvesOnlyToPublicAddresses(
    _ url: URL,
    using resolver: any RecipeHostResolving
  ) -> Bool {
    guard let host = url.host else { return false }
    if IPAddress(host) != nil { return true }
    guard let addresses = try? resolver.resolve(host), !addresses.isEmpty else { return false }
    return addresses.allSatisfy(\.isPublic)
  }
}
