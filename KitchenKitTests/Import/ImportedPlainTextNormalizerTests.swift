// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import XCTest

final class ImportedPlainTextNormalizerTests: XCTestCase {
  func testCommentsAreRemovedWhetherClosedOrTruncated() {
    XCTAssertEqual(
      ImportedPlainTextNormalizer.normalize("before<!-- hidden -->after"),
      "before after"
    )
    XCTAssertEqual(
      ImportedPlainTextNormalizer.normalize("before<!-- never closes"),
      "before"
    )
    XCTAssertEqual(
      ImportedPlainTextNormalizer.normalize("<!-- only a comment -->"),
      ""
    )
  }

  func testRawTextElementsIgnoreFalseClosersAndCase() {
    let source = "before<script>DROP</scripture>still drop</ScRiPt/>after"
    XCTAssertEqual(ImportedPlainTextNormalizer.normalize(source), "before after")

    XCTAssertEqual(
      ImportedPlainTextNormalizer.normalize("one<STYLE>DROP</style >two"),
      "one two"
    )
    XCTAssertEqual(
      ImportedPlainTextNormalizer.normalize("one<script>never closes"),
      "one"
    )
  }

  func testTagsAndSupportedEntitiesBecomeOrdinaryPlainText() {
    let source = "  A&nbsp;<b data-value='>'>B</b>&amp;&lt;&gt;&quot;&#39;  "
    XCTAssertEqual(ImportedPlainTextNormalizer.normalize(source), "A B & \"'")

    XCTAssertEqual(ImportedPlainTextNormalizer.normalize("alpha<>beta"), "alpha beta")
    XCTAssertEqual(ImportedPlainTextNormalizer.normalize("</b>after"), "after")
    XCTAssertEqual(ImportedPlainTextNormalizer.normalize("one<broken"), "one")
  }

  func testEntityDecodingIsExactlyOneLayerAndCaseSensitive() {
    XCTAssertEqual(ImportedPlainTextNormalizer.normalize("&amp;lt;b&amp;gt;"), "&lt;b&gt;")
    XCTAssertEqual(ImportedPlainTextNormalizer.normalize("&AMP; &unknown;"), "&AMP; &unknown;")
  }

  func testSeededMarkupCorpusPreservesNormalizerInvariants() throws {
    // This bounded corpus combines valid and malformed fragments. A fixed seed
    // and recorded source make every property failure exactly reproducible.
    let fragments = [
      "alpha", " beta", "\t", "\n", "&amp;", "&nbsp;", "<b>", "</b>",
      "<!-- comment -->", "<!-- truncated", "<script>DROP_SCRIPT</script>",
      "<style>DROP_STYLE</style>", "<tag data='>'>", "<", "😀",
    ]
    let seed = try PropertyTestSeeds.bundled().seed(named: .importNormalizerMarkup)
    var generator = SeededGenerator(seed: seed.value)

    for caseIndex in 0..<256 {
      let count = generator.int(in: 0...24)
      let source = (0..<count).map { _ in
        fragments[generator.int(in: 0...(fragments.count - 1))]
      }.joined()
      let normalized = ImportedPlainTextNormalizer.normalize(source)
      let context = "seed=\(seed.hexadecimal) case=\(caseIndex) source=\(source)"
      let scriptSentinel = "GENERATED_SCRIPT_PAYLOAD_\(caseIndex)"
      let styleSentinel = "GENERATED_STYLE_PAYLOAD_\(caseIndex)"
      let suppressed = ImportedPlainTextNormalizer.normalize(
        "<script>\(scriptSentinel)</script><style>\(styleSentinel)</style>\(source)"
      )

      // Put each unique payload inside a well-formed raw-text element. Arbitrary
      // malformed fragments remain in `source`, but cannot redefine what text
      // was semantically script/style content for this property.
      XCTAssertFalse(suppressed.contains(scriptSentinel), context)
      XCTAssertFalse(suppressed.contains(styleSentinel), context)
      XCTAssertLessThanOrEqual(normalized.utf8.count, source.utf8.count, context)
      XCTAssertFalse(normalized.hasPrefix(" "), context)
      XCTAssertFalse(normalized.hasSuffix(" "), context)
      XCTAssertFalse(normalized.contains("  "), context)
      XCTAssertFalse(normalized.contains("\n"), context)
      XCTAssertFalse(normalized.contains("\t"), context)
    }
  }
}
