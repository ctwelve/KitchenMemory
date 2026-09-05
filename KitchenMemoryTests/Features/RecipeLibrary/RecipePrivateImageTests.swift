// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenMemory
import CoreGraphics
import ImageIO
import KitchenKit
import UniformTypeIdentifiers
import XCTest

@MainActor
final class RecipePrivateImageTests: XCTestCase {
  func testSyntheticImageImportProducesUsablePrivateImageAndRejectsInvalidData() throws {
    let context = try XCTUnwrap(CGContext(
      data: nil, width: 4, height: 3, bitsPerComponent: 8, bytesPerRow: 16,
      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ))
    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 4, height: 3))
    let output = NSMutableData()
    let destination = try XCTUnwrap(CGImageDestinationCreateWithData(
      output, UTType.png.identifier as CFString, 1, nil
    ))
    CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    let normalized = try RecipePrivateImage.normalized(output as Data)
    let media = RecipeMedia(role: .hero, imageData: normalized)
    XCTAssertNotNil(RecipePrivateImage.image(for: media))
    XCTAssertThrowsError(try RecipePrivateImage.normalized(Data()))
    XCTAssertThrowsError(try RecipePrivateImage.normalized(Data([0, 1, 2])))
    XCTAssertNil(RecipePrivateImage.image(for: RecipeMedia(role: .hero, assetName: "missing-synthetic-asset")))
    var unavailable = media
    unavailable.imageData = nil
    XCTAssertNil(RecipePrivateImage.image(for: unavailable))
    unavailable.imageData = Data([1, 2])
    XCTAssertNil(RecipePrivateImage.image(for: unavailable))
  }
}
