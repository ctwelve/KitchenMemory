// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import ImageIO
import KitchenKit
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Native decoding and bounded, metadata-free storage of explicitly selected images.
enum RecipePrivateImage {
  static let maximumInputBytes = 20 * 1_024 * 1_024

  static func importedData(from url: URL) throws -> Data {
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
    guard size > 0, size <= maximumInputBytes else { throw CocoaError(.fileReadTooLarge) }
    return try normalized(Data(contentsOf: url))
  }

  static func normalized(_ data: Data) throws -> Data {
    guard !data.isEmpty, data.count <= maximumInputBytes,
      let source = CGImageSourceCreateWithData(data as CFData, nil),
      let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: 2_400,
      ] as CFDictionary)
    else { throw CocoaError(.fileReadCorruptFile) }
    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
    else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    return output as Data
  }

  static func image(for media: RecipeMedia) -> Image? {
    if media.isPrivateImage {
      guard let data = media.imageData, media.acceptsImageData(data),
        let source = CGImageSourceCreateWithData(data as CFData, nil),
        let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
      return Image(decorative: decoded, scale: 1)
    }
#if os(macOS)
    guard let image = SampleRecipeCatalog.resourceBundle.image(forResource: media.assetName) else { return nil }
    return Image(nsImage: image)
#else
    guard let image = UIImage(named: media.assetName, in: SampleRecipeCatalog.resourceBundle, compatibleWith: nil)
    else { return nil }
    return Image(uiImage: image)
#endif
  }
}
