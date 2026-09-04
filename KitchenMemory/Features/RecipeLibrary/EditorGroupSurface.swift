// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import SwiftUI

/// Opaque theme surfaces keep dense editing groups legible in both appearances.
/// Borders and spacing preserve the grouping independently of alternating color.
struct EditorGroupSurface: ViewModifier {
  let index: Int
  @Environment(\.colorSchemeContrast) private var contrast

  func body(content: Content) -> some View {
    content
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color(index.isMultiple(of: 2) ? "SubtleFill" : "SubtleFillAlt"), in: .rect(cornerRadius: 12))
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color(contrast == .increased ? "AccentColor" : "SubtleBorder"), lineWidth: 1)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
      .padding(.vertical, 4)
      .listRowSeparator(.hidden)
      .listRowBackground(Color.clear)
  }
}
