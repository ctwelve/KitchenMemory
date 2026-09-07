// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI
#if os(macOS)
import AppKit
#endif

private enum KitchenResetCopy {
  static func title(locale: Locale) -> String {
    LocalizedStringResource.settingsResetConfirmationTitle.localized(for: locale)
  }

  static func message(locale: Locale) -> String {
    LocalizedStringResource.settingsResetConfirmationMessage.localized(for: locale)
  }
}

struct ResetKitchenActionKey: FocusedValueKey {
  typealias Value = () -> Void
}

extension FocusedValues {
  var resetKitchenAction: (() -> Void)? {
    get { self[ResetKitchenActionKey.self] }
    set { self[ResetKitchenActionKey.self] = newValue }
  }
}

#if os(macOS)
struct KitchenCommands: Commands {
  let model: RecipeLibraryModel?
  @Environment(\.locale) private var locale
  @FocusedValue(\.resetKitchenAction) private var resetKitchenAction

  var body: some Commands {
    CommandMenu(.menuKitchenTitle) {
      Button(.settingsResetAction, role: .destructive) {
        if let resetKitchenAction {
          resetKitchenAction()
        } else if let model {
          confirmReset(model)
        }
      }
      .disabled(model?.startupState != .ready)
    }
  }

  private func confirmReset(_ model: RecipeLibraryModel) {
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = KitchenResetCopy.title(locale: locale)
    alert.informativeText = KitchenResetCopy.message(locale: locale)
    alert.addButton(withTitle: LocalizedStringResource.actionCancel.localized(for: locale))
    let reset = alert.addButton(
      withTitle: LocalizedStringResource.settingsResetConfirmationAction.localized(for: locale)
    )
    reset.hasDestructiveAction = true
    // Cancel is the default; Reset requires an explicit destructive choice.
    guard alert.runModal() == .alertSecondButtonReturn else { return }
    if !model.resetKitchen() {
      let failure = NSAlert()
      failure.alertStyle = .warning
      failure.messageText = RecipeLibraryIssue.reset.message(locale: locale)
      failure.addButton(withTitle: LocalizedStringResource.actionCancel.localized(for: locale))
      failure.runModal()
    }
  }
}
#endif

struct KitchenSettingsView: View {
  @State private var sampleRemoval: SamplePackCommand?

  @Bindable var model: RecipeLibraryModel
  let cloudSyncSettings: CloudSyncSettings?
  @State private var isShowingResetConfirmation = false
  @State private var isShowingCloudReconnectionConfirmation = false
  @Environment(\.locale) private var locale
#if !os(macOS)
  @Environment(\.dismiss) private var dismiss
#endif

