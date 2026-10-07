// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct CookingSessionOutcomePicker: View {
  let model: CookingSessionPresentationModel
  let session: CookingSessionProjection

  var body: some View {
    Picker(.sessionOutcomeSection, selection: selection) {
      Text(.sessionOutcomeNone).tag(nil as SessionOutcome.CoarseValue?)
      Text(.sessionOutcomeGreat).tag(SessionOutcome.CoarseValue.great as SessionOutcome.CoarseValue?)
      Text(.sessionOutcomeOkay).tag(SessionOutcome.CoarseValue.okay as SessionOutcome.CoarseValue?)
      Text(.sessionOutcomeUnsuccessful).tag(SessionOutcome.CoarseValue.unsuccessful as SessionOutcome.CoarseValue?)
    }
    .disabled(session.lifecycle != .active || model.currentSessionHasPendingFinish)
    .accessibilityIdentifier("session-outcome")
  }

  private var selection: Binding<SessionOutcome.CoarseValue?> {
    Binding(get: {
      guard case let .coarse(value) = session.outcome else { return nil }
      return value
    }, set: { value in
      if let value { model.setOutcome(.coarse(value)) }
      else if session.outcome != nil { model.clearOutcome() }
    })
  }
}

/// Completing the slide provides consent. A separate named button supplies the
/// same command through a confirmation dialog for keyboard and assistive input.
struct CookingSessionSlideToFinish: View {
  let isEnabled: Bool
  let finish: () -> Void
  @State private var translation: CGFloat = 0

  var body: some View {
    GeometryReader { geometry in
      let travel = max(1, geometry.size.width - 56)
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 28).fill(.secondary.opacity(0.12))
        Text(.sessionFinishSlide)
          .font(.callout.weight(.semibold))
          .frame(maxWidth: .infinity)
          .padding(.leading, 44)
        Image(systemName: "chevron.right.2")
          .font(.title3.bold())
          .frame(width: 52, height: 52)
          .background(isEnabled ? Color.accentColor : Color.secondary, in: .circle)
          .foregroundStyle(.white)
          .offset(x: translation)
          .gesture(DragGesture(minimumDistance: 12)
            .onChanged { value in
              guard isEnabled,
                abs(value.translation.width) > abs(value.translation.height) else { return }
              translation = min(travel, max(0, value.translation.width))
            }
            .onEnded { value in
              let didComplete = isEnabled && translation >= travel * 0.95
                && abs(value.translation.width) > abs(value.translation.height)
              translation = 0
              if didComplete { finish() }
            })
      }
      .opacity(isEnabled ? 1 : 0.5)
    }
    .frame(width: 240, height: 56)
    .accessibilityHidden(true)
    .onChange(of: isEnabled) { _, _ in translation = 0 }
  }
}

/// Failures remain alongside the recipe. Retry always acts on retained work.
struct CookingSessionSaveStatus: View {
  let model: CookingSessionPresentationModel

  var body: some View {
    if model.currentSessionHasPendingWork || model.isShowingIssue {
      VStack(alignment: .leading, spacing: 8) {
        if model.currentSessionHasPendingFinish {
          Label(.sessionFinishPending, systemImage: "clock")
            .font(.callout.bold())
        } else if model.currentSessionHasPendingWork {
          Text(.sessionFinishBlocked).font(.callout)
        }
        if let issue = model.issue, model.isShowingIssue {
          Text(issue.message).font(.callout).foregroundStyle(.secondary)
        }
        Button(.sessionSaveRetry) {
          if model.currentSessionHasPendingWork { model.retryPendingCommands() }
          else { model.retryCurrentIssue() }
        }
          .accessibilityIdentifier("retry-session-save")
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("session-save-status")
    }
  }
}
