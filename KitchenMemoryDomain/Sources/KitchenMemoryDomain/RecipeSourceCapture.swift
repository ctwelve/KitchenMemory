// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation

/// Bounded source evidence retained with an imported recipe revision.
///
/// The initial web importer stores the containing JSON-LD block once, plus the
/// coordinates of the selected recipe. It intentionally does not retain the
/// entire HTML document or duplicate the normalized candidate payload.
public struct RecipeSourceCapture: Codable, Equatable, Sendable {
  public enum Kind: String, Codable, Sendable {
    case schemaOrgJSONLD
  }

  public var kind: Kind
  public var sourceURL: URL
  public var capturedAt: Date
  public var mediaType: String
  public var payload: Data
  public var blockIndex: Int
  public var objectIndex: Int

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
