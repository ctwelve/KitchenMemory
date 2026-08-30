// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct CookingSessionHistoryDestinationView: View {
  @Bindable var model: CookingSessionPresentationModel
  let prepare: () -> Void
  @State private var hasPrepared = false

  var body: some View {
    Group {
      if let finishedSession = model.observedFinishedSession {
        FinishedCookingSessionView(model: model, session: finishedSession)
      } else {
        CookingSessionHistoryView(model: model)
      }
    }
    .onAppear {
      guard !hasPrepared else { return }
      hasPrepared = true
      prepare()
    }
  }
}

struct CookingSessionHistoryView: View {
  @Bindable var model: CookingSessionPresentationModel

  private var ordinarySessions: [CookingSessionProjection] {
    model.displayedHistorySessions.filter { $0.lifecycle != .finished }
  }

  private var currentSession: CookingSessionProjection? {
    guard let current = model.currentHistorySession,
          ordinarySessions.contains(where: { $0.id == current.id })
    else { return nil }
    return current
  }

  private var recentSessions: [CookingSessionProjection] {
    model.recentHistorySessions(from: ordinarySessions, excluding: currentSession?.id)
  }

  private var finishedSessions: [CookingSessionProjection] {
    model.displayedHistorySessions.filter { $0.lifecycle == .finished }
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 24) {
        Text(historyTitle)
          .font(.largeTitle.bold())
          .accessibilityHeading(.h1)
          .accessibilityIdentifier("sessions-history")

        if let currentSession {
          historySection(.sessionHistoryCurrent, identifier: "sessions-current") {
            sessionButton(currentSession)
          }
        }
        if !recentSessions.isEmpty {
          historySection(.sessionHistoryRecent, identifier: "sessions-recent") {
            ForEach(recentSessions, id: \.id) { session in
              sessionButton(session)
            }
          }
        }
        if !finishedSessions.isEmpty {
          historySection(.sessionHistoryFinished, identifier: "sessions-finished") {
            ForEach(finishedSessions, id: \.id) { session in
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
      .frame(maxWidth: 820, alignment: .leading)
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .center)
    }
    .background(Color("AppBackground"))
  }

  private var historyTitle: LocalizedStringResource {
    switch model.historyScope {
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
        .font(.title2.bold())
        .accessibilityHeading(.h2)
      content()
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier(identifier)
  }

  private func sessionButton(_ session: CookingSessionProjection) -> some View {
    Button {
      if session.lifecycle == .finished {
        model.observeFinishedSession(session.id)
      } else {
        model.selectSession(session.id)
      }
    } label: {
      CookingSessionHistoryRow(session: session)
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(historyRowIdentifier(session))
  }

  private func historyRowIdentifier(_ session: CookingSessionProjection) -> String {
    let prefix = session.lifecycle == .finished ? "finished-session-row" : "history-session-row"
    return "\(prefix)-\(session.id.rawValue.uuidString)"
  }
}

struct CookingSessionHistoryRow: View {
  let session: CookingSessionProjection

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
  }
}

struct FinishedCookingSessionView: View {
  @Bindable var model: CookingSessionPresentationModel
  let session: CookingSessionProjection
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
            lineage
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

  @ViewBuilder
  private var lineage: some View {
    CookingSessionCard(title: .sessionHistoryLineage, symbol: "point.3.connected.trianglepath.dotted") {
      if let sourceSessionID = session.sourceSessionID,
         let sourceClosureID = session.sourceClosureID {
        lineageIdentifier(.sessionHistoryLineageSource, id: sourceSessionID.rawValue)
        lineageIdentifier(.sessionHistoryLineageClosure, id: sourceClosureID.rawValue)
      } else {
        Text(.sessionHistoryLineageOriginal)
          .foregroundStyle(.secondary)
      }
      ForEach(model.continuations(of: session.id), id: \.id) { continuation in
        lineageIdentifier(.sessionHistoryLineageContinuation, id: continuation.id.rawValue)
      }
    }
    .accessibilityIdentifier("session-lineage")
  }

  private var controls: some View {
    HStack {
      Button(.sessionHistoryBack) {
        model.dismissObservedFinishedSession()
      }
      .accessibilityIdentifier("back-to-session-history")
      Spacer()
      Button(.sessionActionContinue) {
        model.continueSession(session.id)
      }
      .buttonStyle(.borderedProminent)
      .accessibilityIdentifier("continue-session")
    }
  }

  private func lineageIdentifier(_ title: LocalizedStringResource, id: UUID) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(id.uuidString)
        .font(.caption.monospaced())
        .textSelection(.enabled)
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
    guard case let .coarse(outcome) = session.outcome else { return .sessionOutcomeNone }
    switch outcome {
    case .great: return .sessionOutcomeGreat
    case .okay: return .sessionOutcomeOkay
    case .unsuccessful: return .sessionOutcomeUnsuccessful
    }
  }
}
