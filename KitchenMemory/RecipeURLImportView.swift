// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

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
      Form {
        if candidates.isEmpty {
          urlSection
          privacySection
        } else {
          candidateSection
        }
      }
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
      .frame(minWidth: 480, idealWidth: 560, minHeight: 330, idealHeight: 440)
#endif
    }
  }

  private var urlSection: some View {
    Section("Recipe webpage") {
      TextField("https://example.com/recipe", text: $enteredURL)
        .textContentType(.URL)
#if os(iOS)
        .keyboardType(.URL)
        .textInputAutocapitalization(.never)
#endif
        .autocorrectionDisabled()
        .accessibilityLabel("Recipe webpage URL")
        .onSubmit { beginImport() }

      if let errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle")
          .foregroundStyle(.red)
          .accessibilityIdentifier("recipe-import-error")
      }

      Button {
        beginImport()
      } label: {
        if isLoading {
          ProgressView().controlSize(.small)
        } else {
          Label("Fetch Recipe", systemImage: "arrow.down.doc")
        }
      }
      .disabled(isLoading || normalizedURL == nil)
      .accessibilityIdentifier("recipe-import-fetch")
    }
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
              Text("\(candidate.concerns.count) item\(candidate.concerns.count == 1 ? "" : "s") to review")
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
    guard !trimmed.isEmpty else { return nil }
    let value = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
    return URL(string: value)
  }

  private func beginImport() {
    guard let url = normalizedURL, !isLoading else { return }
    isLoading = true
    errorMessage = nil
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
        }
      } catch {
        guard !Task.isCancelled else { return }
        isLoading = false
        errorMessage = Self.message(for: error)
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
