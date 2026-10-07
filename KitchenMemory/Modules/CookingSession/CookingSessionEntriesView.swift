// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import SwiftUI

struct CookingSessionEntriesView: View {
  let model: CookingSessionPresentationModel
  let session: CookingSessionProjection

  @State private var editingEntryID: SessionEntry.ID?
  @State private var editingText = ""
  @State private var editingTarget: SessionProgressTarget?
  @Environment(\.locale) private var locale
  @Environment(\.cookingSessionComposerOrigin) private var composerOrigin

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(.sessionEntrySection)
        .font(.title2.bold())
        .accessibilityHeading(.h2)

      CookingSessionEvidenceConflictsView(model: model, session: session)

      if session.lifecycle == .active {
        Button(.sessionEntryActionAdd) { model.openEntryComposer(origin: composerOrigin) }
          .disabled(model.currentSessionHasPendingFinish)
          .accessibilityIdentifier("add-session-note")
      }

      if !session.entries.isEmpty {
        VStack(alignment: .leading, spacing: 12) {
          ForEach(session.entries) { entry in
            entryRow(entry)
          }
        }
      }

    }
    .padding(20)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("session-entries")
  }

  @ViewBuilder
  private func entryRow(_ entry: SessionEntry) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      if editingEntryID == entry.id {
        TextField(.sessionEntryDraftPlaceholder, text: $editingText, axis: .vertical)
          .disabled(session.lifecycle != .active || model.currentSessionHasPendingFinish)
          .lineLimit(2...6)
          .padding(6)
          .background(.background, in: RoundedRectangle(cornerRadius: 8))
        targetPicker(selection: $editingTarget)
          .disabled(session.lifecycle != .active || model.currentSessionHasPendingFinish)
        HStack {
          Button(.actionCancel) { editingEntryID = nil }
          Spacer()
          Button(.sessionEntryActionSave) {
            if model.reviseEntry(entry.id, text: editingText, target: editingTarget) {
              editingEntryID = nil
            }
          }
          .buttonStyle(.borderedProminent)
          .disabled(session.lifecycle != .active || model.currentSessionHasPendingFinish
            || !CookingSessionEntryDraft.isMeaningful(editingText))
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
        .disabled(session.lifecycle != .active || model.currentSessionHasPendingFinish)
      }
    }
    .padding(12)
    .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
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
    SessionEntryTargetPresentation(snapshot: session.snapshot, locale: locale)
  }

  private func targetLabel(_ target: SessionProgressTarget) -> String {
    targetPresentation.label(for: target)
  }
}

struct SessionEntryTargetPresentation {
  let snapshot: ExecutionSnapshot
  let locale: Locale

  var options: [SessionEntryTargetOption] {
    let ingredients = snapshot.ingredientSections.enumerated().flatMap { sectionPair in
      let (sectionIndex, section) = sectionPair
      return section.ingredients.enumerated().map { ingredientPair in
        let (ingredientIndex, ingredient) = ingredientPair
        return SessionEntryTargetOption(
          target: .ingredient(ingredient.id),
          label: LocalizedStringResource.sessionEntryTargetIngredient(
            section: sectionIndex + 1,
            position: ingredientIndex + 1,
            label: ingredient.value.originalText
          ).localized(for: locale)
        )
      }
    }
    let instructions = snapshot.instructionSections.enumerated().flatMap { sectionPair in
      let (sectionIndex, section) = sectionPair
      return section.steps.enumerated().map { instructionPair in
        let (instructionIndex, instruction) = instructionPair
        return SessionEntryTargetOption(
          target: .instruction(instruction.id),
          label: LocalizedStringResource.sessionEntryTargetInstruction(
            section: sectionIndex + 1,
            position: instructionIndex + 1,
            label: instruction.value.name ?? instruction.value.text
          ).localized(for: locale)
        )
      }
    }
    return ingredients + instructions
  }

  func label(for target: SessionProgressTarget) -> String {
    options.first(where: { $0.target == target })?.label ??
      LocalizedStringResource.sessionEntryTargetUnavailable.localized(for: locale)
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
