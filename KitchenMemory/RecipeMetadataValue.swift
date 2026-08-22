// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation

struct MetadataValue: Identifiable {
  let label: String
  let value: String
  let systemImage: String

  var id: String { label }
}
