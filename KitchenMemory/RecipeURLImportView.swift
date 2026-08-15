// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Accessibility
import KitchenMemoryApplication
import SwiftUI

struct RecipeURLImportView: View {
  let load: (URL) async throws -> [RecipeImportOption]
  let select: (RecipeImportOption) -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var enteredURL = ""
  @State private var candidates: [RecipeImportOption] = []
  @State private var isLoading = false
  @State private var errorMessage: String?
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
      .navigationTitle(candidates.isEmpty ? "Import Recipe" : "Choose Recipe")
#if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
#endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
      .onDisappear { importTask?.cancel() }
#if os(macOS)
      .frame(minWidth: 520, idealWidth: 600, minHeight: 360, idealHeight: 460)
#endif
    }
  }

  @ViewBuilder
  private var importSections: some View {
    if candidates.isEmpty {
      urlSection
      privacySection
    } else {
      candidateSection
    }
  }

  private var urlSection: some View {
    Section {
      urlField

      if let errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle")
          .foregroundStyle(.red)
          .accessibilityIdentifier("recipe-import-error")
      }

      Button {
        beginImport()
      } label: {
        Label {
          Text(isLoading ? "Fetching Recipe" : "Fetch Recipe")
        } icon: {
          if isLoading {
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
      .disabled(isLoading || normalizedURL == nil)
      .accessibilityLabel(isLoading ? "Fetching recipe" : "Fetch recipe")
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
      text: $enteredURL,
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
      Text(
        "Kitchen Memory fetches this page once without cookies, runs no page scripts, "
          + "and downloads no images during review."
      )
        .foregroundStyle(.secondary)
    }
  }

  private var candidateSection: some View {
    Section {
      ForEach(candidates) { candidate in
        Button {
          select(candidate)
        } label: {
          VStack(alignment: .leading, spacing: 4) {
            Text(candidate.draft.title.isEmpty ? "Untitled recipe" : candidate.draft.title)
              .font(.headline)
            if let summary = candidate.draft.summary, !summary.isEmpty {
              Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            }
            if !candidate.concerns.isEmpty {
              Text("\(candidate.concerns.count) review note\(candidate.concerns.count == 1 ? "" : "s")")
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
        candidates = []
        errorMessage = nil
      }
    }
  }

  private var normalizedURL: URL? {
    let trimmed = enteredURL.trimmingCharacters(in: .whitespacesAndNewlines)
    // URL text is person-controlled and can be pasted from another process.
    // A modest ceiling prevents the UI and Foundation parser from doing
    // disproportionate work on a value that cannot be a practical recipe URL.
    guard !trimmed.isEmpty, trimmed.utf8.count <= 4_096 else { return nil }

    let parsed = URL(string: trimmed)
    let url = parsed?.scheme == nil ? URL(string: "https://\(trimmed)") : parsed
    guard let url,
          let scheme = url.scheme?.lowercased(),
          scheme == "https",
          url.host != nil
    else { return nil }
    return url
  }

  private func beginImport() {
    guard let url = normalizedURL, !isLoading else { return }
    isLoading = true
    errorMessage = nil
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
        isLoading = false
        if loaded.count == 1, let candidate = loaded.first {
          select(candidate)
        } else {
          candidates = loaded
          AccessibilityNotification.Announcement(
            "\(loaded.count) recipes found. Choose a recipe to review."
          ).post()
        }
      } catch {
        guard !Task.isCancelled else { return }
        isLoading = false
        let message = Self.message(for: error)
        errorMessage = message
        // The identifier on the visible error supports automation only; it
        // does not make newly inserted text a live region. A native
        // announcement ensures the failure is heard while preserving the
        // person's current focus so they can correct the URL immediately.
        AccessibilityNotification.Announcement("Recipe import failed. \(message)").post()
      }
    }
  }

  private static func message(for error: Error) -> String {
    switch error {
    case RecipeImportServiceError.noRecipeCandidates:
      "No Schema.org recipe was found on this page."
    case RecipeImportServiceError.disallowedAddress:
      "For safety, Kitchen Memory cannot fetch this address or redirect."
    case RecipeImportServiceError.pageTooLarge:
      "This page contains too much data to import safely."
    case RecipeImportServiceError.unsupportedPage:
      "This address did not return a supported HTML recipe page."
    case RecipeImportServiceError.networkFailure:
      "The webpage could not be downloaded. Check your connection and try again."
    default:
      "Kitchen Memory could not import this webpage. Check the URL and try again."
    }
  }
}
