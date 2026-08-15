// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
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
    guard Self.isAllowed(url) else { throw RecipeURLImportError.disallowedURL }

    let redirectController = RedirectController(maximumRedirects: maximumRedirects)
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
          let finalURL = response.url,
          Self.isAllowed(finalURL)
    else { throw RecipeURLImportError.invalidResponse }

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

  public static func isAllowed(_ url: URL) -> Bool {
    guard let scheme = url.scheme?.lowercased(),
          scheme == "http" || scheme == "https",
          url.user == nil,
          url.password == nil,
          let host = url.host?.lowercased(),
          !host.isEmpty,
          host.contains("."),
          host != "localhost",
          !host.hasSuffix(".localhost"),
          !host.hasSuffix(".local"),
          !isMalformedNumericHost(host),
          !isPrivateIPv4(host),
          !isPrivateIPv6(host)
    else { return false }
    return true
  }

  private static func isPrivateIPv4(_ host: String) -> Bool {
    let parts = host.split(separator: ".").compactMap { UInt8($0) }
    guard parts.count == 4 else { return false }
    switch (parts[0], parts[1]) {
    case (10, _), (127, _), (0, _): return true
    case (169, 254): return true
    case (172, 16...31): return true
    case (192, 168): return true
    default: return false
    }
  }

  private static func isMalformedNumericHost(_ host: String) -> Bool {
    let numericCharacters = CharacterSet(charactersIn: "0123456789.")
    guard host.unicodeScalars.allSatisfy(numericCharacters.contains) else { return false }
    let parts = host.split(separator: ".", omittingEmptySubsequences: false)
    return parts.count != 4 || parts.contains { UInt8($0) == nil }
  }

  private static func isPrivateIPv6(_ host: String) -> Bool {
    let normalized = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]")).lowercased()
    return normalized == "::1"
      || normalized.hasPrefix("fc")
      || normalized.hasPrefix("fd")
      || normalized.hasPrefix("fe8")
      || normalized.hasPrefix("fe9")
      || normalized.hasPrefix("fea")
      || normalized.hasPrefix("feb")
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
    self.importer = importer
    self.maximumCandidates = maximumCandidates
  }

  public func importRecipe(from url: URL) async throws -> RecipeImportResult {
    let document = try await loader.load(url)
    guard let html = Self.decode(document) else {
      throw RecipeURLImportError.undecodableDocument
    }
    let result = importer.importHTML(html, documentURL: document.finalURL)
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
      guard let url = request.url, URLSessionRecipeDocumentLoader.isAllowed(url) else {
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