  var body: some View {
    Form {
      if let cloudSyncSettings {
        Section(.settingsIcloudSection) {
          Toggle(
            .settingsIcloudToggle,
            isOn: Binding(
              get: { cloudSyncSettings.isEnabled },
              set: { newValue in
                if cloudSyncSettings.requestChange(to: newValue)
                  == .requiresReconnectionConfirmation {
                  isShowingCloudReconnectionConfirmation = true
                }
              }
            )
          )
          .accessibilityIdentifier("settings-icloud-sync")
          .accessibilityLabel(Text(.settingsIcloudToggle))
          .alert(
            .settingsIcloudReconnectTitle,
            isPresented: $isShowingCloudReconnectionConfirmation
          ) {
            Button(.actionCancel, role: .cancel) {}
            Button(.settingsIcloudReconnectAction) {
              cloudSyncSettings.confirmReconnection()
            }
            .accessibilityIdentifier("confirm-icloud-reconnection")
          } message: {
            Text(.settingsIcloudReconnectMessage)
          }

          Text(.settingsIcloudSummary)
            .foregroundStyle(.secondary)

          if cloudSyncSettings.requiresRelaunch {
            Label(
              cloudSyncSettings.isEnabled
                ? LocalizedStringResource.settingsIcloudPendingEnable
                : LocalizedStringResource.settingsIcloudPendingDisable,
              systemImage: "arrow.clockwise"
            )
            .foregroundStyle(.secondary)
          } else if cloudSyncSettings.isEnabled {
            personalCloudStatusLabel
            if model.synchronizationEvidenceIsStale {
              Label(.settingsIcloudStaleEvidence,
                    systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .accessibilityIdentifier("icloud-stale-evidence-warning")
            }
          } else {
            Label(.settingsIcloudStatusDisabled, systemImage: "icloud.slash")
              .foregroundStyle(.secondary)
          }
        }
      }

      Section(.settingsSamplesSection) {
        samplePresenceLabel

        Text(.settingsSamplesInstallationMessage)
          .foregroundStyle(.secondary)

        Toggle(.settingsSamplesEnabled, isOn: Binding(
          get: { model.samplePackStatus?.isEnabled ?? false },
          set: { enabled in
            if enabled { model.acceptSampleRecipes() } else { sampleRemoval = model.prepareSamplePackRemoval() }
          }
        ))
        .disabled(model.samplePackStatus == nil || model.pendingSamplePack != nil)
        .accessibilityIdentifier("sample-pack-enabled")
        if let status = model.samplePackStatus {
          LabeledContent(.settingsSamplesEdited, value: status.edited.formatted())
          LabeledContent(.settingsSamplesDeleted, value: status.deleted.formatted())
          LabeledContent(.settingsSamplesUnavailable, value: status.unavailable.formatted())
          if status.isEnabled, status.installed < status.total {
            Button(.settingsSamplesActionInstallMissing, action: model.acceptSampleRecipes)
              .disabled(model.pendingSamplePack != nil)
          }
        }
        if model.issue == .samples {
          Button(.actionTryAgain, action: model.retryCurrentIssue)
        } else if model.samplePackStatus == nil {
          Button(.actionTryAgain, action: model.reload)
        }
        Text(.settingsSamplesIntentMessage).foregroundStyle(.secondary)
          .confirmationDialog(.settingsSamplesRemoveTitle, isPresented: Binding(
            get: { sampleRemoval != nil }, set: { if !$0 { sampleRemoval = nil } }
          )) {
            Button(.settingsSamplesRemoveAction, role: .destructive) {
              if let sampleRemoval { model.confirmSamplePackRemoval(sampleRemoval) }
              sampleRemoval = nil
            }
          } message: {
            if let sampleRemoval {
              Text(.settingsSamplesRemoveMessage)
              Text(sampleRemoval.removalIDs.count.formatted())
            }
          }

      }

      Section(.settingsDataSection) {
        Text(.settingsResetSummary)
        .foregroundStyle(.secondary)

        Button(.settingsResetAction, role: .destructive) {
          isShowingResetConfirmation = true
        }
        .accessibilityIdentifier("settings-reset-kitchen")

        if let issue = model.issue {
          Label(issue.message(locale: locale), systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
        }
      }

      Section {
        NavigationLink {
          PrivacyDisplayView()
        } label: {
          Label {
            VStack(alignment: .leading, spacing: 2) {
              Text(.privacyTitle)
              Text(.settingsPrivacySummary)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          } icon: {
            Image(systemName: "hand.raised.fill")
              .foregroundStyle(.tint)
          }
        }
        .accessibilityIdentifier("settings-privacy")
      }
    }
    .navigationTitle(.settingsTitle)
#if os(macOS)
    .formStyle(.grouped)
    .frame(width: 480, height: 460)
    .focusedSceneValue(\.resetKitchenAction) {
      isShowingResetConfirmation = true
    }
#else
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button(.actionDone) { dismiss() }
          .help(Text(.actionDone))
      }
    }
#endif
    .kitchenResetConfirmation(
      isPresented: $isShowingResetConfirmation,
      model: model,
      locale: locale
    )
  }

  @ViewBuilder
  private var personalCloudStatusLabel: some View {
    switch model.personalCloudStatus {
    case .notConfigured:
      EmptyView()
    case .checking:
      Label(.settingsIcloudStatusChecking, systemImage: "icloud")
        .foregroundStyle(.secondary)
    case .available:
      Label(.settingsIcloudStatusAvailable, systemImage: "checkmark.icloud.fill")
        .foregroundStyle(.green)
    case .syncing:
      Label(.settingsIcloudStatusSyncing, systemImage: "arrow.triangle.2.circlepath.icloud")
        .foregroundStyle(.secondary)
    case .noAccount:
      Label(.settingsIcloudStatusNoAccount, systemImage: "person.crop.circle.badge.exclamationmark")
        .foregroundStyle(.secondary)
    case .restricted:
      Label(.settingsIcloudStatusRestricted, systemImage: "lock.icloud")
        .foregroundStyle(.secondary)
    case .temporarilyUnavailable:
      Label(.settingsIcloudStatusTemporarilyUnavailable, systemImage: "exclamationmark.icloud")
        .foregroundStyle(.yellow)
    case .failed:
      Label(.settingsIcloudStatusFailed, systemImage: "exclamationmark.icloud.fill")
        .foregroundStyle(.red)
    }
  }

  @ViewBuilder
  private var samplePresenceLabel: some View {
    switch model.samplePresence {
    case .complete:
      Label(.settingsSamplesStatusComplete, systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)
    case .partial:
      Label(.settingsSamplesStatusPartial, systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(.yellow)
    case .none:
      Label(.settingsSamplesStatusNone, systemImage: "xmark.circle")
        .foregroundStyle(.secondary)
    case .unavailable:
      Label(.settingsSamplesStatusUnavailable, systemImage: "questionmark.circle")
        .foregroundStyle(.secondary)
    }
  }
}

extension View {
  func kitchenResetConfirmation(
    isPresented: Binding<Bool>,
    model: RecipeLibraryModel,
    locale: Locale
  ) -> some View {
    alert(KitchenResetCopy.title(locale: locale), isPresented: isPresented) {
      Button(.actionCancel, role: .cancel) {}
      Button(.settingsResetConfirmationAction, role: .destructive) {
        model.resetKitchen()
      }
      .accessibilityIdentifier("confirm-reset-kitchen")
    } message: {
      Text(KitchenResetCopy.message(locale: locale))
    }
  }
}
