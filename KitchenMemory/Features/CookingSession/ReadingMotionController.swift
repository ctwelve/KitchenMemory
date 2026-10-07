// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CoreGraphics
import Foundation

struct ReadingViewport {
  let offset: Double
  let height: Double
  let contentHeight: Double
}

/// Owns cancellable, incremental reveal. A native input cancels at the present
/// offset; late scheduler callbacks cannot move the document or restart travel.
@MainActor
final class ReadingMotionController {
  private let viewport: () -> ReadingViewport
  private let move: (Double) -> Void
  private let now: () -> TimeInterval
  private let schedule: @MainActor (@escaping @MainActor () -> Void) -> (() -> Void)
  private var cancelFrames: (() -> Void)?
  private var generation: UUID?

  var isMoving: Bool { generation != nil }

  isolated deinit { cancelFrames?() }

  func restore(to offset: Double) {
    interrupt()
    guard offset.isFinite else { return }
    let visible = viewport()
    move(max(0, min(offset, visible.contentHeight - visible.height)))
  }

  init(viewport: @escaping () -> ReadingViewport, move: @escaping (Double) -> Void,
       now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
       schedule: @escaping @MainActor (@escaping @MainActor () -> Void) -> (() -> Void)
         = ReadingMotionController.scheduleFrames) {
    self.viewport = viewport
    self.move = move
    self.now = now
    self.schedule = schedule
  }

  func interrupt() {
    generation = nil
    cancelFrames?()
    cancelFrames = nil
  }

  func reveal(_ frame: CGRect, animated: Bool) {
    interrupt()
    let visible = viewport()
    let origin = visible.offset
    let desired: Double
    if frame.minY < origin + 12 { desired = frame.minY - 12 } else if frame.maxY > origin + visible.height - 12 {
      desired = min(frame.minY - 12, frame.maxY - visible.height + 12)
    } else { return }
    let destination = max(0, min(desired, visible.contentHeight - visible.height))
    guard destination.isFinite, abs(destination - origin) > 1 else { return }
    guard animated else { move(destination); return }
    let identity = UUID()
    generation = identity
    let started = now()
    let duration = max(1.5, min(4, abs(destination - origin) / 100))
    cancelFrames = schedule { [weak self] in
      guard let self, self.generation == identity else { return }
      let fraction = min(1, max(0, (self.now() - started) / duration))
      self.move(origin + (destination - origin) * fraction)
      if fraction >= 1 { self.interrupt() }
    }
  }

  private static func scheduleFrames(_ action: @escaping @MainActor () -> Void) -> (() -> Void) {
    let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { _ in
      MainActor.assumeIsolated { action() }
    }
    RunLoop.main.add(timer, forMode: .common)
    return { timer.invalidate() }
  }
}
