// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import SwiftUI

/// Native controls own persistent visibility; pointer reveal leaves the split and its drafts in place.
struct AdaptiveLibraryShell<Sidebar: View, Content: View, Detail: View>: View {
  @Binding var visibility: NavigationSplitViewVisibility
  @Binding var preferredColumn: NavigationSplitViewColumn
  @Binding var temporarySidebar: Bool
  @ViewBuilder let sidebar: () -> Sidebar
  @ViewBuilder let content: () -> Content
  @ViewBuilder let detail: () -> Detail
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.layoutDirection) private var layoutDirection

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        NavigationSplitView(columnVisibility: $visibility, preferredCompactColumn: $preferredColumn) {
          sidebar()
        } content: {
          content()
        } detail: {
          detail()
        }
        .navigationSplitViewStyle(.balanced)
        // Otherwise the underlying native split intercepts accessibility hit tests for the overlay.
        .accessibilityHidden(temporarySidebar)
#if os(macOS)
        let sidebarWidth = min(280, geometry.size.width - 32)
        if temporarySidebar {
          sidebar()
            .frame(width: sidebarWidth)
            .background(.regularMaterial, ignoresSafeAreaEdges: .top)
            .shadow(radius: 8)
            .transition(.move(edge: .leading))
            .onExitCommand { setReveal(false) }
        }
#endif
      }
#if os(macOS)
      .background {
        NativeSidebarHover(isHidden: visibility != .all, isRevealed: temporarySidebar,
                           sidebarWidth: min(280, geometry.size.width - 32), layoutDirection: layoutDirection,
                           reveal: { setReveal(true) }, dismiss: { setReveal(false) })
      }
#endif
    }
    .onChange(of: visibility) { _, _ in setReveal(false) }
  }

  private func setReveal(_ shown: Bool) {
    guard temporarySidebar != shown else { return }
    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { temporarySidebar = shown }
  }
}
