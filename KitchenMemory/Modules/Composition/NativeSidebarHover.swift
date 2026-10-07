// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

#if os(macOS)
import AppKit
import SwiftUI

/// Adds temporary reveal to the system sidebar control without replacing its action or accessibility.
struct NativeSidebarHover: NSViewRepresentable {
  var isHidden: Bool
  var isRevealed: Bool
  var sidebarWidth: CGFloat
  var layoutDirection: LayoutDirection
  var reveal: () -> Void
  var dismiss: () -> Void

  func makeNSView(context: Context) -> TrackingView { TrackingView() }
  func updateNSView(_ view: TrackingView, context: Context) {
    view.configuration = self
    view.installTracking()
  }
  static func dismantleNSView(_ view: TrackingView, coordinator: ()) { view.removeTracking() }

  final class TrackingView: NSView {
    var configuration: NativeSidebarHover?
    private weak var trackedView: NSView?
    private var tracking: NSTrackingArea?

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      installTracking()
    }

    func installTracking() {
      guard let frame = window?.contentView?.superview else { removeTracking(); return }
      guard trackedView !== frame else { return }
      removeTracking()
      let area = NSTrackingArea(rect: .zero,
                               options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                               owner: self, userInfo: nil)
      frame.addTrackingArea(area)
      trackedView = frame
      tracking = area
    }

    func removeTracking() {
      if let tracking { trackedView?.removeTrackingArea(tracking) }
      tracking = nil
      trackedView = nil
    }

    override func mouseMoved(with event: NSEvent) {
      guard let configuration, configuration.isHidden, let frame = trackedView else { return }
      let point = frame.convert(event.locationInWindow, from: nil)
      if configuration.isRevealed {
        let outsideSidebar = configuration.layoutDirection == .leftToRight
          ? point.x > frame.bounds.minX + configuration.sidebarWidth
          : point.x < frame.bounds.maxX - configuration.sidebarWidth
        if outsideSidebar || !frame.bounds.contains(point) { configuration.dismiss() }
      } else if let button = sidebarControl, button.convert(button.bounds, to: frame).contains(point) {
        configuration.reveal()
      }
    }

    override func mouseExited(with event: NSEvent) { configuration?.dismiss() }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    private var sidebarControl: NSView? {
      // AppKit supplies a standard identifier. SwiftUI hosts its native control
      // under its own identifier; keep that compatibility detail at this boundary.
      window?.toolbar?.items.first {
        $0.itemIdentifier == .toggleSidebar
          || $0.itemIdentifier.rawValue == "com.apple.SwiftUI.navigationSplitView.toggleSidebar"
      }?.view
    }
  }
}
#endif
