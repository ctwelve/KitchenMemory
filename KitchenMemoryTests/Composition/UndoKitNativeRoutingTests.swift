// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenMemory
import UndoKit
import XCTest
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
final class UndoKitNativeRoutingTests: XCTestCase {
  func testLocalTextUndoDoesNotConsumeCollectionHistoryAndWindowRoutesAfterFocusLeaves() async throws {
    let rig = try await UndoQualificationRig()
    addTeardownBlock { await rig.remove() }
    let commands = try rig.session.commands(for: rig.operation)
    let host = rig.host
    let field = try qualificationTitleField(rig)
    let presentation = try await QualificationNativeWindow(session: rig.session, field: field)
    defer { presentation.disconnect() }
    let before = host.values
    let after = Array(before.reversed())
    assertAccepted(await commands.submit(UndoQualificationChange(before: before, after: after)))

    XCTAssertTrue(presentation.focusScratch())
    let localManager = try XCTUnwrap(presentation.scratchUndoManager)
#if os(macOS)
    localManager.beginUndoGrouping()
#endif
    presentation.typeScratch("temporary note")
#if os(macOS)
    while localManager.groupingLevel > 0 { localManager.endUndoGrouping() }
#else
    // UIKit owns its private typing groups; draining them unbalances UITextUndoManager.
    XCTAssertTrue(localManager.canUndo)
#endif
    XCTAssertEqual(presentation.scratchText, "temporary note")
    XCTAssertTrue(presentation.windowUndoManager.canUndo)
    presentation.windowUndoManager.undo()
    await rig.session.waitForNativeOperations()
    XCTAssertEqual(presentation.scratchText, "")
    XCTAssertEqual(host.values, after, "Native text Undo must leave the accepted collection command intact")
    XCTAssertFalse(presentation.windowUndoManager.canUndo,
      "An empty local text stack must not fall through to the older collection command")
    presentation.windowUndoManager.undo()
    await rig.session.waitForNativeOperations()
    XCTAssertEqual(host.values, after)
    XCTAssertEqual(host.acceptanceCount, 1)

    XCTAssertTrue(presentation.leaveScratch())
    XCTAssertTrue(presentation.windowUndoManager.canUndo)
    presentation.windowUndoManager.undo()
    await rig.session.waitForNativeOperations()
    XCTAssertEqual(host.values, before)
    XCTAssertEqual(host.acceptanceCount, 2)
  }

  func testDifferentNativeWindowsKeepIndependentHistoryAcrossDisconnectionAndScopeDisposal() async throws {
    let first = try await UndoQualificationRig()
    let second = try await UndoQualificationRig()
    addTeardownBlock { await first.remove() }
    addTeardownBlock { await second.remove() }
    let firstWindow = try await QualificationNativeWindow(session: first.session,
      field: qualificationTitleField(first))
    defer { firstWindow.disconnect() }
    let secondWindow = try await QualificationNativeWindow(session: second.session,
      field: qualificationTitleField(second))
    defer { secondWindow.disconnect() }
    let firstBefore = first.host.values
    let secondBefore = second.host.values
    let firstAfter = Array(firstBefore.reversed())
    let secondAfter = Array(secondBefore.reversed())
    let firstCommands = try first.session.commands(for: first.operation)
    let secondCommands = try second.session.commands(for: second.operation)
    assertAccepted(await firstCommands.submit(UndoQualificationChange(before: firstBefore, after: firstAfter)))
    assertAccepted(await secondCommands.submit(UndoQualificationChange(before: secondBefore, after: secondAfter)))
    XCTAssertTrue(firstWindow.leaveScratch())
    firstWindow.windowUndoManager.undo()
    await first.session.waitForNativeOperations()
    XCTAssertEqual(first.host.values, firstBefore)
    XCTAssertEqual(second.host.values, secondAfter)
    XCTAssertTrue(secondWindow.windowUndoManager.canUndo)
    XCTAssertEqual(second.host.acceptanceCount, 1)

    // Disconnecting a presentation retains its scope's durable history and redo.
    firstWindow.disconnect()
    try await first.reopen()
    XCTAssertEqual(first.host.values, firstBefore)
    XCTAssertTrue(first.session.status.canRedo)
    let reopenedWindow = try await QualificationNativeWindow(session: first.session,
      field: qualificationTitleField(first))
    defer { reopenedWindow.disconnect() }
    XCTAssertTrue(reopenedWindow.leaveScratch())
    reopenedWindow.windowUndoManager.redo()
    await first.session.waitForNativeOperations()
    XCTAssertEqual(first.host.values, firstAfter)
    XCTAssertEqual(second.host.values, secondAfter)
    XCTAssertEqual(second.host.acceptanceCount, 1)

    try await assertScopeDisposal(first, nativeManager: reopenedWindow.windowUndoManager)
    XCTAssertEqual(second.host.values, secondAfter)
    XCTAssertTrue(secondWindow.windowUndoManager.canUndo)
    XCTAssertEqual(second.host.acceptanceCount, 1)
  }

