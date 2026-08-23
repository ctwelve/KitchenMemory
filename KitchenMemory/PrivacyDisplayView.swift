// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI

/// A person-facing summary of the privacy contract enforced by the app's
/// bundled privacy manifest.
///
/// Apple presents App Privacy details on the App Store product page, but does
/// not provide a runtime view that renders `PrivacyInfo.xcprivacy`. Keep this
/// deliberately small summary aligned with the root `PRIVACY.md`; the manifest
/// test separately proves that the shipped bundle declares the same current
/// behavior.
struct PrivacyDisplayView: View {
  var body: some View {
    List {
      privacySummary
      currentPractices
      recipeStorage
      debugging
    }
    .navigationTitle("Privacy")
    .accessibilityIdentifier("privacy-display")
#if os(macOS)
    .listStyle(.inset)
    .frame(minWidth: 480, minHeight: 440)
#else
    .listStyle(.insetGrouped)
#endif
  }

  private var privacySummary: some View {
    Section {
      VStack(spacing: 12) {
        Image(systemName: "hand.raised.fill")
          .font(.system(size: 44))
          .foregroundStyle(.tint)
          .accessibilityHidden(true)

        Text("Data Not Collected")
          .font(.title2.bold())
          .accessibilityAddTraits(.isHeader)

        Text("Kitchen Memory does not collect data from this app.")
          .foregroundStyle(.secondary)
      }
      .multilineTextAlignment(.center)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 16)
      .accessibilityIdentifier("privacy-data-not-collected")
    }
    .listRowBackground(Color.clear)
  }

  private var currentPractices: some View {
    Section {
      privacyPractice("No Tracking")
      privacyPractice("No Analytics")
      privacyPractice("No Advertising")
    } footer: {
      Text("This display reflects the privacy manifest included with this version of Kitchen Memory.")
    }
  }

  private var recipeStorage: some View {
    Section("Your Recipes") {
      Label {
        Text(
          "Recipes stay on this device and, when iCloud sync is available, in your private iCloud database."
        )
      } icon: {
        Image(systemName: "lock.icloud.fill")
          .foregroundStyle(.tint)
      }
    }
  }

  private var debugging: some View {
    Section("Debugging and Support") {
      Text(
        "We inspect private information only when you deliberately provide it to diagnose a problem."
      )
      // Preserve one stable localization key for this complete policy sentence.
      Text(
        """
        Private debugging material is deleted when the immediate need ends. It is never published or retained as test \
        data.
        """
      )
    }
  }

  private func privacyPractice(_ title: LocalizedStringKey) -> some View {
    Label(title, systemImage: "checkmark.circle.fill")
      .foregroundStyle(.primary, .green)
  }
}
