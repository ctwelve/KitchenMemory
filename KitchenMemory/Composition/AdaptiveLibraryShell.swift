// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import SwiftUI

/// A temporary reveal never writes persistent column visibility or replaces the
/// detail subtree. Selection and drafts remain owned by the prepared app graph.
struct AdaptiveLibraryShell<Sidebar: View, Content: View, Detail: View>: View {
  @Binding var visibility: NavigationSplitViewVisibility
  @Binding var preferredColumn: NavigationSplitViewColumn
  @Binding var temporarySidebar: Bool
  @ViewBuilder let sidebar: () -> Sidebar
  @ViewBuilder let content: () -> Content
  @ViewBuilder let detail: () -> Detail
  @State private var hoverTask: Task<Void, Never>?
  @AccessibilityFocusState private var revealFocused: Bool
  @AccessibilityFocusState private var dismissFocused: Bool

  var body: some View {
    GeometryReader { geometry in
      NavigationSplitView(columnVisibility: $visibility, preferredCompactColumn: $preferredColumn) {
        sidebar()
      } content: {
        content()
#if os(iOS)
          .toolbar { revealToolbar }
#endif
      } detail: {
        detail()
#if os(iOS)
          .toolbar { revealToolbar }
#endif
      }
      .navigationSplitViewStyle(.balanced)
#if os(macOS)
      .toolbar { revealToolbar }
#endif
      .accessibilityHidden(temporarySidebar)
      .overlay(alignment: .leading) {
        if temporarySidebar {
          temporaryOrganization(width: min(280, geometry.size.width - 32))
        } else if visibility != .all {
#if os(macOS)
          LibraryEdgeHoverRegion(changed: hoverChanged)
            .frame(width: 12)
            .accessibilityHidden(true)
#endif
        }
      }
      .onChange(of: geometry.size) { _, _ in dismissReveal() }
    }
    .onChange(of: visibility) { _, _ in dismissReveal() }
    .onChange(of: preferredColumn) { _, _ in dismissReveal() }
    .onDisappear { hoverTask?.cancel() }
  }

  @ToolbarContentBuilder private var revealToolbar: some ToolbarContent {
    ToolbarItem(placement: .navigation) {
      Menu {
        Button(.libraryOrganizationReveal) { temporarySidebar = true }
          .accessibilityIdentifier("reveal-organization")
        Button(visibility == .all ? .librarySidebarActionHide : .librarySidebarActionShow) {
          visibility = visibility == .all ? .doubleColumn : .all
          preferredColumn = visibility == .all ? .sidebar : .content
        }
      } label: {
        Label(.organizationTitle, systemImage: "sidebar.left")
      }
      .accessibilityIdentifier("organization-navigation")
      .accessibilityFocused($revealFocused)
      .help(Text(.organizationTitle))
    }
  }

  private func temporaryOrganization(width: CGFloat) -> some View {
    VStack(spacing: 0) {
      HStack {
        Text(.organizationTitle).font(.headline).accessibilityAddTraits(.isHeader)
        Spacer()
        Button(.librarySidebarActionHide, systemImage: "xmark") { dismissReveal() }
          .labelStyle(.iconOnly)
          .keyboardShortcut(.escape, modifiers: [])
          .accessibilityFocused($dismissFocused)
      }.padding()
      sidebar()
    }
    .frame(width: width)
    .background(.regularMaterial)
    .clipShape(.rect(cornerRadius: 12))
    .shadow(radius: 8)
    .padding(.vertical, 8)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(Text(.organizationTitle))
    .accessibilityIdentifier("temporary-organization")
    .accessibilityAction(.escape) { dismissReveal() }
    .onAppear { dismissFocused = true }
  }

  private func hoverChanged(_ inside: Bool) {
    hoverTask?.cancel()
    guard inside else { return }
    hoverTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(450))
      guard !Task.isCancelled else { return }
      temporarySidebar = true
    }
  }

  private func dismissReveal() {
    hoverTask?.cancel()
    if temporarySidebar { temporarySidebar = false; revealFocused = true }
  }
}
