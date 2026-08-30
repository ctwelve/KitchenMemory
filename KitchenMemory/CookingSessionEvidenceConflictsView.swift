// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct CookingSessionEvidenceConflictsView: View {
  let model: CookingSessionPresentationModel
  let session: CookingSessionProjection

  var body: some View {
    if !evidenceConflicts.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        Label(.sessionEvidenceConflictTitle, systemImage: "exclamationmark.triangle.fill")
          .font(.headline)
          .foregroundStyle(.orange)

        ForEach(Array(evidenceConflicts.enumerated()), id: \.offset) { _, conflict in
          switch conflict {
          case let .entry(entryID, _, values):
            entryConflict(entryID: entryID, values: values)
          case let .outcome(_, values):
            outcomeConflict(values: values)
          case .progress, .workingScale:
            EmptyView()
          }
        }
      }
      .padding(12)
      .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("session-evidence-conflicts")
    }
  }

  private var evidenceConflicts: [SessionConflict] {
    session.conflicts.filter { conflict in
      switch conflict {
      case .entry, .outcome: true
      case .progress, .workingScale: false
      }
    }
  }

  private func entryConflict(
    entryID: SessionEntry.ID,
    values: [SessionEntryConflictValue]
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(.sessionEvidenceConflictEntry)
        .font(.subheadline)
      ForEach(Array(values.enumerated()), id: \.offset) { _, value in
        switch value {
        case let .present(entry):
          Button {
            model.reviseEntry(entryID, text: entry.text, target: entry.target)
          } label: {
            VStack(alignment: .leading, spacing: 2) {
              Text(entry.text)
              Label(targetLabel(entry.target), systemImage: "scope")
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
          }
        case .withdrawn:
          Button(.sessionEntryConflictWithdrawn, role: .destructive) {
            model.withdrawEntry(entryID)
          }
        }
      }
    }
  }

  private func outcomeConflict(values: [SessionOutcomeConflictValue]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(.sessionEvidenceConflictOutcome)
        .font(.subheadline)
      HStack {
        ForEach(Array(values.enumerated()), id: \.offset) { _, value in
          switch value {
          case let .value(outcome):
            Button(outcomeLabel(outcome)) { model.setOutcome(outcome) }
          case .cleared:
            Button(.sessionOutcomeNone) { model.clearOutcome() }
          }
        }
      }
    }
  }

  private func outcomeLabel(_ outcome: SessionOutcome) -> LocalizedStringResource {
    switch outcome {
    case .coarse(.great): .sessionOutcomeGreat
    case .coarse(.okay): .sessionOutcomeOkay
    case .coarse(.unsuccessful): .sessionOutcomeUnsuccessful
    }
  }

  private func targetLabel(_ target: SessionProgressTarget?) -> String {
    guard let target else { return String(localized: .sessionEntryTargetNone) }
    return SessionEntryTargetPresentation(snapshot: session.snapshot).label(for: target)
  }
}
