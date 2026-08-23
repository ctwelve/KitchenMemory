// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
@testable import KitchenMemoryImport
import XCTest

final class RecipeURLImporterBoundaryTests: XCTestCase {
  func testDeclaredLegacyEncodingAliasesDecodeDeterministically() async throws {
    let finalURL = try XCTUnwrap(URL(string: "https://publisher.example/recipe"))
    let cases = [
      EncodingCase(name: "iso-8859-1", encoding: .isoLatin1, title: "Crème"),
      EncodingCase(name: "latin1", encoding: .isoLatin1, title: "Crème"),
      EncodingCase(name: "windows-1252", encoding: .windowsCP1252, title: "€ toast"),
      EncodingCase(name: "cp1252", encoding: .windowsCP1252, title: "€ toast"),
      EncodingCase(name: "utf-16", encoding: .utf16, title: "Crème 🍲"),
    ]

    for encodingCase in cases {
      let html = #"<script type="application/ld+json">{"@type":"Recipe","name":"\#(encodingCase.title)"}</script>"#
      let loader = BoundaryStubLoader(document: .init(
        data: try XCTUnwrap(html.data(using: encodingCase.encoding)),
        finalURL: finalURL,
        textEncodingName: encodingCase.name.uppercased()
      ))

      let result = try await RecipeURLImporter(loader: loader).importRecipe(from: finalURL)
      XCTAssertEqual(
        result.unambiguousCandidate?.draft.title,
        encodingCase.title,
        encodingCase.name
      )
    }
  }

  func testUnknownOrMissingEncodingNameUsesUTF8() async throws {
    let url = try XCTUnwrap(URL(string: "https://publisher.example/recipe"))
    let html = #"<script type="application/ld+json">{"@type":"Recipe","name":"Soup 🍲"}</script>"#

    for name in [nil, "x-future-utf8"] as [String?] {
      let loader = BoundaryStubLoader(document: .init(
        data: Data(html.utf8),
        finalURL: url,
        textEncodingName: name
      ))
      let result = try await RecipeURLImporter(loader: loader).importRecipe(from: url)
      XCTAssertEqual(result.unambiguousCandidate?.draft.title, "Soup 🍲")
    }
  }

  func testNonCandidateProcessingLimitsBecomeTheGenericURLImportError() async throws {
    let url = try XCTUnwrap(URL(string: "https://publisher.example/recipe"))
    let html = #"""
      <script type="application/ld+json">{ malformed </script>
      <script type="application/ld+json">
      {"@type":"Recipe","name":"Deep","future":[[[[0]]]]}
      </script>
      """#
    let data = Data(html.utf8)
    let loader = BoundaryStubLoader(document: .init(data: data, finalURL: url))
    let parser = SchemaOrgRecipeImporter(limits: .init(maximumJSONDepth: 1))

    await assertImportError(.processingLimitExceeded) {
      try await RecipeURLImporter(loader: loader, importer: parser).importRecipe(from: url)
    }
  }

  func testLoaderErrorsPropagateWithoutBeingReclassified() async {
    let url = URL(string: "https://publisher.example/recipe")!
    let importer = RecipeURLImporter(loader: FailingBoundaryLoader())

    do {
      _ = try await importer.importRecipe(from: url)
      XCTFail("Expected loader failure")
    } catch {
      XCTAssertEqual(error as? BoundaryLoaderError, .offline)
    }
  }

  func testURLLengthBoundaryIsInclusive() {
    let prefix = "https://recipes.example/"
    let exact = URL(string: prefix + String(repeating: "a", count: 4_096 - prefix.utf8.count))!
    let excessive = URL(string: exact.absoluteString + "a")!

    XCTAssertEqual(exact.absoluteString.utf8.count, 4_096)
    XCTAssertTrue(URLSessionRecipeDocumentLoader.isStructurallyAllowedFetchURL(exact))
    XCTAssertFalse(URLSessionRecipeDocumentLoader.isStructurallyAllowedFetchURL(excessive))
  }

  func testFetchPolicyExercisesPortsTrailingDotsAndNumericHostSpellings() throws {
    let accepted = [
      "https://recipes.example:443/path",
      "https://recipes.example./path",
    ]
    let rejected = [
      "https://recipes.example:80/path",
      "https://127.0.0.1/path",
      "https://[::1]/path",
      "https://[2001:db8::1]/path",
      "https://2130706433/path",
      "https://0177.0.0.1/path",
      "https://0x7f.0x0.0x0.0x1/path",
      "https://1.2.3.999/path",
    ]

    for source in accepted {
      let url = try XCTUnwrap(URL(string: source), source)
      XCTAssertTrue(URLSessionRecipeDocumentLoader.isStructurallyAllowedFetchURL(url), source)
    }
    for source in rejected {
      let url = try XCTUnwrap(URL(string: source), source)
      XCTAssertFalse(URLSessionRecipeDocumentLoader.isStructurallyAllowedFetchURL(url), source)
    }
  }

  func testSeededPublicHostCorpusStaysWithinStructuralPolicy() throws {
    let seed = try PropertyTestSeeds.bundled().seed(named: .importURLPublicHosts)
    var generator = SeededGenerator(seed: seed.value)
    for caseIndex in 0..<256 {
      let label = generator.int(in: 0...999_999)
      let path = generator.int(in: 0...999_999)
      let source = "https://r\(label).recipes.example/p/\(path)"
      let url = URL(string: source)!
      let context = "seed=\(seed.hexadecimal) case=\(caseIndex) source=\(source)"

      XCTAssertTrue(URLSessionRecipeDocumentLoader.isStructurallyAllowedFetchURL(url), context)
      XCTAssertFalse(URLSessionRecipeDocumentLoader.isStructurallyAllowedFetchURL(
        URL(string: "https://person:secret@r\(label).recipes.example/p/\(path)")!
      ), context)
      XCTAssertFalse(URLSessionRecipeDocumentLoader.isStructurallyAllowedFetchURL(
        URL(string: "https://r\(label).local/p/\(path)")!
      ), context)
    }
  }

  private func assertImportError(
    _ expected: RecipeURLImportError,
    operation: () async throws -> RecipeImportResult,
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

private struct EncodingCase {
  let name: String
  let encoding: String.Encoding
  let title: String
}

private struct BoundaryStubLoader: RecipeDocumentLoading {
  let document: FetchedRecipeDocument

  func load(_ url: URL) async throws -> FetchedRecipeDocument {
    document
  }
}

private enum BoundaryLoaderError: Error {
  case offline
}

private struct FailingBoundaryLoader: RecipeDocumentLoading {
  func load(_ url: URL) async throws -> FetchedRecipeDocument {
    throw BoundaryLoaderError.offline
  }
}
