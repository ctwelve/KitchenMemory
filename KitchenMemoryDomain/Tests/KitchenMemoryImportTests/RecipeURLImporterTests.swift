// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
@testable import KitchenMemoryImport
import XCTest

final class RecipeURLImporterTests: XCTestCase {
  func testImportsFetchedHTMLUsingTheFinalRedirectURL() async throws {
    let finalURL = try XCTUnwrap(URL(string: "https://publisher.example/recipes/toast"))
    let html = """
      <script type="application/ld+json">
      {"@type":"Recipe","name":"Toast","recipeIngredient":["1 slice bread"]}
      </script>
      """
    let loader = StubLoader(document: FetchedRecipeDocument(
      data: Data(html.utf8),
      finalURL: finalURL,
      mediaType: "text/html",
      textEncodingName: "utf-8"
    ))

    let result = try await RecipeURLImporter(loader: loader).importRecipe(
      from: URL(string: "https://short.example/t")!
    )

    XCTAssertEqual(result.unambiguousCandidate?.draft.title, "Toast")
    XCTAssertEqual(result.unambiguousCandidate?.snapshot.documentURL, finalURL)
  }

  func testLegacyEncodedHTMLCapturesAUTF8JSONLDTranscription() async throws {
    let json = #"{"@type":"Recipe","name":"Crème brûlée","future":"mañana"}"#
    let html = "<script type=\"application/ld+json\">\(json)</script>"
    let loader = StubLoader(document: FetchedRecipeDocument(
      data: try XCTUnwrap(html.data(using: .isoLatin1)),
      finalURL: URL(string: "https://example.com/recipe")!,
      mediaType: "text/html",
      textEncodingName: "iso-8859-1"
    ))

    let result = try await RecipeURLImporter(loader: loader).importRecipe(
      from: URL(string: "https://example.com/recipe")!
    )
    let snapshot = try XCTUnwrap(result.unambiguousCandidate?.snapshot)

    XCTAssertEqual(snapshot.jsonLD, Data(json.utf8))
    XCTAssertNotEqual(snapshot.jsonLD, try XCTUnwrap(json.data(using: .isoLatin1)))
  }

  func testURLPolicyRejectsLocalAndCredentialBearingDestinations() {
    let rejected = [
      "file:///tmp/recipe.html",
      "http://example.com/recipe",
      "http://localhost/recipe",
      "http://router.local/recipe",
      "http://127.0.0.1/recipe",
      "http://127.1/recipe",
      "http://[::ffff:127.0.0.1]/recipe",
      "http://0177.0.0.1/recipe",
      "http://0x7f.0.0.1/recipe",
      "http://10.0.0.4/recipe",
      "http://172.20.1.2/recipe",
      "http://192.168.1.1/recipe",
      "https://person:secret@example.com/recipe",
      "https://intranet/recipe",
      "https://93.184.216.34/recipe",
      "https://localhost./recipe",
      "https://example.com:8443/recipe",
    ]

    for value in rejected {
      XCTAssertFalse(
        URLSessionRecipeDocumentLoader.isStructurallyAllowedFetchURL(URL(string: value)!),
        value
      )
    }
    XCTAssertTrue(URLSessionRecipeDocumentLoader.isStructurallyAllowedFetchURL(
      URL(string: "https://recipes.example.com/toast")!
    ))
  }

  func testFetchAndRetainedSourcePoliciesAreDeliberatelySeparate() {
    let legacySource = URL(string: "http://publisher.example/recipe")!

    XCTAssertFalse(
      URLSessionRecipeDocumentLoader.isStructurallyAllowedFetchURL(legacySource)
    )
    XCTAssertTrue(
      URLSessionRecipeDocumentLoader.isStructurallyAllowedSourceURL(legacySource)
    )
  }

  func testURLPolicyRejectsImplausiblyLongInput() {
    let oversized = URL(
      string: "https://example.com/" + String(repeating: "a", count: 4_096)
    )!

    XCTAssertFalse(URLSessionRecipeDocumentLoader.isStructurallyAllowedFetchURL(oversized))
  }

  func testSessionConfigurationOwnsTheFiniteRequestLifetime() {
    let timeout: TimeInterval = 7
    let configuration = URLSessionRecipeDocumentLoader.configuredSession(
      .default,
      timeout: timeout
    )

    XCTAssertEqual(configuration.timeoutIntervalForRequest, timeout)
    XCTAssertEqual(configuration.timeoutIntervalForResource, timeout)
    XCTAssertFalse(configuration.waitsForConnectivity)
    XCTAssertEqual(configuration.requestCachePolicy, .reloadIgnoringLocalCacheData)
    XCTAssertNil(configuration.urlCache)
    XCTAssertNil(configuration.httpCookieStorage)
    XCTAssertFalse(configuration.httpShouldSetCookies)
  }

  func testInvalidTextEncodingFailsWithoutAttemptingFallbackInterpretation() async {
    let loader = StubLoader(document: FetchedRecipeDocument(
      data: Data([0xFF, 0xFE, 0xFD]),
      finalURL: URL(string: "https://example.com/recipe")!,
      textEncodingName: "utf-8"
    ))

    do {
      _ = try await RecipeURLImporter(loader: loader).importRecipe(
        from: URL(string: "https://example.com/recipe")!
      )
      XCTFail("Expected undecodableDocument")
    } catch {
      XCTAssertEqual(error as? RecipeURLImportError, .undecodableDocument)
    }
  }

  func testCapsCandidateFanOutAfterParsingABoundedDocument() async {
    let recipes = (1...3).map { #"{"@type":"Recipe","name":"Recipe \#($0)"}"# }
      .joined(separator: ",")
    let html = "<script type=\"application/ld+json\">[\(recipes)]</script>"
    let loader = StubLoader(document: FetchedRecipeDocument(
      data: Data(html.utf8),
      finalURL: URL(string: "https://example.com/recipes")!
    ))

    do {
      _ = try await RecipeURLImporter(loader: loader, maximumCandidates: 2)
        .importRecipe(from: URL(string: "https://example.com/recipes")!)
      XCTFail("Expected candidate cap")
    } catch {
      XCTAssertEqual(error as? RecipeURLImportError, .tooManyCandidates(maximum: 2))
    }
  }
}

private struct StubLoader: RecipeDocumentLoading {
  var document: FetchedRecipeDocument

  func load(_ url: URL) async throws -> FetchedRecipeDocument {
    document
  }
}
