// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import SwiftUI

struct CookingSessionLifecyclePresentation {
  let title: LocalizedStringResource
  let symbol: String

  init(_ lifecycle: SessionLifecycle) {
    switch lifecycle {
    case .active:
      title = .sessionLifecycleActive
      symbol = "flame"
    case .stopped:
      title = .sessionLifecycleStopped
      symbol = "pause.circle"
    case .finished:
      title = .sessionLifecycleFinished
      symbol = "checkmark.seal"
    }
  }
}

/// Renders a supplied Session projection and submits explicit user intentions.
///
/// `@Bindable` exposes the retained model to controls; the confirmation `@State`
/// values belong to this view's identity. Appearing, disappearing, or resizing
/// this interface does not authorize a Session lifecycle transition.
struct CookingSessionView: View {
  @Bindable var model: CookingSessionPresentationModel
  let session: CookingSessionProjection
  let embedsInNavigationStack: Bool
  let leaveSession: () -> Void

  @State private var isShowingFinishConfirmation = false
  @State private var isShowingDraftFinishOptions = false
  @State private var isShowingDeleteConfirmation = false
  @State private var composerOrigin = UUID()
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  init(
    model: CookingSessionPresentationModel,
    session: CookingSessionProjection,
    embedsInNavigationStack: Bool = true,
    leaveSession: (() -> Void)? = nil
  ) {
    self.model = model
    self.session = session
    self.embedsInNavigationStack = embedsInNavigationStack
    self.leaveSession = leaveSession ?? { model.leaveCurrentSession() }
  }

  var body: some View {
    CookingSessionNavigationContainer(embedsInNavigationStack: embedsInNavigationStack) {
      GeometryReader { geometry in
        let layoutMode = CookingSessionLayoutMode.resolve(
          width: geometry.size.width,
          usesAccessibilityTextSize: dynamicTypeSize.isAccessibilitySize
        )
        VStack(spacing: 0) {
          CookingSessionReadingSurface(model: model, session: session, layoutMode: layoutMode) {
            if model.currentSessionNeedsStaleNudge {
              CookingSessionStaleNudge(model: model, session: session)
            }
            if session.sourceSessionID != nil {
              CookingSessionLineageView(model: model, session: session)
            }
          }
          .environment(\.cookingSessionComposerOrigin, composerOrigin)
          lifecycleControls
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(.bar)
        }
        .background(Color("AppBackground"))
      }
      .navigationTitle(.sessionNavigationTitle)
      .alert(
        .sessionFinishConfirmationTitle,
        isPresented: $isShowingFinishConfirmation
      ) {
        Button(.actionCancel, role: .cancel) {}
        Button(.sessionFinishConfirmationAction, role: .destructive) {
          requestFinish()
        }
        .accessibilityIdentifier("confirm-finish-session")
      } message: {
        Text(.sessionFinishConfirmationMessage)
      }
      .confirmationDialog(
        .sessionFinishDraftTitle,
        isPresented: $isShowingDraftFinishOptions,
        titleVisibility: .visible
      ) {
        if session.lifecycle == .stopped {
          Button(.sessionFinishDraftResume) { model.resumeToEditCurrentEntryDraft(origin: composerOrigin) }
        } else {
          Button(.sessionFinishDraftSubmit) { model.submitCurrentEntryDraftAndFinish() }
        }
        Button(.sessionFinishDraftCopy) {
          copyDraftThenFinish()
        }
        Button(.sessionFinishDraftDiscard, role: .destructive) {
          model.finishDiscardingCurrentEntryDraft()
        }
        Button(.actionCancel, role: .cancel) {}
      } message: {
        Text(.sessionFinishDraftMessage)
      }
      .sheet(isPresented: entryComposerIsPresented) {
        CookingSessionEntryComposer(model: model, session: session,
          close: { entryComposerIsPresented.wrappedValue = false })
      }
      .cookingSessionDeletionConfirmation(
        isPresented: $isShowingDeleteConfirmation,
        model: model,
        sessionID: session.id
      )
    }
  }

  /// The model owns one shared draft; this view owns the window that displays
  /// its editor. Dismissing an old sheet cannot close another window's request.
  private var entryComposerIsPresented: Binding<Bool> {
    Binding(get: {
      model.isShowingEntryComposer && model.entryComposerOrigin == composerOrigin
    }, set: { isPresented in
      guard model.entryComposerOrigin == composerOrigin else { return }
      if !isPresented { model.dismissEntryComposer(origin: composerOrigin) }
    })
  }

