// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
@testable import KitchenMemoryImport
import XCTest

final class URLSessionRecipeDocumentLoaderTests: XCTestCase {
  func testLoadsAnAllowedBoundedHTMLResponse() async throws {
    let loader = testLoader(maximumBytes: 1_024)

    let document = try await loader.load(transportURL("success"))

    XCTAssertEqual(String(data: document.data, encoding: .utf8), RecipeLoaderURLProtocol.html)
    XCTAssertEqual(document.finalURL, transportURL("success"))
    XCTAssertEqual(document.mediaType, "text/html")
    XCTAssertEqual(document.textEncodingName, "utf-8")
  }

  func testRejectsDisallowedInputBeforeCreatingANetworkRequest() async {
    await assertLoadError(.disallowedURL) {
      try await URLSessionRecipeDocumentLoader().load(
        URL(string: "http://transport.example/insecure")!
      )
    }
  }

  func testRejectsInvalidStatusAndUnsupportedContentType() async {
    await assertLoadError(.invalidResponse) {
      try await self.testLoader().load(self.transportURL("status"))
    }
    await assertLoadError(.unsupportedContentType) {
      try await self.testLoader().load(self.transportURL("media-type"))
    }
    await assertLoadError(.disallowedURL) {
      try await self.testLoader().load(self.transportURL("disallowed-final"))
    }
  }

  func testAcceptsExactAndRejectsExcessiveDeclaredAndStreamedBodies() async throws {
    let exactData = Data("1234".utf8)
    for path in ["declared-exact-limit", "streamed-exact-limit"] {
      let document = try await testLoader(maximumBytes: 4).load(transportURL(path))
      XCTAssertEqual(document.data, exactData, path)
    }

    await assertLoadError(.responseTooLarge(maximumBytes: 4)) {
      try await self.testLoader(maximumBytes: 4).load(
        self.transportURL("declared-too-large")
      )
    }
    await assertLoadError(.responseTooLarge(maximumBytes: 4)) {
      try await self.testLoader(maximumBytes: 4).load(
        self.transportURL("streamed-too-large")
      )
    }
  }

  func testTransportErrorsAndPreexistingCancellationPropagate() async {
    do {
      _ = try await testLoader().load(transportURL("transport-error"))
      XCTFail("Expected transport error")
    } catch {
      XCTAssertEqual((error as? URLError)?.code, .cannotConnectToHost)
    }

    let successURL = transportURL("success")
    let task = Task {
      try await URLSessionRecipeDocumentLoader().load(successURL)
    }
    task.cancel()
    do {
      _ = try await task.value
      XCTFail("Expected cancellation")
    } catch {
      XCTAssertTrue(error is CancellationError)
    }
  }

  private func transportURL(_ path: String) -> URL {
    URL(string: "https://transport.example/\(path)")!
  }

  private func testLoader(
    maximumBytes: Int = URLSessionRecipeDocumentLoader.defaultMaximumBytes
  ) -> URLSessionRecipeDocumentLoader {
    URLSessionRecipeDocumentLoader(
      maximumBytes: maximumBytes,
      configurationProvider: RecipeLoaderURLProtocol.configuration
    )
  }

  private func assertLoadError(
    _ expected: RecipeURLImportError,
    operation: () async throws -> FetchedRecipeDocument,
    file: StaticString = #filePath,
    line: UInt = #line
  ) async {
    do {
      _ = try await operation()
      XCTFail("Expected \(expected)", file: file, line: line)
    } catch {
      XCTAssertEqual(error as? RecipeURLImportError, expected, file: file, line: line)
    }
  }
}

private final class RecipeLoaderURLProtocol: URLProtocol, @unchecked Sendable {
  static let html = "<html><body>recipe</body></html>"

  static func configuration() -> URLSessionConfiguration {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [RecipeLoaderURLProtocol.self]
    return configuration
  }

  // URLProtocol declares these as overridable class methods, so `static` is not
  // available even though this test double is final.
  // swiftlint:disable:next static_over_final_class
  override class func canInit(with request: URLRequest) -> Bool {
    request.url?.host == "transport.example"
  }

  // swiftlint:disable:next static_over_final_class
  override class func canonicalRequest(for request: URLRequest) -> URLRequest {
    request
  }

  override func startLoading() {
    guard let url = request.url else {
      client?.urlProtocol(self, didFailWithError: URLError(.badURL))
      return
    }
    if url.path == "/transport-error" {
      client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
      return
    }

    let statusCode = url.path == "/status" ? 503 : 200
    let contentType = url.path == "/media-type"
      ? "application/json"
      : "text/html; charset=utf-8"
    var headers = ["Content-Type": contentType]
    if url.path == "/declared-too-large" {
      headers["Content-Length"] = "5"
    } else if url.path == "/declared-exact-limit" {
      headers["Content-Length"] = "4"
    } else if url.path == "/success" {
      headers["Content-Length"] = String(Self.html.utf8.count)
    }
    let responseURL = url.path == "/disallowed-final"
      ? URL(string: "http://transport.example/disallowed-final")!
      : url
    guard let response = HTTPURLResponse(
      url: responseURL,
      statusCode: statusCode,
      httpVersion: "HTTP/1.1",
      headerFields: headers
    ) else {
      client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
      return
    }

    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    let data: Data
    if url.path == "/declared-too-large" || url.path == "/streamed-too-large" {
      data = Data("12345".utf8)
    } else if url.path == "/declared-exact-limit" || url.path == "/streamed-exact-limit" {
      data = Data("1234".utf8)
    } else {
      data = Data(Self.html.utf8)
    }
    client?.urlProtocol(self, didLoad: data)
    client?.urlProtocolDidFinishLoading(self)
  }

  override func stopLoading() {}
}
