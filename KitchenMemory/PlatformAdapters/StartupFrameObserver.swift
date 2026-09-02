// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import QuartzCore
import SwiftUI

@MainActor
final class StartupFrameReporter {
  var needsPresentationBoundary: Bool { !hasReportedFrame }

  private var didPresent: @MainActor () -> Void
  private var hasReportedFrame = false

  init(didPresent: @escaping @MainActor () -> Void) {
    self.didPresent = didPresent
  }

  func update(didPresent: @escaping @MainActor () -> Void) {
    self.didPresent = didPresent
  }

  func reportPresentedFrameIfNeeded() {
    guard !hasReportedFrame else { return }
    hasReportedFrame = true
    didPresent()
  }
}

#if os(macOS)
import AppKit

struct StartupFrameObserver: NSViewRepresentable {
  let didPresent: @MainActor () -> Void

  func makeNSView(context: Context) -> StartupFrameObservationView {
    StartupFrameObservationView(didPresent: didPresent)
  }

  func updateNSView(_ view: StartupFrameObservationView, context: Context) {
    view.reporter.update(didPresent: didPresent)
    view.needsDisplay = true
  }
}

@MainActor
final class StartupFrameObservationView: NSView {
  let reporter: StartupFrameReporter
  private var presentationDisplayLink: CADisplayLink?

  init(didPresent: @escaping @MainActor () -> Void) {
    reporter = StartupFrameReporter(didPresent: didPresent)
    super.init(frame: .zero)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable")
  }

  override var isOpaque: Bool { false }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    needsDisplay = true
  }

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    armPresentationBoundaryIfNeeded()
  }

  override func viewWillMove(toWindow newWindow: NSWindow?) {
    super.viewWillMove(toWindow: newWindow)
    guard newWindow == nil else { return }
    presentationDisplayLink?.invalidate()
    presentationDisplayLink = nil
  }

  private func armPresentationBoundaryIfNeeded() {
    guard window != nil,
          presentationDisplayLink == nil,
          reporter.needsPresentationBoundary else { return }
    let displayLink = displayLink(
      target: self,
      selector: #selector(displayDidRefresh(_:))
    )
    displayLink.add(to: .main, forMode: .common)
    presentationDisplayLink = displayLink
  }

  @objc private func displayDidRefresh(_ displayLink: CADisplayLink) {
    displayLink.invalidate()
    presentationDisplayLink = nil
    reporter.reportPresentedFrameIfNeeded()
  }
}
#elseif os(iOS)
import UIKit

struct StartupFrameObserver: UIViewRepresentable {
  let didPresent: @MainActor () -> Void

  func makeUIView(context: Context) -> StartupFrameObservationView {
    StartupFrameObservationView(didPresent: didPresent)
  }

  func updateUIView(_ view: StartupFrameObservationView, context: Context) {
    view.reporter.update(didPresent: didPresent)
    view.setNeedsDisplay()
  }
}

@MainActor
final class StartupFrameObservationView: UIView {
  let reporter: StartupFrameReporter
  private var presentationDisplayLink: CADisplayLink?

  init(didPresent: @escaping @MainActor () -> Void) {
    reporter = StartupFrameReporter(didPresent: didPresent)
    super.init(frame: .zero)
    isOpaque = false
    backgroundColor = .clear
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is unavailable")
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    setNeedsDisplay()
  }

  override func draw(_ rect: CGRect) {
    super.draw(rect)
    armPresentationBoundaryIfNeeded()
  }

  override func willMove(toWindow newWindow: UIWindow?) {
    super.willMove(toWindow: newWindow)
    guard newWindow == nil else { return }
    presentationDisplayLink?.invalidate()
    presentationDisplayLink = nil
  }

  private func armPresentationBoundaryIfNeeded() {
    guard window != nil,
          presentationDisplayLink == nil,
          reporter.needsPresentationBoundary else { return }
    let displayLink = CADisplayLink(
      target: self,
      selector: #selector(displayDidRefresh(_:))
    )
    displayLink.add(to: .main, forMode: .common)
    presentationDisplayLink = displayLink
  }

  @objc private func displayDidRefresh(_ displayLink: CADisplayLink) {
    displayLink.invalidate()
    presentationDisplayLink = nil
    reporter.reportPresentedFrameIfNeeded()
  }
}
#endif
