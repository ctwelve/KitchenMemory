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

  func testURLPolicyRejectsLocalAndCredentialBearingDestinations() {
    let rejected = [
      "file:///tmp/recipe.html",
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
      "https://localhost./recipe",
      "https://example.com:8443/recipe",
    ]

    for value in rejected {
      XCTAssertFalse(
        URLSessionRecipeDocumentLoader.isStructurallyAllowed(URL(string: value)!),
        value
      )
    }
    XCTAssertTrue(URLSessionRecipeDocumentLoader.isStructurallyAllowed(
      URL(string: "https://recipes.example.com/toast")!
    ))
  }

  func testRejectsPublicHostnameWhenAnyResolvedAddressIsNotPublic() async {
    let loader = URLSessionRecipeDocumentLoader(hostResolver: StubHostResolver(addresses: [
      IPAddress("93.184.216.34")!,
      IPAddress("192.168.1.20")!,
    ]))

    do {
      _ = try await loader.load(URL(string: "https://recipes.example.com/toast")!)
      XCTFail("Expected private DNS result to be rejected before fetching")
    } catch {
      XCTAssertEqual(error as? RecipeURLImportError, .disallowedURL)
    }
  }

  func testIPAddressPolicyRejectsNonGlobalNetworks() {
    let rejected = [
      "0.0.0.0", "100.64.0.1", "169.254.169.254", "192.0.2.1",
      "198.18.0.1", "198.51.100.1", "203.0.113.1", "224.0.0.1",
      "::1", "::ffff:8.8.8.8", "2001:db8::1", "fc00::1", "fe80::1",
    ]
    for address in rejected {
      XCTAssertFalse(IPAddress(address)!.isPublic, address)
    }
    XCTAssertTrue(IPAddress("93.184.216.34")!.isPublic)
    XCTAssertTrue(IPAddress("2606:2800:220:1:248:1893:25c8:1946")!.isPublic)
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

private struct StubHostResolver: RecipeHostResolving {
  var addresses: [IPAddress]

  func resolve(_ host: String) throws -> [IPAddress] {
    addresses
  }
}

private struct StubLoader: RecipeDocumentLoading {
  var document: FetchedRecipeDocument

  func load(_ url: URL) async throws -> FetchedRecipeDocument {
    document
  }
}
