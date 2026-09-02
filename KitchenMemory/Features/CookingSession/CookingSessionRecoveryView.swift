// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct DeletedItemsDestinationView: View {
  @Bindable var model: CookingSessionPresentationModel
  let prepare: () -> Void
  @State private var hasPrepared = false

  var body: some View {
    CookingSessionDeletedItemsView(model: model)
      .onAppear {
        guard !hasPrepared else { return }
        hasPrepared = true
        prepare()
      }
  }
}

struct CookingSessionRecoveryDestinationView: View {
  @Bindable var model: CookingSessionPresentationModel
  let prepare: () -> Void
  @State private var hasPrepared = false

  var body: some View {
    CookingSessionRecoveryView(model: model)
      .onAppear {
        guard !hasPrepared else { return }
        hasPrepared = true
        prepare()
      }
  }
}

struct CookingSessionDeletedItemsView: View {
  @Bindable var model: CookingSessionPresentationModel
  @State private var pendingRestore: CookingSessionProjection?

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 16) {
        Text(.deletedItemsTitle)
          .font(.largeTitle.bold())
          .accessibilityHeading(.h1)
          .accessibilityIdentifier("deleted-items")
        Text(.deletedItemsRetentionMessage)
          .foregroundStyle(.secondary)
        ForEach(model.deletedSessions, id: \.id) { session in
          deletedSession(session)
        }
        ForEach(model.waitingDeletedSessions, id: \.evidence.sessionID) { item in
          waitingSession(item)
        }
        if model.deletedItemCount == 0 {
          ContentUnavailableView(
            .deletedItemsEmptyTitle,
            systemImage: "trash",
            description: Text(.deletedItemsEmptyMessage)
          )
          .frame(maxWidth: .infinity)
        }
      }
      .frame(maxWidth: 820, alignment: .leading)
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .center)
    }
    .background(Color("AppBackground"))
    .confirmationDialog(
      .sessionRestoreConfirmationTitle,
      isPresented: Binding(
        get: { pendingRestore != nil },
        set: { if !$0 { pendingRestore = nil } }
      ),
      titleVisibility: .visible
    ) {
      Button(.sessionRestoreAction) {
        if let pendingRestore { model.restoreSession(pendingRestore.id) }
        pendingRestore = nil
      }
      .accessibilityIdentifier("confirm-restore-session")
      Button(.actionCancel, role: .cancel) { pendingRestore = nil }
    } message: {
      Text(.sessionRestoreConfirmationMessage)
    }
  }

  private func deletedSession(_ session: CookingSessionProjection) -> some View {
    let lifecycle = CookingSessionLifecyclePresentation(session.lifecycle)
    return HStack(spacing: 14) {
      Image(systemName: "trash")
        .foregroundStyle(Color("IconMark"))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text(session.snapshot.title).font(.headline)
        Label(lifecycle.title, systemImage: lifecycle.symbol)
          .font(.caption)
          .foregroundStyle(.secondary)
        if case .deleted(needsAttention: true) = session.disposition {
          Label(.deletedItemsNeedsAttention, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.orange)
        }
      }
      Spacer()
      Button(.sessionRestoreAction) { pendingRestore = session }
        .accessibilityIdentifier("restore-session-\(session.id.rawValue.uuidString)")
    }
    .padding(16)
    .background(Color("ContentSurface"), in: .rect(cornerRadius: 12))
    .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color("SubtleBorder")) }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("deleted-session-\(session.id.rawValue.uuidString)")
  }

  private func waitingSession(_ item: UnavailableSession) -> some View {
    HStack(spacing: 14) {
      Image(systemName: "icloud.and.arrow.down")
        .foregroundStyle(Color("IconMark"))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text(.deletedItemsSessionFallback).font(.headline)
        Text(item.evidence.sessionID.rawValue.uuidString)
          .font(.caption.monospaced())
          .foregroundStyle(.secondary)
        Label(.deletedItemsWaiting, systemImage: "clock")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      Button(.actionTryAgain) { model.reload() }
        .accessibilityIdentifier("retry-deleted-session")
    }
    .padding(16)
    .background(Color("ContentSurface"), in: .rect(cornerRadius: 12))
    .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color("SubtleBorder")) }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("waiting-deleted-session-\(item.evidence.sessionID.rawValue.uuidString)")
  }
}

