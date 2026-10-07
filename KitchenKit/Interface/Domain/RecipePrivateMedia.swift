// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CryptoKit
import Foundation

extension RecipeMedia {
  /// Creates a fresh media identity with a SHA-256 content-addressed reference.
  ///
  /// The supplied bytes are retained locally without decoding, normalization, or
  /// size checks; image preparation belongs to the media acceptance boundary.
  public init(role: Role, imageData: Data, accessibilityLabel: String? = nil) {
    self.init(role: role, assetName: Self.privateReference(for: imageData),
              accessibilityLabel: accessibilityLabel)
    self.imageData = imageData
  }

  /// Whether the logical reference uses the private content-addressed prefix.
  ///
  /// This checks reference syntax only, without validating or decoding bytes.
  public var isPrivateImage: Bool { assetName.hasPrefix("private-image:sha256:") }

  /// Whether supplied bytes hash to this private reference.
  ///
  /// Bundled names always return false; a matching digest does not prove the bytes
  /// are a decodable image.
  public func acceptsImageData(_ data: Data) -> Bool {
    isPrivateImage && assetName == Self.privateReference(for: data)
  }

  private static func privateReference(for data: Data) -> String {
    "private-image:sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}
