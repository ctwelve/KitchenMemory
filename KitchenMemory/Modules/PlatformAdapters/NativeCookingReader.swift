// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

/// A native scroll viewport so pointer/touch input can cancel travel before
/// normal event delivery. SwiftUI retains authored content and semantic controls.
struct NativeCookingReader<Content: View> {
  let session: CookingSessionProjection
  let readingOrigin: UUID
  let preference: CookingSessionReadingPreference
  let completion: CookingSessionReadingCompletion?
  let jump: UUID?
  let isForeground: Bool
  let save: (CookingSessionReadingPosition) -> Void
  @ViewBuilder let content: Content
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.locale) private var locale
  @Environment(\.dynamicTypeSize) private var textSize
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.layoutDirection) private var direction

  func makeCoordinator() -> CookingReaderCoordinator {
    CookingReaderCoordinator(readingOrigin: readingOrigin, position: preference.position, completion: completion)
  }

  func document(_ coordinator: CookingReaderCoordinator) -> some View {
    CookingReaderDocument(content: content, locale: locale, textSize: textSize,
      colorScheme: colorScheme, direction: direction, frames: coordinator.setFrames)
  }

  func update(_ coordinator: CookingReaderCoordinator) {
    coordinator.save = save
    coordinator.prepareLayout(textSize: textSize, reduceMotion: reduceMotion)
    coordinator.update(session: session, preference: preference, completion: completion,
      jump: jump, reduceMotion: reduceMotion)
    if !isForeground { coordinator.end() }
  }
}

#if os(macOS)
import AppKit

extension NativeCookingReader: NSViewRepresentable {
  func makeNSView(context: Context) -> CookingReadingScrollView {
    let scroll = CookingReadingScrollView()
    let coordinator = context.coordinator
    scroll.reader = coordinator
    scroll.documentView = NSHostingView(rootView: AnyView(document(coordinator)))
    scroll.hasVerticalScroller = true
    scroll.drawsBackground = false
    scroll.contentView.postsBoundsChangedNotifications = true
    scroll.boundsObserver = NotificationCenter.default.addObserver(
      forName: NSView.boundsDidChangeNotification, object: scroll.contentView, queue: .main
    ) { [weak coordinator, weak scroll] _ in
      MainActor.assumeIsolated {
        if scroll?.isApplyingReadingMove == false { coordinator?.interrupt() }
        coordinator?.scrolled()
      }
    }
    coordinator.isReady = { [weak scroll] in
      (scroll?.contentSize.height ?? 0) > 0 && (scroll?.documentView?.frame.height ?? 0) > 0
    }
    coordinator.offset = { [weak scroll] in Double(scroll?.contentView.bounds.minY ?? 0) }
    coordinator.motion = ReadingMotionController(viewport: { [weak scroll] in
      ReadingViewport(offset: Double(scroll?.contentView.bounds.minY ?? 0),
        height: Double(scroll?.contentSize.height ?? 0), contentHeight: Double(scroll?.documentView?.frame.height ?? 0))
    }, move: { [weak scroll] value in
      guard let scroll else { return }
      scroll.isApplyingReadingMove = true
      scroll.contentView.scroll(to: NSPoint(x: 0, y: value))
      scroll.reflectScrolledClipView(scroll.contentView)
      scroll.isApplyingReadingMove = false
    })
    scroll.inputMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [.leftMouseDown, .rightMouseDown, .keyDown]
    ) { [weak scroll] event in
      if let scroll, event.window === scroll.window {
        coordinator.takeControl()
      }
      return event
    }
    update(coordinator)
    return scroll
  }

  func updateNSView(_ scroll: CookingReadingScrollView, context: Context) {
    update(context.coordinator)
    (scroll.documentView as? NSHostingView<AnyView>)?.rootView = AnyView(document(context.coordinator))
    scroll.needsLayout = true
  }

  static func dismantleNSView(_ scroll: CookingReadingScrollView, coordinator: CookingReaderCoordinator) {
    coordinator.end()
    if let monitor = scroll.inputMonitor { NSEvent.removeMonitor(monitor) }
    if let observer = scroll.boundsObserver { NotificationCenter.default.removeObserver(observer) }
  }
}

