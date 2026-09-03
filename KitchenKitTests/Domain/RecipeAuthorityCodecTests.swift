// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import XCTest

final class RecipeAuthorityCodecTests: XCTestCase {
  func testIdentifierSetFormatOneHasStableRawByteOrdering() throws {
    let later = UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!
    let earlier = UUID(uuidString: "00010203-0405-0607-0809-0a0b0c0d0e0f")!

    let encoded = RecipeIdentifierSetCodec.encode([later, earlier])

    XCTAssertEqual(encoded.formatVersion, 1)
    XCTAssertEqual(
      encoded.data.hex,
      "000102030405060708090a0b0c0d0e0fffffffffffffffffffffffffffffffff"
    )
    XCTAssertEqual(
      try RecipeIdentifierSetCodec.decode(formatVersion: 1, data: encoded.data),
      [earlier, later]
    )
  }

  func testIdentifierSetRejectsMalformedDuplicateAndNoncanonicalData() {
    let first = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let second = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    XCTAssertThrowsError(
      try RecipeIdentifierSetCodec.decode(formatVersion: 1, data: Data([0]))
    )
    XCTAssertThrowsError(
      try RecipeIdentifierSetCodec.decode(
        formatVersion: 1,
        data: RecipeIdentifierSetCodec.encode([first, first]).data
      )
    )
    XCTAssertThrowsError(
      try RecipeIdentifierSetCodec.decode(
        formatVersion: 1,
        data: Data(RecipeIdentifierSetCodec.encode([second, first]).data.reversed())
      )
    )
    XCTAssertThrowsError(
      try RecipeIdentifierSetCodec.decode(formatVersion: 2, data: Data())
    )
  }

  func testEmptyPayloadManifestHasFrozenFormatOneBytes() throws {
    let recipeID = Recipe.ID(rawValue: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!)
    let revision = RecipeRevision(
      id: .init(rawValue: UUID(uuidString: "00010203-0405-0607-0809-0a0b0c0d0e0f")!),
      recipeID: recipeID,
      revisionNumber: 1,
      title: "Soup"
    )

    let encoded = RecipePayloadManifestCodec.encode(RecipePayloadManifest(revision: revision))

    XCTAssertEqual(encoded.formatVersion, 1)
    XCTAssertEqual(
      encoded.data.hex,
      "000102030405060708090a0b0c0d0e0f" + String(repeating: "00", count: 24)
    )
    XCTAssertEqual(
      try RecipePayloadManifestCodec.decode(formatVersion: 1, data: encoded.data),
      RecipePayloadManifest(revision: revision)
    )
  }

  func testRevisionCodecIsCanonicalAndDigestCoversCompleteValue() throws {
    let recipeID = Recipe.ID(rawValue: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!)
    var revision = RecipeRevision(
      id: .init(rawValue: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!),
      recipeID: recipeID,
      revisionNumber: 1,
      title: "Soup",
      summary: nil,
      categories: ["Supper", "Quick"]
    )
    let first = try RecipeRevisionCodec.encode(revision)
    XCTAssertEqual(try RecipeRevisionCodec.decode(formatVersion: 1, data: first.data), revision)

    revision.summary = "Warm"
    let second = try RecipeRevisionCodec.encode(revision)
    XCTAssertNotEqual(first.digest, second.digest)
    XCTAssertThrowsError(
      try RecipeRevisionCodec.decode(formatVersion: 1, data: first.data + Data([0x0A]))
    )
  }
}

private extension Data {
  var hex: String { map { String(format: "%02x", $0) }.joined() }
}
