// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI

private enum KitchenResetCopy {
  static let title = "Reset Kitchen?"
  static let message = """
    All recipes, edits, revision history, imported source captures, and recipe metadata in this \
    Kitchen will be permanently deleted. Kitchen Memory will restore only the sample recipes \
    included with this version. This cannot be undone.
    """
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
#if !os(macOS)
  @Environment(\.dismiss) private var dismiss
#endif

  var body: some View {
    Form {
      Section("Kitchen Data") {
        Text(
          "Restore this Kitchen to the sample recipes included with the current version of "
            + "Kitchen Memory."
        )
        .foregroundStyle(.secondary)

        Button("Reset Kitchen…", role: .destructive) {
          isShowingResetConfirmation = true
        }
        .accessibilityIdentifier("settings-reset-kitchen")

        if let errorMessage = model.errorMessage {
          Label(errorMessage, systemImage: "exclamationmark.triangle")
            .foregroundStyle(.red)
        }
      }
    }
    .navigationTitle("Settings")
#if os(macOS)
    .formStyle(.grouped)
    .frame(width: 480, height: 260)
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
      model: model
    )
  }
}

extension View {
  func kitchenResetConfirmation(
    isPresented: Binding<Bool>,
    model: RecipeLibraryModel
  ) -> some View {
    alert(KitchenResetCopy.title, isPresented: isPresented) {
      Button("Cancel", role: .cancel) {}
      Button("Reset Kitchen", role: .destructive) {
        model.resetKitchen()
      }
      .accessibilityIdentifier("confirm-reset-kitchen")
    } message: {
      Text(KitchenResetCopy.message)
    }
  }
}