final class CookingReadingScrollView: NSScrollView {
  weak var reader: CookingReaderCoordinator?
  var boundsObserver: NSObjectProtocol?
  var inputMonitor: Any?
  var isApplyingReadingMove = false
  private var previousWidth: CGFloat = 0

  override func layout() {
    super.layout()
    guard let documentView else { return }
    let width = contentSize.width
    if abs(width - previousWidth) > 1 {
      reader?.interrupt()
      previousWidth = width
    }
    documentView.setFrameSize(NSSize(width: width, height: documentView.frame.height))
    documentView.setFrameSize(NSSize(width: width, height: documentView.fittingSize.height))
    reader?.applyGeometry()
  }

  override func scrollWheel(with event: NSEvent) {
    reader?.takeControl()
    super.scrollWheel(with: event)
  }
}
#else
import UIKit

extension NativeCookingReader: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> CookingReadingViewController {
    let controller = CookingReadingViewController()
    let coordinator = context.coordinator
    controller.reader = coordinator
    let host = UIHostingController(rootView: AnyView(document(coordinator)))
    host.sizingOptions = .intrinsicContentSize
    controller.install(host)
    coordinator.isReady = { [weak controller] in
      (controller?.scroll.bounds.height ?? 0) > 0 && (controller?.scroll.contentSize.height ?? 0) > 0
    }
    coordinator.offset = { [weak controller] in Double(controller?.scroll.contentOffset.y ?? 0) }
    coordinator.motion = ReadingMotionController(viewport: { [weak controller] in
      ReadingViewport(offset: Double(controller?.scroll.contentOffset.y ?? 0),
        height: Double(controller?.scroll.bounds.height ?? 0),
        contentHeight: Double(controller?.scroll.contentSize.height ?? 0))
    }, move: { [weak controller] value in
      controller?.isApplyingReadingMove = true
      controller?.scroll.setContentOffset(CGPoint(x: 0, y: value), animated: false)
      controller?.isApplyingReadingMove = false
    })
    update(coordinator)
    return controller
  }

  func updateUIViewController(_ controller: CookingReadingViewController, context: Context) {
    update(context.coordinator)
    controller.host?.rootView = AnyView(document(context.coordinator))
    controller.view.setNeedsLayout()
  }

  static func dismantleUIViewController(
    _ controller: CookingReadingViewController, coordinator: CookingReaderCoordinator
  ) {
    coordinator.end()
  }
}

final class CookingReadingViewController: UIViewController, UIScrollViewDelegate {
  let scroll = UIScrollView()
  var host: UIHostingController<AnyView>?
  weak var reader: CookingReaderCoordinator?
  var isApplyingReadingMove = false
  private var previousWidth: CGFloat = 0

  func install(_ host: UIHostingController<AnyView>) {
    loadViewIfNeeded()
    self.host = host
    view.addSubview(scroll)
    scroll.translatesAutoresizingMaskIntoConstraints = false
    scroll.delegate = self
    scroll.keyboardDismissMode = .interactive
    let observer = CookingReadingTouchObserver(target: nil, action: nil)
    observer.onInput = { [weak reader] in reader?.takeControl() }
    observer.cancelsTouchesInView = false
    observer.delaysTouchesBegan = false
    scroll.addGestureRecognizer(observer)
    addChild(host)
    scroll.addSubview(host.view)
    host.view.backgroundColor = .clear
    host.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      scroll.topAnchor.constraint(equalTo: view.topAnchor),
      scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      host.view.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
      host.view.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
      host.view.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
      host.view.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
    ])
    host.didMove(toParent: self)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    if abs(scroll.bounds.width - previousWidth) > 1 {
      reader?.interrupt()
      previousWidth = scroll.bounds.width
    }
    reader?.applyGeometry()
  }

  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { reader?.takeControl() }
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    if !isApplyingReadingMove { reader?.interrupt() }
    reader?.scrolled()
  }
}

/// Observes first contact, then fails immediately so the intended child control
/// or vertical pan keeps its ordinary gesture delivery.
final class CookingReadingTouchObserver: UIGestureRecognizer {
  var onInput: () -> Void = {}
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    onInput()
    state = .failed
  }
}
#endif
