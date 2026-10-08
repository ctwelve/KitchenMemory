// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Accessibility
import Foundation
import KitchenKit
import SwiftUI

struct CookingSessionReadingSurface<Context: View>: View {
  let model: CookingSessionPresentationModel
  let session: CookingSessionProjection
  let layoutMode: CookingSessionLayoutMode
  @ViewBuilder let context: Context
  @State private var showsIngredients = false
  @State private var showsScaling = false
  @State private var deferredNoteTarget: SessionProgressTarget?
  @State private var jump: UUID?
  @State private var isVisible = false
  @State private var awake = ScreenAwakeController()
  @State private var readingOrigin = UUID()
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.locale) private var locale
  @Environment(\.cookingSessionComposerOrigin) private var composerOrigin

  private var preference: CookingSessionReadingPreference { model.readingPreference(for: session) }

  var body: some View {
    VStack(spacing: 0) {
      readingControls
        .padding()
      HStack(alignment: .top, spacing: 0) {
        if layoutMode == .wide {
          ScrollView {
            CookingSessionIngredientList(model: model, session: session).padding(20)
          }
          .frame(width: 340)
          Divider()
        }
        NativeCookingReader(session: session, readingOrigin: readingOrigin, preference: preference,
          completion: model.readingCompletion, jump: jump,
          isForeground: scenePhase == .active && !showsIngredients && !showsScaling && !isShowingOwnEntryComposer,
          save: { model.rememberReadingPosition($0, in: session) }, content: {
          VStack(alignment: .leading, spacing: 24) {
            Text(session.snapshot.title)
              .font(.largeTitle.bold())
              .accessibilityHeading(.h1)
              .accessibilityIdentifier("cooking-session-shell")
            CookingSessionScaleSummary(session: session) { showsScaling = true }
            CookingSessionScalingExplanation(model: model, session: session)
            let lifecycle = CookingSessionLifecyclePresentation(session.lifecycle)
            Label(lifecycle.title, systemImage: lifecycle.symbol)
              .foregroundStyle(.secondary)
              .accessibilityIdentifier("session-lifecycle")
            context
            CookingSessionSnapshotContext(snapshot: session.snapshot, showsYield: false)
            CookingSessionMethodGuidance(session: session)
            CookingSessionInstructionList(model: model, session: session)
            CookingSessionEntriesView(model: model, session: session)
          }
          .frame(maxWidth: 760, alignment: .leading)
          .padding(24)
          .frame(maxWidth: .infinity)
          .environment(\.cookingReadingOrigin, readingOrigin)
          .environment(\.cookingSessionComposerOrigin, composerOrigin)
        })
        .accessibilityIdentifier("cooking-session-scroll")
      }
    }
    .sheet(isPresented: $showsIngredients, onDismiss: openDeferredIngredientNote) {
      NavigationStack {
        ScrollView { CookingSessionIngredientList(model: model, session: session).padding() }
          .environment(\.cookingSessionComposerOrigin, composerOrigin)
          .environment(\.cookingSessionNoteRequest, requestIngredientNote)
          .navigationTitle(.sessionProgressIngredients)
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button(.actionDone) { showsIngredients = false }
            }
          }
      }
      .frame(minWidth: 300, minHeight: 400)
    }
    .sheet(isPresented: $showsScaling) {
      CookingSessionScalingView(model: model, session: session, close: { showsScaling = false })
    }
    .onAppear {
      model.prepareReadingPreference(for: session)
      isVisible = true
      updateAwake()
    }
    .onDisappear { isVisible = false; awake.end() }
    .onChange(of: scenePhase) { _, _ in updateAwake() }
    .onChange(of: session.lifecycle) { _, _ in updateAwake() }
    .onChange(of: preference.keepsScreenAwake) { _, _ in updateAwake() }
    .onChange(of: model.readingCompletion?.id) { _, _ in announceCompletion() }
  }

  private func requestIngredientNote(_ target: SessionProgressTarget) {
    deferredNoteTarget = target
    showsIngredients = false
  }

  private func openDeferredIngredientNote() {
    guard let target = deferredNoteTarget else { return }
    deferredNoteTarget = nil
    model.openEntryComposer(target: target, origin: composerOrigin)
  }

  private var isShowingOwnEntryComposer: Bool {
    model.isShowingEntryComposer && model.entryComposerOrigin == composerOrigin
  }

  private var readingControls: some View {
    ViewThatFits(in: .horizontal) {
      HStack { ingredientAccess; jumpControl; Spacer(); awakeControl }
      VStack(alignment: .leading) {
        HStack { ingredientAccess; jumpControl }
        awakeControl
      }
    }
  }

  @ViewBuilder private var ingredientAccess: some View {
    if layoutMode != .wide {
      Button { showsIngredients = true } label: {
        Label(.sessionProgressIngredients, systemImage: "carrot")
      }
      .accessibilityIdentifier("session-reading-ingredients")
    }
  }

  private var jumpControl: some View {
    Button(.sessionReadingJump) { jump = UUID() }
      .disabled(preference.emphasizedInstructionID == nil)
      .accessibilityIdentifier("session-reading-jump")
  }

  private var awakeControl: some View {
    Toggle(.sessionReadingKeepAwake, isOn: Binding(
      get: { preference.keepsScreenAwake },
      set: { model.setKeepsScreenAwake($0, in: session) }))
      .toggleStyle(.switch)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityLabel(Text(.sessionReadingKeepAwake))
      .accessibilityIdentifier("session-reading-keep-awake")
  }

  private func updateAwake() {
    awake.update(isVisible: isVisible, isForeground: scenePhase == .active,
      lifecycle: session.lifecycle, keepsAwake: preference.keepsScreenAwake)
  }

  private func announceCompletion() {
    guard let completion = model.readingCompletion, completion.sessionID == session.id,
          completion.readingOrigin == readingOrigin else { return }
    let message: LocalizedStringResource
    if let next = completion.nextNumber {
      message = .sessionReadingCompletedNext(completed: completion.completedNumber, next: next)
    } else {
      message = .sessionReadingCompletedLast(completed: completion.completedNumber)
    }
    AccessibilityNotification.Announcement(message.localized(for: locale)).post()
  }
}
