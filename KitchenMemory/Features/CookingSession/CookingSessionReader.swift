// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

private struct CookingReadingOriginKey: EnvironmentKey {
  static let defaultValue: UUID? = nil
}

extension EnvironmentValues {
  var cookingReadingOrigin: UUID? {
    get { self[CookingReadingOriginKey.self] }
    set { self[CookingReadingOriginKey.self] = newValue }
  }
}

struct CookingReadingFrames: PreferenceKey {
  static let defaultValue: [SessionInstruction.ID: CGRect] = [:]
  static func reduce(value: inout [SessionInstruction.ID: CGRect], nextValue: () -> [SessionInstruction.ID: CGRect]) {
    value.merge(nextValue(), uniquingKeysWith: { _, new in new })
  }
}

/// Shared geometry/consent policy; native adapters own input delivery and actual scrolling.
@MainActor
final class CookingReaderCoordinator {
  let readingOrigin: UUID
  var frames: [SessionInstruction.ID: CGRect] = [:]
  var motion: ReadingMotionController?
  var offset: () -> Double = { 0 }
  var isReady: () -> Bool = { false }
  var save: (CookingSessionReadingPosition) -> Void = { _ in }
  private var restored = false
  private var initialPosition: CookingSessionReadingPosition?
  private var completionID: UUID?
  private var jumpID: UUID?
  private var pendingReveal: SessionInstruction.ID?
  private var animateReveal = false
  private var lastEmphasis: SessionInstruction.ID?
  private var lastSession: CookingSessionProjection?
  private var lastTextSize: DynamicTypeSize?
  private var lastReduceMotion = false
  private var lastKeepsAwake: Bool?
  private var saveTask: Task<Void, Never>?

  func prepareLayout(textSize: DynamicTypeSize, reduceMotion: Bool) {
    if lastTextSize != textSize || (reduceMotion && !lastReduceMotion) { interrupt() }
    lastTextSize = textSize
    lastReduceMotion = reduceMotion
  }

  init(readingOrigin: UUID, position: CookingSessionReadingPosition?, completion: CookingSessionReadingCompletion?) {
    self.readingOrigin = readingOrigin
    initialPosition = position
    completionID = completion?.id
  }

  func update(session: CookingSessionProjection, preference: CookingSessionReadingPreference,
              completion: CookingSessionReadingCompletion?, jump: UUID?, reduceMotion: Bool) {
    // Any non-completion projection/selection change cancels existing consent.
    let isNewCompletion = completion?.sessionID == session.id && completion?.id != completionID
      && completion?.readingOrigin == readingOrigin
    if lastSession != session || lastEmphasis != preference.emphasizedInstructionID
      || lastKeepsAwake != preference.keepsScreenAwake {
      interrupt()
    }
    lastSession = session
    lastEmphasis = preference.emphasizedInstructionID
    lastKeepsAwake = preference.keepsScreenAwake
    if isNewCompletion {
      completionID = completion?.id
      if !reduceMotion {
        pendingReveal = completion?.nextInstructionID
        animateReveal = true
      }
    }
    if jump != jumpID {
      jumpID = jump
      pendingReveal = preference.emphasizedInstructionID
      animateReveal = false
    }
  }

  func setFrames(_ value: [SessionInstruction.ID: CGRect]) {
    frames = value
    applyGeometry()
  }

  func applyGeometry() {
    guard let motion, isReady() else { return }
    if !restored {
      if let anchor = initialPosition?.instructionID, frames[anchor] == nil { return }
      restored = true
      let position = initialPosition
      let top = position?.instructionID.flatMap { frames[$0]?.minY } ?? 0
      motion.restore(to: top + (position?.offset ?? 0))
    }
    if let id = pendingReveal, let frame = frames[id] {
      pendingReveal = nil
      motion.reveal(frame, animated: animateReveal)
    }
  }

  func interrupt() {
    pendingReveal = nil
    motion?.interrupt()
  }

  /// First contact also revokes any restoration still waiting for layout.
  func takeControl() {
    restored = true
    initialPosition = nil
    interrupt()
  }

  func scrolled() {
    saveTask?.cancel()
    saveTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled else { return }
      self?.savePosition()
    }
  }

  func savePosition() {
    guard restored else { return }
    let current = offset()
    let anchor = frames.filter { $0.value.minY <= current + 1 }
      .max { $0.value.minY < $1.value.minY }
    save(.init(instructionID: anchor?.key, offset: current - (anchor?.value.minY ?? 0)))
  }

  func end() {
    interrupt()
    saveTask?.cancel()
    savePosition()
  }
}

/// Environment values explicitly cross the nested native hosting boundary.
struct CookingReaderDocument<Content: View>: View {
  let content: Content
  let locale: Locale
  let textSize: DynamicTypeSize
  let colorScheme: ColorScheme
  let direction: LayoutDirection
  let frames: ([SessionInstruction.ID: CGRect]) -> Void

  var body: some View {
    content
      .frame(maxWidth: .infinity, alignment: .leading)
      .coordinateSpace(name: "cooking-reading")
      .environment(\.locale, locale)
      .environment(\.dynamicTypeSize, textSize)
      .environment(\.colorScheme, colorScheme)
      .environment(\.layoutDirection, direction)
      .onPreferenceChange(CookingReadingFrames.self, perform: frames)
  }
}
