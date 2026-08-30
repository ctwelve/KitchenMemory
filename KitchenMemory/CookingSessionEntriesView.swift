// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct CookingSessionEntriesView: View {
  let model: CookingSessionPresentationModel
  let session: CookingSessionProjection

  @State private var editingEntryID: SessionEntry.ID?
  @State private var editingText = ""
  @State private var editingTarget: SessionProgressTarget?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(.sessionEntrySection)
        .font(.title2.bold())
        .accessibilityHeading(.h2)

      CookingSessionEvidenceConflictsView(model: model, session: session)

      draftEditor

      if !session.entries.isEmpty {
        VStack(alignment: .leading, spacing: 12) {
          ForEach(session.entries) { entry in
            entryRow(entry)
          }
        }
      }

      outcomePicker
    }
    .padding(20)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("session-entries")
  }

  private var draftEditor: some View {
    VStack(alignment: .leading, spacing: 10) {
      TextField(.sessionEntryDraftPlaceholder, text: draftText, axis: .vertical)
        .lineLimit(3...8)
        .padding(8)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("session-entry-draft")

      HStack(alignment: .firstTextBaseline) {
        targetPicker(selection: draftTarget)
        Spacer()
        Button(.sessionEntryActionSubmit) {
          model.submitCurrentEntryDraft()
        }
        .buttonStyle(.borderedProminent)
        .disabled(session.lifecycle != .active || model.currentEntryDraft?.isMeaningful != true)
        .accessibilityIdentifier("submit-session-entry")
      }

      Text(.sessionEntryDraftNote)
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private func entryRow(_ entry: SessionEntry) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      if editingEntryID == entry.id {
        TextField(.sessionEntryDraftPlaceholder, text: $editingText, axis: .vertical)
          .lineLimit(2...6)
          .padding(6)
          .background(.background, in: RoundedRectangle(cornerRadius: 8))
        targetPicker(selection: $editingTarget)
        HStack {
          Button(.actionCancel) { editingEntryID = nil }
          Spacer()
          Button(.sessionEntryActionSave) {
            if model.reviseEntry(entry.id, text: editingText, target: editingTarget) {
              editingEntryID = nil
            }
          }
          .buttonStyle(.borderedProminent)
          .disabled(!CookingSessionEntryDraft.isMeaningful(editingText))
        }
      } else {
        Text(entry.text)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
        if let target = entry.target {
          Label(targetLabel(target), systemImage: "scope")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        HStack {
          Button(.sessionEntryActionEdit) {
            editingEntryID = entry.id
            editingText = entry.text
            editingTarget = entry.target
          }
          targetMenu(entryID: entry.id)
          Spacer()
          Button(.sessionEntryActionWithdraw, role: .destructive) {
            model.withdrawEntry(entry.id)
          }
        }
        .buttonStyle(.borderless)
        .disabled(session.lifecycle != .active)
      }
    }
    .padding(12)
    .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
  }

  private var outcomePicker: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(.sessionOutcomeSection)
        .font(.headline)
      Picker(.sessionOutcomeSection, selection: outcomeSelection) {
        Text(.sessionOutcomeNone).tag(nil as SessionOutcome.CoarseValue?)
        Text(.sessionOutcomeGreat)
          .tag(SessionOutcome.CoarseValue.great as SessionOutcome.CoarseValue?)
        Text(.sessionOutcomeOkay)
          .tag(SessionOutcome.CoarseValue.okay as SessionOutcome.CoarseValue?)
        Text(.sessionOutcomeUnsuccessful)
          .tag(SessionOutcome.CoarseValue.unsuccessful as SessionOutcome.CoarseValue?)
      }
      .pickerStyle(.segmented)
      .disabled(session.lifecycle != .active)
      .accessibilityIdentifier("session-outcome")
    }
  }

  private var draftText: Binding<String> {
    Binding(
      get: { model.currentEntryDraft?.text ?? "" },
      set: { model.updateCurrentEntryDraft(text: $0, target: model.currentEntryDraft?.target) }
    )
  }

  private var draftTarget: Binding<SessionProgressTarget?> {
    Binding(
      get: { model.currentEntryDraft?.target },
      set: { model.updateCurrentEntryDraft(text: model.currentEntryDraft?.text ?? "", target: $0) }
    )
  }

  private var outcomeSelection: Binding<SessionOutcome.CoarseValue?> {
    Binding(
      get: {
        guard case let .coarse(value) = session.outcome else { return nil }
        return value
      },
      set: { value in
        if let value {
          model.setOutcome(.coarse(value))
        } else if session.outcome != nil {
          model.clearOutcome()
        }
      }
    )
  }

  private func targetPicker(selection: Binding<SessionProgressTarget?>) -> some View {
    Picker(.sessionEntryTargetLabel, selection: selection) {
      Text(.sessionEntryTargetNone).tag(nil as SessionProgressTarget?)
      ForEach(targetPresentation.options) { option in
        Text(option.label).tag(option.target as SessionProgressTarget?)
      }
    }
    .labelsHidden()
    .accessibilityLabel(Text(.sessionEntryTargetLabel))
  }

  private func targetMenu(entryID: SessionEntry.ID) -> some View {
    Menu(.sessionEntryActionRetarget) {
      Button(.sessionEntryTargetNone) { model.retargetEntry(entryID, to: nil) }
      ForEach(targetPresentation.options) { option in
        Button(option.label) { model.retargetEntry(entryID, to: option.target) }
      }
    }
  }

  private var targetPresentation: SessionEntryTargetPresentation {
    SessionEntryTargetPresentation(snapshot: session.snapshot)
  }

  private func targetLabel(_ target: SessionProgressTarget) -> String {
    targetPresentation.label(for: target)
  }
}

struct SessionEntryTargetPresentation {
  let snapshot: ExecutionSnapshot

  var options: [SessionEntryTargetOption] {
    let ingredients = snapshot.ingredientSections.enumerated().flatMap { sectionPair in
      let (sectionIndex, section) = sectionPair
      return section.ingredients.enumerated().map { ingredientPair in
        let (ingredientIndex, ingredient) = ingredientPair
        return SessionEntryTargetOption(
          target: .ingredient(ingredient.id),
          label: String(localized: .sessionEntryTargetIngredient(
            section: sectionIndex + 1,
            position: ingredientIndex + 1,
            label: ingredient.value.originalText
          ))
        )
      }
    }
    let instructions = snapshot.instructionSections.enumerated().flatMap { sectionPair in
      let (sectionIndex, section) = sectionPair
      return section.steps.enumerated().map { instructionPair in
        let (instructionIndex, instruction) = instructionPair
        return SessionEntryTargetOption(
          target: .instruction(instruction.id),
          label: String(localized: .sessionEntryTargetInstruction(
            section: sectionIndex + 1,
            position: instructionIndex + 1,
            label: instruction.value.name ?? instruction.value.text
          ))
        )
      }
    }
    return ingredients + instructions
  }

  func label(for target: SessionProgressTarget) -> String {
    options.first(where: { $0.target == target })?.label ??
      String(localized: .sessionEntryTargetUnavailable)
  }
}

struct SessionEntryTargetOption: Identifiable {
  let target: SessionProgressTarget
  let label: String

  var id: UUID {
    switch target {
    case let .ingredient(id): id.rawValue
    case let .instruction(id): id.rawValue
    }
  }
}