struct CookingSessionRecoveryView: View {
  @Bindable var model: CookingSessionPresentationModel
  @State private var pendingSelection: ClosureSelectionRequest?

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 16) {
        Text(.recoveryTitle)
          .font(.largeTitle.bold())
          .accessibilityHeading(.h1)
          .accessibilityIdentifier("session-recovery")
        Text(.recoveryMessage).foregroundStyle(.secondary)
        ForEach(model.waitingSessions, id: \.evidence.sessionID) { item in
          recoveryWaitingRow(item)
        }
        ForEach(model.recoverySessions, id: \.evidence.sessionID) { item in
          recoveryRow(item)
        }
        if model.recoveryItemCount == 0 {
          ContentUnavailableView(
            .recoveryEmptyTitle,
            systemImage: "wrench.and.screwdriver",
            description: Text(.recoveryEmptyMessage)
          )
          .frame(maxWidth: .infinity)
        }
      }
      .frame(maxWidth: 820, alignment: .leading)
      .padding(28)
      .frame(maxWidth: .infinity, alignment: .center)
    }
    .background(Color("AppBackground"))
    .confirmationDialog(
      .recoveryClosureConfirmationTitle,
      isPresented: Binding(
        get: { pendingSelection != nil },
        set: { if !$0 { pendingSelection = nil } }
      ),
      titleVisibility: .visible
    ) {
      Button(.recoveryClosureSelectionAction) {
        if let request = pendingSelection {
          model.selectClosure(request.closureID, for: request.recovery)
        }
        pendingSelection = nil
      }
      .accessibilityIdentifier("confirm-closure-selection")
      Button(.actionCancel, role: .cancel) { pendingSelection = nil }
    } message: {
      Text(.recoveryClosureConfirmationMessage)
    }
  }

  private func recoveryWaitingRow(_ item: UnavailableSession) -> some View {
    recoveryCard(id: item.evidence.sessionID, title: .recoveryWaitingTitle) {
      Text(.recoveryWaitingMessage).foregroundStyle(.secondary)
      Button(.actionTryAgain) { model.reload() }
        .accessibilityIdentifier("retry-waiting-session")
    }
  }

  private func recoveryRow(_ recovery: SessionRecovery) -> some View {
    recoveryCard(id: recovery.evidence.sessionID, title: .recoveryEvidenceTitle) {
      Text(recoveryExplanation(recovery)).foregroundStyle(.secondary)
      let candidates = model.closureCandidates(for: recovery)
      if !candidates.isEmpty {
        Text(.recoveryClosureSelectionTitle).font(.headline)
        ForEach(candidates, id: \.id) { closure in
          Button {
            pendingSelection = ClosureSelectionRequest(
              recovery: recovery,
              closureID: closure.id
            )
          } label: {
            VStack(alignment: .leading, spacing: 3) {
              Text(closure.finishedAt, format: .dateTime)
              Text(closure.id.rawValue.uuidString)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            }
          }
          .accessibilityIdentifier("select-closure-\(closure.id.rawValue.uuidString)")
        }
      } else {
        Button(.actionTryAgain) { model.reload() }
          .accessibilityIdentifier("retry-recovery-session")
      }
    }
  }

  private func recoveryCard<Content: View>(
    id: CookingSession.ID,
    title: LocalizedStringResource,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(title, systemImage: "exclamationmark.triangle")
        .font(.headline)
      Text(id.rawValue.uuidString)
        .font(.caption.monospaced())
        .foregroundStyle(.secondary)
      content()
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color("ContentSurface"), in: .rect(cornerRadius: 12))
    .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color("SubtleBorder")) }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("recovery-session-\(id.rawValue.uuidString)")
  }

  private func recoveryExplanation(_ recovery: SessionRecovery) -> LocalizedStringResource {
    recovery.reasons == [.competingClosures]
      ? .recoveryCompetingClosuresMessage
      : .recoveryInvariantMessage
  }
}

private struct ClosureSelectionRequest {
  let recovery: SessionRecovery
  let closureID: SessionClosure.ID
}
