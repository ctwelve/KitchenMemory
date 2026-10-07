// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import SwiftData

/// Revision-owned private bytes. No relationships or cascading deletion.
@Model final class RecipeImagePayloadRecord {
  var revisionID: UUID = UUID()
  var mediaID: UUID = UUID()
  @Attribute(.externalStorage) var imageData: Data?

  init(revisionID: UUID, mediaID: UUID, imageData: Data) {
    self.revisionID = revisionID
    self.mediaID = mediaID
    self.imageData = imageData
  }
}
