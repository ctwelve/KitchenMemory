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

  var body: some View {
    let lifecycle = CookingSessionLifecyclePresentation(session.lifecycle)
    NavigationStack {
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

        ContentUnavailableView {
          Label(.sessionShellFoundationTitle, systemImage: "frying.pan")
        } description: {
          Text(.sessionShellFoundationMessage)
        }

        Spacer()

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
        }
      }
      .frame(maxWidth: 760, maxHeight: .infinity, alignment: .leading)
      .padding(28)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color("AppBackground"))
      .navigationTitle(.sessionNavigationTitle)
      .alert(
        .sessionFinishConfirmationTitle,
        isPresented: $isShowingFinishConfirmation
      ) {
        Button(.actionCancel, role: .cancel) {}
        Button(.sessionFinishConfirmationAction, role: .destructive) {
          model.finishCurrentSession()
        }
        .accessibilityIdentifier("confirm-finish-session")
      } message: {
        Text(.sessionFinishConfirmationMessage)
      }
    }
  }
}
