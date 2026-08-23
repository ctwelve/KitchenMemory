// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryLogic
import KitchenMemoryPersistence
import SwiftUI

private enum KitchenResetCopy {
  static func title(locale: Locale) -> String {
    String(localized: "Reset Kitchen?", locale: locale)
  }

  static func message(locale: Locale) -> String {
    let source = """
      All recipes, edits, revision history, imported source captures, and recipe metadata in this \
      Kitchen will be permanently deleted. Kitchen Memory will restore only the sample recipes \
      included with this version. This cannot be undone.
      """
    return String(
      localized: String.LocalizationValue(source),
      locale: locale
    )
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
  @FocusedValue(\.resetKitchenAction) private var resetKitchenAction

  var body: some Commands {
    CommandMenu("Kitchen") {
      Button("Reset Kitchen…", role: .destructive) {
        resetKitchenAction?()
      }
      .disabled(resetKitchenAction == nil)
    }
  }
}
#endif

struct KitchenSettingsView: View {
  @Bindable var model: RecipeLibraryModel
  @State private var isShowingResetConfirmation = false
  @Environment(\.locale) private var locale
#if !os(macOS)
  @Environment(\.dismiss) private var dismiss
#endif

  var body: some View {
    Form {
      if model.personalCloudStatus != .notConfigured {
        Section("iCloud Sync") {
          personalCloudStatusLabel
        }
      }

      Section("Sample Recipes") {
        samplePresenceLabel

        Text("Installation checks stable recipe identities and adds only missing samples.")
          .foregroundStyle(.secondary)

        Button(action: model.acceptSampleRecipes) {
          if model.issue == .samples {
            Text("Try Again")
          } else if model.samplePresence == .partial {
            Text("Install Missing Sample Recipes")
          } else if model.samplePresence == .complete {
            Text("Sample Recipes Installed")
          } else {
            Text("Install Sample Recipes")
          }
        }
        .disabled(model.samplePresence == .complete && model.issue != .samples)
        .accessibilityIdentifier("add-sample-recipes")
      }

      Section("Kitchen Data") {
        Text("Restore this Kitchen to the sample recipes included with the current version of Kitchen Memory.")
        .foregroundStyle(.secondary)

        Button("Reset Kitchen…", role: .destructive) {
          isShowingResetConfirmation = true
        }
        .accessibilityIdentifier("settings-reset-kitchen")

        if let issue = model.issue {
          Label(issue.message(locale: locale), systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
        }
      }
    }
    .navigationTitle("Settings")
#if os(macOS)
    .formStyle(.grouped)
    .frame(width: 480, height: 360)
    .focusedSceneValue(\.resetKitchenAction) {
      isShowingResetConfirmation = true
    }
#else
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Done") { dismiss() }
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
      Label("Checking iCloud status…", systemImage: "icloud")
        .foregroundStyle(.secondary)
    case .available:
      Label("iCloud sync is available.", systemImage: "checkmark.icloud.fill")
        .foregroundStyle(.green)
    case .syncing:
      Label("Kitchen Memory is syncing with iCloud.", systemImage: "arrow.triangle.2.circlepath.icloud")
        .foregroundStyle(.secondary)
    case .noAccount:
      Label("Sign in to iCloud to sync your recipes.", systemImage: "person.crop.circle.badge.exclamationmark")
        .foregroundStyle(.secondary)
    case .restricted:
      Label("iCloud access is restricted on this device.", systemImage: "lock.icloud")
        .foregroundStyle(.secondary)
    case .temporarilyUnavailable:
      Label("iCloud sync is temporarily unavailable.", systemImage: "exclamationmark.icloud")
        .foregroundStyle(.yellow)
    case .failed:
      Label("iCloud sync needs attention.", systemImage: "exclamationmark.icloud.fill")
        .foregroundStyle(.red)
    }
  }

  @ViewBuilder
  private var samplePresenceLabel: some View {
    switch model.samplePresence {
    case .complete:
      Label("All sample recipes are installed.", systemImage: "checkmark.circle.fill")
        .foregroundStyle(.green)
    case .partial:
      Label("Some sample recipes are missing.", systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(.yellow)
    case .none:
      Label("No sample recipes are installed.", systemImage: "xmark.circle")
        .foregroundStyle(.secondary)
    case .unavailable:
      Label("Sample recipe status is unavailable.", systemImage: "questionmark.circle")
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
      Button("Cancel", role: .cancel) {}
      Button("Reset Kitchen", role: .destructive) {
        model.resetKitchen()
      }
      .accessibilityIdentifier("confirm-reset-kitchen")
    } message: {
      Text(KitchenResetCopy.message(locale: locale))
    }
  }
}
