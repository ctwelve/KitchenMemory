// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

struct SamplePackReceipt: OrganizationPayload {
  let digest: Data
  let enabled: Bool
  let folderID: Folder.ID?
  let tagID: Tag.ID?
  var compactableRegister: String? { nil }
}