  private func assertScopeDisposal(_ rig: UndoQualificationRig, nativeManager: UndoManager) async throws {
    let commands = try rig.session.commands(for: rig.operation)
    let before = rig.host.values
    let acceptedCount = rig.host.acceptanceCount
    let priorGeneration = try XCTUnwrap(rig.host.receiptTokens.last?.generation)
    let baseline = try JSONEncoder().encode(before)
    let generation = try rig.session.advanced.clearHistory(adopting:
      HistoryPayload(family: "kitchenmemory.qualification.baseline", data: baseline))
    XCTAssertNotEqual(generation, priorGeneration)
    XCTAssertFalse(nativeManager.canUndo)
    XCTAssertFalse(nativeManager.canRedo)
    nativeManager.undo()
    await rig.session.waitForNativeOperations()
    let staleResult = await commands.submit(UndoQualificationChange(before: before, after: Array(before.reversed())))
    guard case .unexecuted = staleResult else {
      XCTFail("Retired commands must not reach the host")
      return
    }
    XCTAssertEqual(rig.host.values, before)
    XCTAssertEqual(rig.host.acceptanceCount, acceptedCount)
  }
}

@MainActor
private func qualificationTitleField(_ rig: UndoQualificationRig) throws -> HistoryField<String> {
  let host = rig.host
  let commands = try rig.session.commands(for: rig.operation)
  let itemID = try XCTUnwrap(host.values.first?.id)
  return HistoryField<String>(id: "qualification.title", mappingID: "qualification.rename",
    codec: .json(), commands: commands, read: {
      HistoryFieldSnapshot(value: host.values.first(where: { $0.id == itemID })!.title,
        revision: Data(String(host.acceptanceCount).utf8))
    }, makeCommands: { _, title in
      let before = host.values
      let after = before.map { item in
        item.id == itemID ? UndoQualificationItem(id: item.id, title: title) : item
      }
      return [UndoQualificationChange(before: before, after: after)]
    })
}

#if canImport(AppKit)
@MainActor
private final class QualificationRoutedWindow: NSWindow {
  var historyManager: UndoManager?
  override var undoManager: UndoManager? { historyManager }
}

@MainActor
private final class QualificationNativeWindow {
  private let window: QualificationRoutedWindow
  private let editor = NativeHistoryAppKitTextView(frame: NSRect(x: 0, y: 100, width: 400, height: 90))
  private let scratch = NativeHistoryAppKitTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 90))
  private var attachment: HistoryAttachment?
  private var binding: NativeHistoryAppKitBinding?

  init(session: HistorySession, field: HistoryField<String>) async throws {
    window = QualificationRoutedWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
      styleMask: [.titled], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    editor.isRichText = false
    scratch.isRichText = false
    editor.allowsUndo = true
    scratch.allowsUndo = true
    window.contentView?.addSubview(editor)
    window.contentView?.addSubview(scratch)
    let attachment = try session.attach(owner: window)
    self.attachment = attachment
    binding = try await attachment.bindAppKit(editors: [(editor, field)], localEditors: [scratch])
    window.historyManager = attachment.undoManager
    window.makeKeyAndOrderFront(nil)
  }

  var scratchUndoManager: UndoManager? { scratch.undoManager }
  var windowUndoManager: UndoManager { window.undoManager! }
  var scratchText: String { scratch.string }
  func focusScratch() -> Bool { window.makeFirstResponder(scratch) }
  func leaveScratch() -> Bool { window.makeFirstResponder(nil) }
  func typeScratch(_ text: String) {
    scratch.insertText(text, replacementRange: NSRange(location: 0, length: 0))
    scratch.breakUndoCoalescing()
  }
  func disconnect() {
    binding?.disconnect()
    window.historyManager = nil
    window.close()
  }
}
#elseif canImport(UIKit)
@MainActor
private final class QualificationRoutedWindow: UIWindow {
  var historyManager: UndoManager?
  override var undoManager: UndoManager? { historyManager }
}

@MainActor
private final class QualificationNativeWindow {
  private let window: QualificationRoutedWindow
  private weak var previousKeyWindow: UIWindow?
  private let editor = NativeHistoryTextView(frame: CGRect(x: 0, y: 100, width: 300, height: 90))
  private let scratch = UITextView(frame: CGRect(x: 0, y: 200, width: 300, height: 90))
  private var attachment: HistoryAttachment?
  private var binding: NativeHistoryUIKitBinding?

  init(session: HistorySession, field: HistoryField<String>) async throws {
    let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive })
    previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
    window = QualificationRoutedWindow(windowScene: scene)
    let controller = UIViewController()
    window.rootViewController = controller
    controller.view.addSubview(editor)
    controller.view.addSubview(scratch)
    window.makeKeyAndVisible()
    let attachment = try session.attach(owner: window)
    self.attachment = attachment
    binding = try await attachment.bindUIKit(editors: [(editor, field)], localEditors: [scratch])
    window.historyManager = attachment.undoManager
  }

  var scratchUndoManager: UndoManager? { scratch.undoManager }
  var windowUndoManager: UndoManager { window.undoManager! }
  var scratchText: String { scratch.text ?? "" }
  func focusScratch() -> Bool { scratch.becomeFirstResponder() }
  func leaveScratch() -> Bool { !scratch.isFirstResponder || scratch.resignFirstResponder() }
  func typeScratch(_ text: String) { scratch.insertText(text) }
  func disconnect() {
    binding?.disconnect()
    window.historyManager = nil
    window.isHidden = true
    previousKeyWindow?.makeKey()
  }
}
#endif