  private var lifecycleControls: some View {
    VStack(alignment: .leading, spacing: 12) {
      CookingSessionSaveStatus(model: model)
      CookingSessionOutcomePicker(model: model, session: session)
      ViewThatFits(in: .horizontal) {
        HStack { navigationActions; Spacer(); finishActions }
        VStack(alignment: .leading, spacing: 12) {
          navigationActions
          finishActions
        }
      }
    }
  }

  private var navigationActions: some View {
    HStack {
      Button(.sessionActionLeave) { leaveSession() }
        .accessibilityIdentifier("leave-session")
      if session.lifecycle == .stopped {
        Button(.sessionActionResume) { model.resumeCurrentSession() }
          .buttonStyle(.borderedProminent)
          .disabled(model.currentSessionHasPendingFinish)
          .accessibilityIdentifier("resume-session")
      }
      Menu {
        if session.lifecycle == .active {
          Button(.sessionActionStop) { model.stopCurrentSession() }
            .disabled(model.currentSessionHasPendingFinish)
            .accessibilityIdentifier("stop-session")
        }
        Button(.sessionDeleteAction, role: .destructive) {
          isShowingDeleteConfirmation = true
        }
        .accessibilityIdentifier("delete-session")
      } label: {
        Label(.sessionLifecycleMoreActions, systemImage: "ellipsis.circle")
      }
      .accessibilityIdentifier("session-lifecycle-menu")
    }
  }

  @ViewBuilder
  private var finishActions: some View {
    if !model.currentSessionHasPendingFinish {
      ViewThatFits(in: .horizontal) {
        HStack { finishSlide; namedFinishAction }
        VStack(alignment: .leading) { finishSlide; namedFinishAction }
      }
    }
  }

  private var finishSlide: some View {
    CookingSessionSlideToFinish(isEnabled: canFinish, finish: requestFinish)
  }

  private var namedFinishAction: some View {
    Button(.sessionActionFinish) { isShowingFinishConfirmation = true }
      .disabled(!canFinish)
      .accessibilityIdentifier("finish-session")
  }

  private var canFinish: Bool {
    session.lifecycle != .finished && !model.hasPendingDeliveryWork
  }

  private func requestFinish() {
    guard canFinish else { return }
    if model.currentEntryDraft?.isMeaningful == true {
      isShowingDraftFinishOptions = true
    } else {
      model.finishCurrentSession()
    }
  }

  private func copyDraftThenFinish() {
    model.copyCurrentEntryDraftAndFinish(using: CookingSessionClipboard.copy)
  }
}

private struct CookingSessionNavigationContainer<Content: View>: View {
  let embedsInNavigationStack: Bool
  let content: Content

  init(
    embedsInNavigationStack: Bool,
    @ViewBuilder content: () -> Content
  ) {
    self.embedsInNavigationStack = embedsInNavigationStack
    self.content = content()
  }

  @ViewBuilder
  var body: some View {
    if embedsInNavigationStack {
      NavigationStack { content }
    } else {
      content
    }
  }
}

private struct CookingSessionStaleNudge: View {
  let model: CookingSessionPresentationModel
  let session: CookingSessionProjection

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Label(.sessionStaleTitle, systemImage: "clock.badge.questionmark")
        .font(.headline)
      Text(.sessionStaleMessage)
        .font(.callout)
        .foregroundStyle(.secondary)
      HStack {
        if session.lifecycle == .active {
          Button(.sessionActionStop) { model.stopCurrentSession() }
            .accessibilityIdentifier("stale-stop-session")
        } else {
          Button(.sessionActionResume) { model.resumeCurrentSession() }
            .accessibilityIdentifier("stale-resume-session")
        }
        Button(.sessionStaleActionNew) {
          model.leaveCurrentSession()
          model.showRecipes()
        }
        .accessibilityIdentifier("stale-new-session")
        Spacer()
        Button(.sessionStaleActionDismiss) { model.dismissStaleSessionNudge() }
          .accessibilityIdentifier("dismiss-stale-session")
      }
      .buttonStyle(.borderless)
    }
    .padding(16)
    .background(Color("ContentSurface"), in: .rect(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color("SubtleBorder"), lineWidth: 1)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("stale-session-nudge")
  }
}
