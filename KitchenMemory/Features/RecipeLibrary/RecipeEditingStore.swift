// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import CryptoKit

extension FileRecipeEditingStore {
  static func deviceLocal(ownerID: KitchenOwner.ID) throws -> Self {
    let directory = try FileManager.default.url(
      for: .applicationSupportDirectory, in: .userDomainMask,
      appropriateFor: nil, create: true
    ).appendingPathComponent("RecipeDrafts", isDirectory: true)
    let owner = SHA256.hash(data: Data(ownerID.rawValue.utf8))
      .map { String(format: "%02x", $0) }.joined()
    return Self(url: directory.appendingPathComponent("\(owner).json"))
  }
}
