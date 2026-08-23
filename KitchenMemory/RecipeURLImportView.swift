// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Accessibility
import Foundation
import KitchenMemoryLogic
import SwiftUI

struct RecipeURLImportView: View {
  let load: (URL) async throws -> [RecipeImportOption]
  let select: (RecipeImportOption) -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.locale) private var locale
  @State private var session = RecipeImportSession()
  @State private var importTask: Task<Void, Never>?

  var body: some View {
    NavigationStack {
      Group {
#if os(macOS)
        List {
          importSections
        }
        .listStyle(.inset)
#else
        Form {
          importSections
        }
#endif
      }
      .accessibilityIdentifier("recipe-url-import-scroll")
      .navigationTitle(session.candidates.isEmpty ? "Import Recipe" : "Choose Recipe")
#if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
#endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
      .onDisappear {
        importTask?.cancel()
        session.cancel()
      }
#if os(macOS)
      .frame(minWidth: 520, idealWidth: 600, minHeight: 360, idealHeight: 460)
#endif
    }
  }

  @ViewBuilder
  private var importSections: some View {
    if session.candidates.isEmpty {
      urlSection
      privacySection
    } else {
      candidateSection
    }
  }

  private var urlSection: some View {
    Section {
      urlField

      if let failure = session.failure {
        Label(Self.message(for: failure, locale: locale), systemImage: "exclamationmark.triangle")
          .foregroundStyle(.red)
          .accessibilityIdentifier("recipe-import-error")
      }

      Button {
        beginImport()
      } label: {
        Label {
          Text(session.isLoading ? "Fetching Recipe" : "Fetch Recipe")
        } icon: {
          if session.isLoading {
            ProgressView()
              .controlSize(.small)
              // The button's changing text communicates progress. Exposing the
              // spinner separately would make VoiceOver announce two controls.
              .accessibilityHidden(true)
          } else {
            Image(systemName: "arrow.down.doc")
          }
        }
      }
      .disabled(session.isLoading || session.normalizedURL == nil)
      .accessibilityLabel(session.isLoading ? "Fetching recipe" : "Fetch recipe")
      .accessibilityIdentifier("recipe-import-fetch")
    }
  }

  @ViewBuilder
  private var urlField: some View {
#if os(macOS)
    LabeledContent {
      urlTextField
        .labelsHidden()
    } label: {
      Text("Recipe webpage")
        .font(.subheadline.weight(.semibold))
    }
#else
    VStack(alignment: .leading, spacing: 6) {
      Text("Recipe webpage")
        .font(.subheadline.weight(.semibold))
      urlTextField
    }
#endif
  }

  private var urlTextField: some View {
    TextField(
      "Recipe webpage",
      text: $session.enteredURL,
      prompt: Text("https://example.com/recipe").foregroundStyle(.secondary)
    )
    .foregroundStyle(.primary)
    .textContentType(.URL)
#if os(iOS)
    .keyboardType(.URL)
    .textInputAutocapitalization(.never)
#endif
    .autocorrectionDisabled()
    .accessibilityLabel("Recipe webpage URL")
    .onSubmit { beginImport() }
  }

  private var privacySection: some View {
    Section("Privacy") {
      // swiftlint:disable:next line_length
      Text("Kitchen Memory follows redirects and downloads the resulting HTML with an ephemeral request that supplies no cookies or app credentials. It runs no page scripts and downloads no images during review.")
        .foregroundStyle(.secondary)
      // swiftlint:disable:next line_length
      Text("If you save a recipe, Kitchen Memory keeps the final source URL and one bounded JSON-LD recipe-metadata block locally, including source fields not shown in the review editor.")
        .foregroundStyle(.secondary)
    }
  }

  private var candidateSection: some View {
    Section {
      ForEach(session.candidates) { candidate in
        Button {
          select(candidate)
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            Text(
              candidate.draft.title.isEmpty
                ? String(localized: "Untitled recipe", locale: locale)
                : candidate.draft.title
            )
              .font(.headline)
            if let summary = candidate.draft.summary, !summary.isEmpty {
              Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            }
            if !candidate.concerns.isEmpty {
              Text(reviewNoteCount(candidate.concerns.count))
                .font(.caption)
                .foregroundStyle(.orange)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Review this recipe before saving")
      }
    } header: {
      Text("This page contains multiple recipes")
    } footer: {
      Button("Use a Different URL") {
        session.useDifferentURL()
      }
    }
  }

  private func beginImport() {
    guard let url = session.beginImport() else { return }
    // Changing a button label is visible feedback, but assistive technology
    // does not necessarily revisit that button when an asynchronous operation
    // begins. Announce the state transition without moving keyboard or
    // VoiceOver focus away from the URL field.
    AccessibilityNotification.Announcement("Fetching recipe").post()
    importTask?.cancel()
    importTask = Task {
      do {
        let loaded = try await load(url)
        guard !Task.isCancelled else { return }
        switch session.receive(loaded) {
        case .review(let candidate):
          select(candidate)
        case .choose:
          AccessibilityNotification.Announcement(
            "\(loaded.count) recipes found. Choose a recipe to review."
          ).post()
        case nil:
          break
        }
      } catch {
        session.receive(error: error)
        guard !Task.isCancelled, let failure = session.failure else { return }
        let message = Self.message(for: failure, locale: locale)
        // The identifier on the visible error supports automation only; it
        // does not make newly inserted text a live region. A native
        // announcement ensures the failure is heard while preserving the
        // person's current focus so they can correct the URL immediately.
        AccessibilityNotification.Announcement("Recipe import failed. \(message)").post()
      }
    }
  }

  private func reviewNoteCount(_ count: Int) -> String {
    String(localized: "\(count) review note", locale: locale)
  }

  private static func message(
    for failure: RecipeImportSessionFailure,
    locale: Locale = .current
  ) -> String {
    switch failure {
    case .noRecipeCandidates:
      String(localized: "No Schema.org recipe was found on this page.", locale: locale)
    case .disallowedAddress:
      String(localized: "For safety, Kitchen Memory cannot fetch this address or redirect.", locale: locale)
    case .pageTooLarge:
      String(localized: "This page contains too much data to import safely.", locale: locale)
    case .unsupportedPage:
      String(localized: "This address did not return a supported HTML recipe page.", locale: locale)
    case .networkFailure:
      String(
        localized: "The webpage could not be downloaded. Check your connection and try again.",
        locale: locale
      )
    case .unknown:
      String(
        localized: "Kitchen Memory could not import this webpage. Check the URL and try again.",
        locale: locale
      )
    }
  }
}
