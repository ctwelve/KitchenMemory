// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CryptoKit
import Foundation

/// Session tombstones can arrive before the prepared graph and remain available to every restored scope.
@MainActor
struct OrganizationHistorySceneDisposals {
  let root: URL

  func record(_ identifiers: Set<String>) throws {
    let directory = root.appendingPathComponent("DiscardedSceneSessions", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for identifier in identifiers {
      try Data("discarded".utf8).write(to: marker(identifier), options: .atomic)
    }
  }

  func contains(_ identifier: String) -> Bool {
    FileManager.default.fileExists(atPath: marker(identifier).path)
  }

  private func marker(_ identifier: String) -> URL {
    let digest = SHA256.hash(data: Data(identifier.utf8)).map { String(format: "%02x", $0) }.joined()
    return root.appendingPathComponent("DiscardedSceneSessions", isDirectory: true)
      .appendingPathComponent(digest + ".discarded")
  }

  static func deviceLocalRoot() throws -> URL {
    try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
      appropriateFor: nil, create: true).appendingPathComponent("RecipeOrganizationHistory", isDirectory: true)
  }
}
