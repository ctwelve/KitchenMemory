// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import SwiftUI

struct CookingSessionHistoryView: View {
  @Bindable var model: CookingSessionPresentationModel
  var applyNavigationFocus: () -> Void = {}

  var body: some View {
    let scope = model.displayedHistoryScope
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 12) {
        Text(historyTitle)
          .font(.headline)
          .accessibilityHeading(.h1)
          .accessibilityIdentifier("sessions-history")

        ForEach(model.displayedHistoryGroups, id: \.lifecycle) { group in
            historySection(CookingSessionLifecyclePresentation(group.lifecycle).title,
                           identifier: "sessions-\(group.lifecycle.rawValue)") {
              ForEach(group.sessions, id: \.id) { session in
                sessionButton(session)
              }
            }
        }
        if model.displayedHistorySessions.isEmpty {
          ContentUnavailableView(
            .sessionHistoryEmptyTitle,
            systemImage: "clock.arrow.circlepath",
            description: Text(.sessionHistoryEmptyMessage)
          )
          .frame(maxWidth: .infinity)
        }
      }
      .scrollTargetLayout()
      .frame(maxWidth: 820, alignment: .leading)
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .center)
    }
    .scrollPosition(id: Binding(get: { model.navigation.historyListAnchor(for: scope) },
                                set: { model.navigation.rememberHistoryListAnchor($0, for: scope) }), anchor: .top)
    .id(scope)
    .background(Color("AppBackground"))

  }

  private var historyTitle: LocalizedStringResource {
    switch model.displayedHistoryScope {
    case .recipe: .sessionHistoryRecipeTitle
    case .all, nil: .sessionHistoryTitle
    }
  }

  private func historySection<Content: View>(
    _ title: LocalizedStringResource,
    identifier: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.subheadline)
        .accessibilityHeading(.h2)
      content()
    }
    .scrollTargetLayout()
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(identifier)
  }

  private func sessionButton(_ session: CookingSessionProjection) -> some View {
      Button {
        let selected = session.lifecycle == .finished
          ? model.observeFinishedSession(session.id) : model.selectSessionFromHistory(session.id)
        if selected { applyNavigationFocus() }
      } label: {
        CookingSessionHistoryRow(session: session)
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier(historyRowIdentifier(session))
      .id(session.id)
  }

  private func historyRowIdentifier(_ session: CookingSessionProjection) -> String {
    let prefix = session.lifecycle == .finished ? "finished-session-row" : "history-session-row"
    return "\(prefix)-\(session.id.rawValue.uuidString)"
  }
}

struct CookingSessionHistoryRow: View {
  let session: CookingSessionProjection
  @Environment(\.locale) private var locale

  var body: some View {
    let lifecycle = CookingSessionLifecyclePresentation(session.lifecycle)
    HStack(spacing: 14) {
      Image(systemName: lifecycle.symbol)
        .foregroundStyle(Color("IconMark"))
        .frame(width: 24)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text(session.snapshot.title)
          .font(.headline)
        Text(lifecycle.title)
          .font(.caption)
          .foregroundStyle(.secondary)
        if let startedAt = session.startedAt {
          Text(startedAt, format: .dateTime.year().month().day().hour().minute().second().locale(locale))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        if let outcome = session.outcome {
          Text(cookingSessionOutcomeTitle(outcome))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      Spacer()
      Image(systemName: "chevron.forward")
        .font(.caption.bold())
        .foregroundStyle(.tertiary)
        .accessibilityHidden(true)
    }
    .padding(16)
    .background(Color("ContentSurface"), in: .rect(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color("SubtleBorder"), lineWidth: 1)
    }
    .contentShape(.rect)
    .accessibilityElement(children: .combine)
  }
}

struct FinishedCookingSessionView: View {
  @Bindable var model: CookingSessionPresentationModel
  let session: CookingSessionProjection
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @State private var isShowingDeleteConfirmation = false

  var body: some View {
    GeometryReader { geometry in
      let layoutMode = CookingSessionLayoutMode.resolve(
        width: geometry.size.width,
        usesAccessibilityTextSize: dynamicTypeSize.isAccessibilitySize
      )
      VStack(spacing: 0) {
        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            header
            CookingSessionLineageView(model: model, session: session)
            FinishedSessionEntriesView(session: session)
            CookingSessionProgressView(model: model, session: session, layoutMode: layoutMode)
          }
          .frame(maxWidth: layoutMode == .wide ? 1_220 : 900, alignment: .leading)
          .padding(28)
          .frame(maxWidth: .infinity, alignment: .center)
        }
        controls
          .padding(.horizontal, 28)
          .padding(.vertical, 16)
          .background(.bar)
      }
      .background(Color("AppBackground"))
      .cookingSessionDeletionConfirmation(
        isPresented: $isShowingDeleteConfirmation,
        model: model,
        sessionID: session.id
      )
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(session.snapshot.title)
        .font(.largeTitle.bold())
        .accessibilityHeading(.h1)
        .accessibilityIdentifier("finished-session")
      Label(.sessionLifecycleFinished, systemImage: "checkmark.seal")
        .foregroundStyle(.secondary)
      Text(.sessionHistoryImmutableMessage)
        .font(.callout)
        .foregroundStyle(.secondary)
    }
  }

  private var controls: some View {
    HStack {
      Button(model.historyScope == nil ? .sessionHistoryBackRecipe : .sessionHistoryBack) {
        model.dismissObservedFinishedSession()
      }
      .accessibilityIdentifier("back-to-session-history")
      Spacer()
      Button(.sessionActionContinue) {
        model.continueSession(session.id)
      }
      .buttonStyle(.borderedProminent)
      .accessibilityIdentifier("continue-session")
      Button(.sessionDeleteAction, role: .destructive) {
        isShowingDeleteConfirmation = true
      }
      .accessibilityIdentifier("delete-session")
    }
  }

}

private struct FinishedSessionEntriesView: View {
  let session: CookingSessionProjection
  @Environment(\.locale) private var locale

  var body: some View {
    CookingSessionCard(title: .sessionEntrySection, symbol: "text.bubble") {
      if session.entries.isEmpty {
        Text(.sessionHistoryEntriesEmpty)
          .foregroundStyle(.secondary)
      } else {
        ForEach(session.entries) { entry in
          VStack(alignment: .leading, spacing: 4) {
            Text(entry.text)
              .textSelection(.enabled)
            if let target = entry.target {
              Label(targetPresentation.label(for: target), systemImage: "scope")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      LabeledContent(.sessionOutcomeSection) {
        Text(outcomeTitle)
      }
    }
  }

  private var targetPresentation: SessionEntryTargetPresentation {
    SessionEntryTargetPresentation(snapshot: session.snapshot, locale: locale)
  }

  private var outcomeTitle: LocalizedStringResource {
    session.outcome.map(cookingSessionOutcomeTitle) ?? .sessionOutcomeNone
  }
}

func cookingSessionOutcomeTitle(_ value: SessionOutcome) -> LocalizedStringResource {
  switch value {
  case .coarse(let outcome):
    switch outcome {
    case .great: .sessionOutcomeGreat
    case .okay: .sessionOutcomeOkay
    case .unsuccessful: .sessionOutcomeUnsuccessful
    }
  }
}
