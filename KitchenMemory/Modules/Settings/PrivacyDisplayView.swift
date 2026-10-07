// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

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
    .navigationTitle(.privacyTitle)
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

        Text(.privacySummaryTitle)
          .font(.title2.bold())
          .accessibilityAddTraits(.isHeader)

        Text(.privacySummaryMessage)
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
      privacyPractice(.privacyPracticeNoTracking)
      privacyPractice(.privacyPracticeNoAnalytics)
      privacyPractice(.privacyPracticeNoAdvertising)
    } footer: {
      Text(.privacyManifestNote)
    }
  }

  private var recipeStorage: some View {
    Section(.privacyRecipesSection) {
      Label {
        Text(.privacyRecipesMessage)
      } icon: {
        Image(systemName: "lock.icloud.fill")
          .foregroundStyle(.tint)
      }
    }
  }

  private var debugging: some View {
    Section(.privacyDebuggingSection) {
      Text(.privacyDebuggingInspection)
      Text(.privacyDebuggingRetention)
    }
  }

  private func privacyPractice(_ title: LocalizedStringResource) -> some View {
    Label(title, systemImage: "checkmark.circle.fill")
      .foregroundStyle(.primary, .green)
  }
}
