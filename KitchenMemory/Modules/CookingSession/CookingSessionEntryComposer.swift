// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

private struct CookingSessionComposerOriginKey: EnvironmentKey {
  static let defaultValue: UUID? = nil
}

private struct CookingSessionNoteRequestKey: EnvironmentKey {
  static var defaultValue: (@MainActor (SessionProgressTarget) -> Void)? { nil }
}

extension EnvironmentValues {
  var cookingSessionNoteRequest: (@MainActor (SessionProgressTarget) -> Void)? {
    get { self[CookingSessionNoteRequestKey.self] }
    set { self[CookingSessionNoteRequestKey.self] = newValue }
  }

  var cookingSessionComposerOrigin: UUID? {
    get { self[CookingSessionComposerOriginKey.self] }
    set { self[CookingSessionComposerOriginKey.self] = newValue }
  }
}

/// One on-demand editor over the Session's retained local draft. Sheet dismissal
/// only changes presentation; submission and discard remain explicit actions.
struct CookingSessionEntryComposer: View {
  @Bindable var model: CookingSessionPresentationModel
  let session: CookingSessionProjection
  let close: () -> Void
  @Environment(\.locale) private var locale
  @State private var showsDiscardConfirmation = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          TextField(.sessionEntryDraftPlaceholder, text: draftText, axis: .vertical)
            .lineLimit(5...14)
            .padding(12)
            .background(.background, in: .rect(cornerRadius: 10))
            .disabled(session.lifecycle != .active || model.currentSessionHasPendingFinish)
            .accessibilityIdentifier("session-entry-draft")
          Picker(.sessionEntryTargetLabel, selection: draftTarget) {
            Text(.sessionEntryTargetNone).tag(nil as SessionProgressTarget?)
            ForEach(SessionEntryTargetPresentation(snapshot: session.snapshot, locale: locale).options) { option in
              Text(option.label).tag(option.target as SessionProgressTarget?)
            }
          }
          .disabled(session.lifecycle != .active || model.currentSessionHasPendingFinish)
          .accessibilityIdentifier("session-entry-draft-target")
          Text(.sessionEntryDraftNote)
            .font(.footnote)
            .foregroundStyle(.secondary)
          if model.currentSessionHasPendingEntrySubmission {
            Text(.sessionEntryPendingSubmission)
              .font(.callout)
            Button(.sessionSaveRetry) { model.retryPendingCommands() }
              .accessibilityIdentifier("retry-session-entry")
          } else {
            Button(.sessionEntryActionSubmit) {
              if model.submitCurrentEntryDraft(), model.currentEntryDraft?.isMeaningful != true {
                close()
              }
            }
            .buttonStyle(.borderedProminent)
            .disabled(session.lifecycle != .active || model.currentSessionHasPendingFinish
              || model.currentEntryDraft?.isMeaningful != true)
            .accessibilityIdentifier("submit-session-entry")
          }
          if let issue = model.issue, model.isShowingIssue {
            Text(issue.message).font(.callout).foregroundStyle(.secondary)
          }
          Button(.sessionEntryDraftDiscard, role: .destructive) {
            showsDiscardConfirmation = true
          }
          .disabled(model.currentEntryDraft == nil)
          .accessibilityIdentifier("discard-session-entry-draft")
        }
        .padding(24)
      }
      .navigationTitle(.sessionEntryComposerTitle)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(.actionDone) { close() }
        }
      }
      .confirmationDialog(.sessionEntryDraftDiscardTitle,
        isPresented: $showsDiscardConfirmation, titleVisibility: .visible) {
        Button(.sessionEntryDraftDiscard, role: .destructive) {
          model.discardCurrentEntryDraft()
          close()
        }
        Button(.actionCancel, role: .cancel) {}
      } message: {
        Text(.sessionEntryDraftDiscardMessage)
      }
    }
    .frame(minWidth: 300, minHeight: 400)
  }

  private var draftText: Binding<String> {
    Binding(get: { model.currentEntryDraft?.text ?? "" },
      set: { model.updateCurrentEntryDraft(text: $0, target: model.currentEntryDraft?.target) })
  }

  private var draftTarget: Binding<SessionProgressTarget?> {
    Binding(get: { model.currentEntryDraft?.target },
      set: { model.updateCurrentEntryDraft(text: model.currentEntryDraft?.text ?? "", target: $0) })
  }
}

/// Target notes stay readable in authored context as well as in the notes list.
struct CookingSessionTargetNotes: View {
  let model: CookingSessionPresentationModel
  let session: CookingSessionProjection
  let target: SessionProgressTarget
  @Environment(\.cookingSessionComposerOrigin) private var composerOrigin
  @Environment(\.cookingSessionNoteRequest) private var requestNote

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(session.entries.filter { $0.target == target }) { entry in
        Label { Text(entry.text).textSelection(.enabled) } icon: {
          Image(systemName: "note.text")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
      }
      if session.lifecycle == .active {
        Button {
          if let requestNote { requestNote(target) }
          else { model.openEntryComposer(target: target, origin: composerOrigin) }
        } label: {
          Label(.sessionEntryActionAdd, systemImage: "square.and.pencil")
        }
        .buttonStyle(.borderless)
        .disabled(model.currentSessionHasPendingFinish)
        .frame(minHeight: 44)
        .accessibilityIdentifier("session-target-note-\(targetID)")
      }
    }
    .accessibilityElement(children: .contain)
  }

  private var targetID: String {
    switch target {
    case .ingredient(let id): id.rawValue.uuidString
    case .instruction(let id): id.rawValue.uuidString
    }
  }
}
