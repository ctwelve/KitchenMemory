// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CryptoKit
import Foundation

extension RecipeMedia {
  /// Private image references are content-addressed, never bundled resource names.
  public init(role: Role, imageData: Data, accessibilityLabel: String? = nil) {
    self.init(role: role, assetName: Self.privateReference(for: imageData),
              accessibilityLabel: accessibilityLabel)
    self.imageData = imageData
  }

  public var isPrivateImage: Bool { assetName.hasPrefix("private-image:sha256:") }

  public func acceptsImageData(_ data: Data) -> Bool {
    isPrivateImage && assetName == Self.privateReference(for: data)
  }

  private static func privateReference(for data: Data) -> String {
    "private-image:sha256:" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}
