// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

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

struct CookingSessionView: View {
  @Bindable var model: CookingSessionPresentationModel
  let session: CookingSessionProjection

  @State private var isShowingFinishConfirmation = false
  @State private var isShowingDraftFinishOptions = false
  @State private var isShowingDeleteConfirmation = false
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  var body: some View {
    let lifecycle = CookingSessionLifecyclePresentation(session.lifecycle)
    NavigationStack {
      GeometryReader { geometry in
        let layoutMode = CookingSessionLayoutMode.resolve(
          width: geometry.size.width,
          usesAccessibilityTextSize: dynamicTypeSize.isAccessibilitySize
        )
        VStack(spacing: 0) {
          ScrollView {
            VStack(alignment: .leading, spacing: 24) {
              VStack(alignment: .leading, spacing: 8) {
                Text(session.snapshot.title)
                  .font(.largeTitle.bold())
                  .accessibilityHeading(.h1)
                  .accessibilityIdentifier("cooking-session-shell")
                Label(lifecycle.title, systemImage: lifecycle.symbol)
                  .foregroundStyle(.secondary)
                  .accessibilityIdentifier("session-lifecycle")
              }

              if model.currentSessionNeedsStaleNudge {
                CookingSessionStaleNudge(model: model, session: session)
              }

              CookingSessionEntriesView(model: model, session: session)

              CookingSessionProgressView(
                model: model,
                session: session,
                layoutMode: layoutMode
              )
            }
            .frame(maxWidth: layoutMode == .wide ? 1_220 : 900, alignment: .leading)
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .center)
          }
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
          if model.currentEntryDraft?.isMeaningful == true {
            isShowingDraftFinishOptions = true
          } else {
            model.finishCurrentSession()
          }
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
        Button(.sessionFinishDraftSubmit) {
          model.submitCurrentEntryDraftAndFinish()
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
      .cookingSessionDeletionConfirmation(
        isPresented: $isShowingDeleteConfirmation,
        model: model,
        sessionID: session.id
      )
    }
  }

  private var lifecycleControls: some View {
    HStack {
      Button(.sessionActionLeave) {
        model.leaveCurrentSession()
      }
      .accessibilityIdentifier("leave-session")

      Spacer()

      if session.lifecycle == .active {
        Button(.sessionActionStop) {
          model.stopCurrentSession()
        }
        .accessibilityIdentifier("stop-session")
      } else if session.lifecycle == .stopped {
        Button(.sessionActionResume) {
          model.resumeCurrentSession()
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("resume-session")
      }

      Button(.sessionActionFinish, role: .destructive) {
        isShowingFinishConfirmation = true
      }
      .accessibilityIdentifier("finish-session")

      Button(.sessionDeleteAction, role: .destructive) {
        isShowingDeleteConfirmation = true
      }
      .accessibilityIdentifier("delete-session")
    }
  }

  private func copyDraftThenFinish() {
    model.copyCurrentEntryDraftAndFinish(using: CookingSessionClipboard.copy)
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
