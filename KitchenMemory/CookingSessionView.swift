// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct CookingSessionView: View {
  @Bindable var model: CookingSessionPresentationModel
  let session: CookingSessionProjection

  @State private var isShowingFinishConfirmation = false

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 8) {
          Text(session.snapshot.title)
            .font(.largeTitle.bold())
            .accessibilityHeading(.h1)
            .accessibilityIdentifier("cooking-session-shell")
          Label(lifecycleKey, systemImage: lifecycleSymbol)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("session-lifecycle")
        }

        ContentUnavailableView {
          Label("session.shell.foundation.title", systemImage: "frying.pan")
        } description: {
          Text("session.shell.foundation.message")
        }

        Spacer()

        HStack {
          Button("session.action.leave") {
            model.leaveCurrentSession()
          }
          .accessibilityIdentifier("leave-session")

          Spacer()

          if session.lifecycle == .active {
            Button("session.action.stop") {
              model.stopCurrentSession()
            }
            .accessibilityIdentifier("stop-session")
          } else if session.lifecycle == .stopped {
            Button("session.action.resume") {
              model.resumeCurrentSession()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("resume-session")
          }

          Button("session.action.finish", role: .destructive) {
            isShowingFinishConfirmation = true
          }
          .accessibilityIdentifier("finish-session")
        }
      }
      .frame(maxWidth: 760, maxHeight: .infinity, alignment: .leading)
      .padding(28)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color("AppBackground"))
      .navigationTitle("session.navigation.title")
      .alert(
        "session.finish.confirmation.title",
        isPresented: $isShowingFinishConfirmation
      ) {
        Button("action.cancel", role: .cancel) {}
        Button("session.finish.confirmation.action", role: .destructive) {
          model.finishCurrentSession()
        }
        .accessibilityIdentifier("confirm-finish-session")
      } message: {
        Text("session.finish.confirmation.message")
      }
    }
  }

  private var lifecycleKey: LocalizedStringKey {
    switch session.lifecycle {
    case .active: "session.lifecycle.active"
    case .stopped: "session.lifecycle.stopped"
    case .finished: "session.lifecycle.finished"
    }
  }

  private var lifecycleSymbol: String {
    switch session.lifecycle {
    case .active: "flame"
    case .stopped: "pause.circle"
    case .finished: "checkmark.seal"
    }
  }
}
