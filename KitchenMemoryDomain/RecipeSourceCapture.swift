// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation

/// Bounded source evidence retained with an imported recipe revision.
///
/// The web importer stores a UTF-8 transcription of the containing JSON-LD
/// block once, plus the coordinates of the selected recipe. It intentionally
/// does not retain the entire HTML document, its original network encoding, or
/// a duplicate normalized candidate payload.
public struct RecipeSourceCapture: Codable, Equatable, Sendable {
  public enum Kind: String, Codable, Sendable {
    case schemaOrgJSONLD
  }

  public let kind: Kind
  /// The final fetched document URL, after redirects.
  public let sourceURL: URL
  public let capturedAt: Date
  public let mediaType: String
  /// Untrusted opaque JSON text, encoded as UTF-8.
  ///
  /// Never execute this payload or insert it into an HTML surface. The current
  /// native UI treats it only as source evidence for future reinterpretation.
  public let payload: Data
  /// Candidate traversal coordinates from the importer version that captured it.
  ///
  /// These values are not a permanent JSON Pointer. A later importer may walk
  /// the same document differently as its Schema.org support improves.
  public let blockIndex: Int
  public let objectIndex: Int

  public init(
    kind: Kind,
    sourceURL: URL,
    capturedAt: Date,
    mediaType: String,
    payload: Data,
    blockIndex: Int,
    objectIndex: Int
  ) {
    self.kind = kind
    self.sourceURL = sourceURL
    self.capturedAt = capturedAt
    self.mediaType = mediaType
    self.payload = payload
    self.blockIndex = blockIndex
    self.objectIndex = objectIndex
  }
}
