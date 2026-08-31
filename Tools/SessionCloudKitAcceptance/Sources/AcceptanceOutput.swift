// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

enum AcceptanceOutput {
  static func emit(_ values: [String: Any]) {
    guard JSONSerialization.isValidJSONObject(values),
          let data = try? JSONSerialization.data(
            withJSONObject: values,
            options: [.sortedKeys]
          ),
          let line = String(data: data, encoding: .utf8)
    else {
      print("{\"event\":\"harness-error\",\"reason\":\"encoding\"}")
      return
    }
    print(line)
  }
}
