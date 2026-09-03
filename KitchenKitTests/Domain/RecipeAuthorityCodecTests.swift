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

  func testPayloadManifestRejectsUnsupportedMalformedAndDuplicateData() {
    XCTAssertThrowsError(
      try RecipePayloadManifestCodec.decode(formatVersion: 2, data: Data())
    )
    XCTAssertThrowsError(
      try RecipePayloadManifestCodec.decode(formatVersion: 1, data: Data())
    )

    let revisionID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    var missingFamilies = Data(revisionID.uuidBytes)
    missingFamilies.append(contentsOf: [0, 0, 0, 0])
    XCTAssertThrowsError(
      try RecipePayloadManifestCodec.decode(formatVersion: 1, data: missingFamilies)
    )

    let duplicateID = RecipeMedia.ID(
      rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    )
    let duplicate = RecipePayloadManifest(
      revisionID: .init(rawValue: revisionID),
      mediaIDs: [duplicateID, duplicateID],
      equipmentIDs: [],
      ingredientSectionIDs: [],
      ingredientIDs: [],
      instructionSectionIDs: [],
      instructionStepIDs: []
    )
    XCTAssertThrowsError(
      try RecipePayloadManifestCodec.decode(
        formatVersion: 1,
        data: RecipePayloadManifestCodec.encode(duplicate).data
      )
    )

    let valid = RecipePayloadManifestCodec.encode(RecipePayloadManifest(
      revisionID: .init(rawValue: revisionID),
      mediaIDs: [],
      equipmentIDs: [],
      ingredientSectionIDs: [],
      ingredientIDs: [],
      instructionSectionIDs: [],
      instructionStepIDs: []
    )).data
    XCTAssertThrowsError(
      try RecipePayloadManifestCodec.decode(formatVersion: 1, data: valid + Data([0]))
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
    XCTAssertThrowsError(
      try RecipeRevisionCodec.decode(formatVersion: 2, data: first.data)
    )
    XCTAssertThrowsError(
      try RecipeRevisionCodec.decode(formatVersion: 1, data: Data("{}".utf8))
    )

    let object = try XCTUnwrap(
      JSONSerialization.jsonObject(with: first.data) as? [String: Any]
    )
    let noncanonical = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
    XCTAssertThrowsError(
      try RecipeRevisionCodec.decode(formatVersion: 1, data: noncanonical)
    )
  }

  func testAuthorityFrontierHasFrozenFamilyOrderAndRejectsNoncanonicalSets() throws {
    let revisionID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let selectionID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let deletionID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    let restorationID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    let frontier = RecipeAuthorityFrontier(
      revisionHeads: [.init(rawValue: revisionID)],
      selectionHeads: [.init(rawValue: selectionID)],
      deletionIDs: [deletionID],
      restorationIDs: [restorationID]
    )

    let encoded = RecipeAuthorityFrontierCodec.encode(frontier)

    XCTAssertEqual(encoded.formatVersion, 1)
    XCTAssertEqual(encoded.data.count, 80)
    XCTAssertEqual(
      try RecipeAuthorityFrontierCodec.decode(formatVersion: 1, data: encoded.data),
      frontier
    )
    var noncanonical = encoded.data
    noncanonical.replaceSubrange(0..<4, with: [0, 0, 0, 2])
    noncanonical.insert(contentsOf: Array(repeating: 0, count: 16), at: 20)
    XCTAssertThrowsError(
      try RecipeAuthorityFrontierCodec.decode(formatVersion: 1, data: noncanonical)
    )
    let duplicate = RecipeAuthorityFrontier(
      revisionHeads: [
        .init(rawValue: revisionID),
        .init(rawValue: revisionID),
      ],
      selectionHeads: [],
      deletionIDs: [],
      restorationIDs: []
    )
    XCTAssertThrowsError(
      try RecipeAuthorityFrontierCodec.decode(
        formatVersion: 1,
        data: RecipeAuthorityFrontierCodec.encode(duplicate).data
      )
    )
    XCTAssertThrowsError(
      try RecipeAuthorityFrontierCodec.decode(formatVersion: 2, data: encoded.data)
    )
    XCTAssertThrowsError(
      try RecipeAuthorityFrontierCodec.decode(formatVersion: 1, data: Data())
    )
    XCTAssertThrowsError(
      try RecipeAuthorityFrontierCodec.decode(formatVersion: 1, data: encoded.data + Data([0]))
    )
  }
}

private extension UUID {
  var uuidBytes: [UInt8] {
    withUnsafeBytes(of: uuid) { Array($0) }
  }
}

private extension Data {
  var hex: String { map { String(format: "%02x", $0) }.joined() }
}
