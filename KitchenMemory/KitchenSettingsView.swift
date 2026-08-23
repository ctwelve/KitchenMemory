// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryLogic
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
      Section("Sample Recipes") {
        if model.sampleConsent == .accepted, model.issue != .samples {
          Label("Sample recipes are enabled.", systemImage: "checkmark.circle")
            .foregroundStyle(.secondary)
        } else {
          Text("Add the sample recipes included with this version of Kitchen Memory.")
            .foregroundStyle(.secondary)

          Button(model.issue == .samples ? "Try Again" : "Add Sample Recipes") {
            model.acceptSampleRecipes()
          }
          .accessibilityIdentifier("add-sample-recipes")
        }
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
