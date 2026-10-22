// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension EnvironmentValues {
  @Entry var organizationHistory: OrganizationHistoryPresentation?
}

#if os(macOS)
private struct OrganizationHistoryFocusedKey: FocusedValueKey {
  typealias Value = OrganizationHistoryPresentation
}
extension FocusedValues {
  var organizationHistory: OrganizationHistoryPresentation? {
    get { self[OrganizationHistoryFocusedKey.self] }
    set { self[OrganizationHistoryFocusedKey.self] = newValue }
  }
}

/// Uses the focused window only. A focused native text editor owns even an empty local stack.
@MainActor
enum OrganizationHistoryNativeRouting {
  private static let emptyTextHistory = UndoManager()
  static func manager(history: OrganizationHistoryPresentation?, responder: NSResponder?) -> UndoManager? {
    if let editor = responder as? NSTextView { return editor.undoManager ?? emptyTextHistory }
    if let history { return history.nativeUndoManager }
    return responder?.undoManager
  }
}

struct OrganizationHistoryCommands: Commands {
  @FocusedValue(\.organizationHistory) private var history
  var body: some Commands {
    CommandGroup(replacing: .undoRedo) { OrganizationHistoryCommandButtons(history: history) }
  }
}

private struct OrganizationHistoryCommandButtons: View {
  let history: OrganizationHistoryPresentation?
  @State private var revision = 0
  @State private var lastRoutingState = ""
  private var manager: UndoManager? {
    _ = revision
    return OrganizationHistoryNativeRouting.manager(history: history, responder: NSApp.keyWindow?.firstResponder)
  }
  var body: some View {
    Button(manager?.undoMenuItemTitle ?? UndoManager().undoMenuItemTitle) { manager?.undo() }
      .keyboardShortcut("z", modifiers: .command)
      .disabled(manager?.canUndo != true)
    Button(manager?.redoMenuItemTitle ?? UndoManager().redoMenuItemTitle) { manager?.redo() }
      .keyboardShortcut("z", modifiers: [.command, .shift])
      .disabled(manager?.canRedo != true)
      .onReceive(NotificationCenter.default.publisher(for: NSWindow.didUpdateNotification)) { _ in
        let manager = OrganizationHistoryNativeRouting.manager(
          history: history, responder: NSApp.keyWindow?.firstResponder)
        let state = "\(manager.map(ObjectIdentifier.init).hashValue):\(manager?.canUndo == true)"
          + ":\(manager?.canRedo == true):\(manager?.undoActionName ?? ""):\(manager?.redoActionName ?? "")"
        if state != lastRoutingState { lastRoutingState = state; revision &+= 1 }
      }
      .onReceive(NotificationCenter.default.publisher(for: NSText.didChangeNotification)) { _ in revision &+= 1 }
  }
}

struct OrganizationHistoryNativeHost<Content: View>: View {
  let history: OrganizationHistoryPresentation?
  @ViewBuilder let content: Content
  var body: some View {
    content.focusedSceneValue(\.organizationHistory, history)
      .background(OrganizationHistoryWindowObserver(history: history))
  }
}

private struct OrganizationHistoryWindowObserver: NSViewRepresentable {
  let history: OrganizationHistoryPresentation?
  func makeNSView(context: Context) -> CloseObserver { CloseObserver() }
  func updateNSView(_ view: CloseObserver, context: Context) { view.history = history }

  final class CloseObserver: NSView {
    var history: OrganizationHistoryPresentation?
    private var closeObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?
    private var terminating = false
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
      if let terminationObserver { NotificationCenter.default.removeObserver(terminationObserver) }
      guard let window else { return }
      terminationObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification,
        object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.terminating = true } }
      closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
        object: window, queue: .main) { [weak self] _ in
          MainActor.assumeIsolated {
            guard let self, !self.terminating else { return }
            self.history?.disposeScene()
          }
        }
    }
    isolated deinit {
      if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
      if let terminationObserver { NotificationCenter.default.removeObserver(terminationObserver) }
    }
  }
}
#else
/// The hosting controller participates in its own scene's responder chain; text controls retain their own managers.
struct OrganizationHistoryNativeHost<Content: View>: UIViewControllerRepresentable {
  let history: OrganizationHistoryPresentation?
  @ViewBuilder let content: Content
  func makeUIViewController(context: Context) -> OrganizationHistoryHostingController<Content> {
    OrganizationHistoryHostingController(rootView: content, history: history)
  }
  func updateUIViewController(_ controller: OrganizationHistoryHostingController<Content>, context: Context) {
    controller.rootView = content
    controller.history = history
  }
}

final class OrganizationHistoryApplicationDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    OrganizationHistoryRegistry.discardSceneSessions(Set(sceneSessions.map(\.persistentIdentifier)))
  }
}

final class OrganizationHistoryHostingController<Content: View>: UIHostingController<Content> {
  var history: OrganizationHistoryPresentation? {
    didSet { recordSceneSession(); claimUnclaimedFirstResponder() }
  }
  private var responderObservers: [NSObjectProtocol] = []
  init(rootView: Content, history: OrganizationHistoryPresentation?) {
    self.history = history
    super.init(rootView: rootView)
  }
  @MainActor required dynamic init?(coder aDecoder: NSCoder) { fatalError("init(coder:) is unavailable") }
  override func viewDidLoad() {
    super.viewDidLoad()
    for name in [
      UIWindow.didBecomeKeyNotification,
      UITextView.textDidEndEditingNotification,
      UITextField.textDidEndEditingNotification,
    ] {
      responderObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil,
        queue: .main) { [weak self] notification in
          let source = notification.object as? UIView
          MainActor.assumeIsolated {
            guard let self, let window = self.viewIfLoaded?.window, let source,
                  source === window || source.window === window else { return }
            Task { @MainActor [weak self] in
              await Task.yield()
              self?.claimUnclaimedFirstResponder()
            }
          }
        })
    }
  }
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    recordSceneSession()
    claimUnclaimedFirstResponder()
  }
  private func claimUnclaimedFirstResponder() {
    guard history != nil, let window = viewIfLoaded?.window, window.isKeyWindow,
          !isFirstResponder, window.historyFirstResponder == nil else { return }
    becomeFirstResponder()
  }
  isolated deinit {
    for observer in responderObservers { NotificationCenter.default.removeObserver(observer) }
  }
  private func recordSceneSession() {
    guard isViewLoaded, let identifier = view.window?.windowScene?.session.persistentIdentifier else { return }
    history?.recordSceneSession(identifier)
  }
  private let emptyTextHistory = UndoManager()
  private var resolvingTextManager = false
  override var canBecomeFirstResponder: Bool { true }
  override var undoManager: UndoManager? {
    guard !resolvingTextManager else { return emptyTextHistory }
    if let editor = viewIfLoaded?.focusedHistoryTextResponder {
      resolvingTextManager = true
      defer { resolvingTextManager = false }
      return editor.undoManager ?? emptyTextHistory
    }
    return history?.nativeUndoManager
  }
}

private extension UIView {
  var historyFirstResponder: UIResponder? {
    if isFirstResponder { return self }
    if let controller = next as? UIViewController, controller.isFirstResponder { return controller }
    for child in subviews {
      if let responder = child.historyFirstResponder { return responder }
    }
    return nil
  }
  var focusedHistoryTextResponder: UIResponder? {
    if isFirstResponder, self is UITextView || self is UITextField { return self }
    for child in subviews {
      if let responder = child.focusedHistoryTextResponder { return responder }
    }
    return nil
  }
}
#endif
