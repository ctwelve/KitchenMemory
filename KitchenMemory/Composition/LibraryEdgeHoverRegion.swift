// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

#if os(macOS)
  import SwiftUI
  import AppKit

  /// A bounded native tracking surface; clicks continue through to the content.
  struct LibraryEdgeHoverRegion: NSViewRepresentable {
    var changed: (Bool) -> Void

    func makeNSView(context: Context) -> TrackingView { TrackingView(changed: changed) }
    func updateNSView(_ view: TrackingView, context: Context) { view.changed = changed }

    final class TrackingView: NSView {
      var changed: (Bool) -> Void
      private var area: NSTrackingArea?

      init(changed: @escaping (Bool) -> Void) {
        self.changed = changed
        super.init(frame: .zero)
      }
      required init?(coder: NSCoder) { nil }

      override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area { removeTrackingArea(area) }
        let newArea = NSTrackingArea(
          rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
          owner: self, userInfo: nil
        )
        addTrackingArea(newArea)
        area = newArea
      }
      override func mouseEntered(with event: NSEvent) { changed(true) }
      override func mouseExited(with event: NSEvent) { changed(false) }
      override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
  }
#endif
