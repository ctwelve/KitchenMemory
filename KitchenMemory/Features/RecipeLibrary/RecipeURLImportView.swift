// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Accessibility
import Foundation
import KitchenKit
import SwiftUI
import UniformTypeIdentifiers

struct RecipeURLImportView: View {
  let load: (URL) async throws -> [RecipeImportOption]
  let loadDocument: (URL) throws -> [RecipeImportOption]
  let select: (RecipeImportOption) -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.locale) private var locale
  @State private var session = RecipeImportSession()
  @State private var importTask: Task<Void, Never>?
  @State private var showsDocumentPicker = false

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
      .fileImporter(isPresented: $showsDocumentPicker, allowedContentTypes: [.html, .json]) { result in
        do {
          let options = try loadDocument(result.get())
          if case .review(let option) = session.receive(options) { select(option) }
        } catch CocoaError.userCancelled {
          // Dismissing the native picker leaves the current import intent alone.
        } catch { session.receive(error: error) }
      }
      .navigationTitle(session.candidates.isEmpty ? .recipeImportTitle : .recipeImportChooseTitle)
#if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
#endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(.actionCancel) { dismiss() }
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
          Text(session.isLoading ? .recipeImportFetchProgress : .recipeImportFetchAction)
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
      .accessibilityLabel(
        Text(session.isLoading ? .recipeImportFetchProgress : .recipeImportFetchAction)
      )
      .accessibilityIdentifier("recipe-import-fetch")
      Button(.recipeImportDocumentAction, systemImage: "doc") {
        showsDocumentPicker = true
      }
      .disabled(session.isLoading)
    }
  }

  @ViewBuilder
  private var urlField: some View {
#if os(macOS)
    LabeledContent {
      urlTextField
        .labelsHidden()
    } label: {
      Text(.recipeImportWebpageField)
        .font(.subheadline.weight(.semibold))
    }
#else
    VStack(alignment: .leading, spacing: 6) {
      Text(.recipeImportWebpageField)
        .font(.subheadline.weight(.semibold))
      urlTextField
    }
#endif
  }

  private var urlTextField: some View {
    TextField(
      LocalizedStringResource.recipeImportWebpageField,
      text: $session.enteredURL,
      prompt: Text(verbatim: "https://example.com/recipe").foregroundStyle(.secondary)
    )
    .foregroundStyle(.primary)
    .textContentType(.URL)
#if os(iOS)
    .keyboardType(.URL)
    .textInputAutocapitalization(.never)
#endif
    .autocorrectionDisabled()
    .accessibilityLabel(Text(.recipeImportWebpageAccessibilityLabel))
    .onSubmit { beginImport() }
  }

  private var privacySection: some View {
    Section(.privacyTitle) {
      Text(.recipeImportPrivacyFetching)
        .foregroundStyle(.secondary)
      Text(.recipeImportPrivacyStorage)
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
                ? LocalizedStringResource.recipeImportCandidateUntitled.localized(for: locale)
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
        .accessibilityHint(Text(.recipeImportCandidateReviewHint))
      }
    } header: {
      Text(.recipeImportCandidatesSection)
    } footer: {
      Button(.recipeImportActionDifferentUrl) {
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
    AccessibilityNotification.Announcement(
      LocalizedStringResource.recipeImportFetchProgress.localized(for: locale)
    ).post()
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
            LocalizedStringResource.recipeImportAnnouncementCandidateCount(count: loaded.count)
              .localized(for: locale)
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
        AccessibilityNotification.Announcement(
          LocalizedStringResource.recipeImportAnnouncementFailed(message: message)
            .localized(for: locale)
        ).post()
      }
    }
  }

  private func reviewNoteCount(_ count: Int) -> String {
    LocalizedStringResource.importReviewConcernReviewNoteCount(count: count)
      .localized(for: locale)
  }

  private static func message(
    for failure: RecipeImportSessionFailure,
    locale: Locale = .current
  ) -> String {
    switch failure {
    case .noRecipeCandidates:
      LocalizedStringResource.recipeImportFailureNoCandidates.localized(for: locale)
    case .disallowedAddress:
      LocalizedStringResource.recipeImportFailureDisallowedAddress.localized(for: locale)
    case .pageTooLarge:
      LocalizedStringResource.recipeImportFailurePageTooLarge.localized(for: locale)
    case .unsupportedPage:
      LocalizedStringResource.recipeImportFailureUnsupportedPage.localized(for: locale)
    case .networkFailure:
      LocalizedStringResource.recipeImportFailureNetwork.localized(for: locale)
    case .unknown:
      LocalizedStringResource.recipeImportFailureUnknown.localized(for: locale)
    }
  }
}
