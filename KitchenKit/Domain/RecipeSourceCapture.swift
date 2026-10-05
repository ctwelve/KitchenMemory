// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Bounded source evidence retained with an imported recipe revision.
///
/// The web importer stores a UTF-8 transcription of the containing JSON-LD
/// block once, plus the coordinates of the selected recipe. It intentionally
/// does not retain the entire HTML document, its original network encoding, or
/// a duplicate normalized candidate payload.
public struct RecipeSourceCapture: Codable, Equatable, Sendable {
  /// The retained source-evidence representation understood by the importer.
  public enum Kind: String, Codable, Sendable {
    /// One source-faithful UTF-8 JSON-LD block containing the selected Schema.org Recipe.
    case schemaOrgJSONLD
  }

  /// The interpretation family for the opaque retained evidence.
  public let kind: Kind
  /// The acquired document location: the final fetched URL after redirects, or
  /// the selected file URL for a local document import.
  ///
  /// A file URL records provenance and must never become an active web link.
  public let sourceURL: URL
  /// The acquisition date recorded as provenance, without making it Recipe authority.
  public let capturedAt: Date
  /// The declared evidence media type, retained without inspecting or executing the payload.
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
  /// The discovered object position within the captured block, not a permanent JSON Pointer.
  public let objectIndex: Int

  /// Retains supplied source evidence and traversal coordinates.
  ///
  /// Construction does not enforce importer budgets or validate URLs; consumers must
  /// keep payloads opaque and never promote them into executable presentation.
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
