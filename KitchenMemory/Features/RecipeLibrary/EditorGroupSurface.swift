// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import SwiftUI

/// Opaque theme surfaces keep dense editing groups legible in both appearances.
/// Borders and spacing preserve the grouping independently of alternating color.
struct EditorGroupSurface: ViewModifier {
  enum Level {
    case section, item
  }

  let index: Int
  var level: Level = .section
  @Environment(\.colorSchemeContrast) private var contrast

  func body(content: Content) -> some View {
    if level == .section {
      surface(content)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    } else {
      surface(content)
    }
  }

  private var fill: Color {
    let primary = level == .section ? "SubtleFill" : "ContentSurface"
    let alternate = level == .section ? "SubtleFillAlt" : "ContentSurfaceAlt"
    return Color(index.isMultiple(of: 2) ? primary : alternate)
  }

  private func surface(_ content: Content) -> some View {
    content
      .padding(level == .section ? 14 : 10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(fill, in: .rect(cornerRadius: 12))
      .overlay {
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color(contrast == .increased ? "AccentColor" : "SubtleBorder"), lineWidth: 1)
          .allowsHitTesting(false)
          .accessibilityHidden(true)
      }
      .padding(.vertical, 4)
  }
}
