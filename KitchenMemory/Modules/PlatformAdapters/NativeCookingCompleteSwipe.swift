// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CoreGraphics
import Foundation
import SwiftUI

#if os(iOS)
import UIKit

/// A marker confines Complete to the instruction text. A rightward horizontal
/// pan may recognize alongside reading scroll; vertical/leftward intent fails.
struct NativeCookingCompleteSwipe: UIViewRepresentable {
  let isEnabled: Bool
  let complete: () -> Void

  func makeCoordinator() -> Coordinator { Coordinator() }
  func makeUIView(context: Context) -> Marker {
    let marker = Marker()
    marker.isUserInteractionEnabled = false
    marker.attach = { [weak marker, weak coordinator = context.coordinator] in
      guard let marker, let coordinator else { return }
      coordinator.attach(to: marker)
    }
    return marker
  }
  func updateUIView(_ marker: Marker, context: Context) {
    context.coordinator.complete = complete
    context.coordinator.pan.isEnabled = isEnabled
    context.coordinator.attach(to: marker)
  }
  static func dismantleUIView(_ marker: Marker, coordinator: Coordinator) { coordinator.detach() }

  final class Marker: UIView {
    var attach: () -> Void = {}
    override func didMoveToWindow() { super.didMoveToWindow(); attach() }
  }

  final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    weak var marker: Marker?
    var complete: () -> Void = {}
    lazy var pan = UIPanGestureRecognizer(target: self, action: #selector(swiped))

    func attach(to marker: Marker) {
      self.marker = marker
      var ancestor = marker.superview
      while let view = ancestor, !(view is UIScrollView) { ancestor = view.superview }
      guard let ancestor, pan.view !== ancestor else { return }
      detach()
      pan.delegate = self
      pan.cancelsTouchesInView = false
      ancestor.addGestureRecognizer(pan)
    }
    func detach() { pan.view?.removeGestureRecognizer(pan) }
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
      guard let marker else { return false }
      let translation = pan.translation(in: marker)
      let location = pan.location(in: marker)
      let start = CGPoint(x: location.x - translation.x, y: location.y - translation.y)
      let velocity = pan.velocity(in: marker)
      return marker.bounds.contains(start) && velocity.x > 0 && velocity.x > abs(velocity.y) * 2
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
      true
    }
    @objc private func swiped() {
      let value = pan.translation(in: marker)
      if pan.state == .ended, value.x >= 90, value.x > abs(value.y) * 2 { complete() }
    }
  }
}
#else
struct NativeCookingCompleteSwipe: View {
  let isEnabled: Bool
  let complete: () -> Void
  var body: some View { Color.clear }
}
#endif
