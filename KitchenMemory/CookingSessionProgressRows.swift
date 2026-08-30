// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct CookingSessionIngredientList: View {
  let model: CookingSessionPresentationModel
  let session: CookingSessionProjection
  @Environment(\.locale) private var locale

  var body: some View {
    CookingSessionCard(title: .sessionProgressIngredients, symbol: "carrot") {
      if session.snapshot.ingredientSections.isEmpty {
        Text(.sessionProgressEmptyIngredients)
          .foregroundStyle(.secondary)
      } else {
        ForEach(Array(session.snapshot.ingredientSections.enumerated()), id: \.offset) { _, section in
          if let title = section.title, !title.isEmpty {
            Text(title)
              .font(.headline)
              .accessibilityAddTraits(.isHeader)
          }
          ForEach(section.ingredients) { ingredient in
            ingredientRow(ingredient)
          }
        }
      }
    }
  }

  private func ingredientRow(_ ingredient: SessionIngredient) -> some View {
    let state = session.ingredientProgress(for: ingredient.id)
    let isAccounted = state == .accounted
    return Button {
      model.setIngredient(ingredient.id, to: isAccounted ? .open : .accounted)
    } label: {
      HStack(alignment: .firstTextBaseline, spacing: 12) {
        Image(systemName: isAccounted ? "checkmark.circle.fill" : "circle")
          .foregroundStyle(isAccounted ? Color.accentColor : .secondary)
          .accessibilityHidden(true)
        Text(displayedIngredient(ingredient))
          .strikethrough(isAccounted)
          .frame(maxWidth: .infinity, alignment: .leading)
          .multilineTextAlignment(.leading)
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(session.lifecycle != .active)
    .accessibilityAddTraits(isAccounted ? .isSelected : [])
    .accessibilityValue(Text(isAccounted
      ? LocalizedStringResource.sessionProgressIngredientAccounted
      : .sessionProgressIngredientOpen))
    .accessibilityIdentifier("session-ingredient-\(ingredient.id.rawValue.uuidString)")
  }

  private func displayedIngredient(_ ingredient: SessionIngredient) -> String {
    var value = ingredient.value
    if let quantity = session.workingScale?.quantities.first(where: {
      $0.ingredientID == ingredient.id
    })?.quantity {
      value.quantity = quantity
    }
    return RecipePresentationFormatter(locale: locale).ingredient(value)
  }
}

struct CookingSessionInstructionList: View {
  let model: CookingSessionPresentationModel
  let session: CookingSessionProjection
  @Environment(\.locale) private var locale

  private var nextInstructionID: SessionInstruction.ID? {
    session.snapshot.instructionSections.flatMap(\.steps).first(where: {
      session.instructionProgress(for: $0.id) == .open
    })?.id
  }

  var body: some View {
    CookingSessionCard(title: .sessionProgressInstructions, symbol: "list.number") {
      if session.snapshot.instructionSections.isEmpty {
        Text(.sessionProgressEmptyInstructions)
          .foregroundStyle(.secondary)
      } else {
        ForEach(
          Array(session.snapshot.instructionSections.enumerated()),
          id: \.offset
        ) { sectionIndex, section in
          if let title = section.title, !title.isEmpty {
            Text(title)
              .font(.headline)
              .accessibilityAddTraits(.isHeader)
          }
          ForEach(Array(section.steps.enumerated()), id: \.element.id) { stepIndex, instruction in
            instructionRow(
              instruction,
              number: instructionNumber(sectionIndex: sectionIndex, stepIndex: stepIndex)
            )
          }
        }
      }
    }
  }

  private func instructionRow(
    _ instruction: SessionInstruction,
    number: Int
  ) -> some View {
    let state = session.instructionProgress(for: instruction.id)
    return VStack(alignment: .leading, spacing: 8) {
      if instruction.id == nextInstructionID {
        Label(.sessionProgressUpNext, systemImage: "arrow.right.circle.fill")
          .font(.caption.bold())
          .foregroundStyle(.tint)
      }
      HStack(alignment: .top, spacing: 12) {
        Button {
          model.setInstruction(instruction.id, to: state == .open ? .completed : .open)
        } label: {
          HStack(alignment: .top, spacing: 12) {
            Image(systemName: instructionSymbol(state))
              .foregroundStyle(instructionColor(state))
              .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
              Text(instruction.value.text)
                .strikethrough(state != .open)
                .frame(maxWidth: .infinity, alignment: .leading)
              if let duration = instruction.value.duration {
                Label(
                  RecipePresentationFormatter(locale: locale).duration(duration),
                  systemImage: "timer"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
              }
            }
          }
          .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(session.lifecycle != .active)
        .accessibilityAddTraits(state == .completed ? .isSelected : [])
        .accessibilityLabel(
          RecipeInstructionAccessibilityFormatter(locale: locale).label(
            number: number,
            step: instruction.value
          )
        )
        .accessibilityValue(Text(instructionValue(state)))
        .accessibilityIdentifier("session-instruction-step-\(instruction.id.rawValue.uuidString)")

        instructionMenu(instruction, state: state)
      }
    }
    .padding(.vertical, 4)
  }

  private func instructionMenu(
    _ instruction: SessionInstruction,
    state: SessionInstructionProgress
  ) -> some View {
    Menu {
      if state == .open {
        Button(.sessionProgressInstructionComplete) {
          model.setInstruction(instruction.id, to: .completed)
        }
        Button(.sessionProgressInstructionSkip) {
          model.setInstruction(instruction.id, to: .skipped)
        }
      } else {
        Button(.sessionProgressInstructionReopen) {
          model.setInstruction(instruction.id, to: .open)
        }
      }
    } label: {
      Image(systemName: "ellipsis.circle")
    }
    .disabled(session.lifecycle != .active)
    .accessibilityLabel(Text(.sessionProgressInstructionMoreActions))
    .accessibilityIdentifier("session-instruction-menu-\(instruction.id.rawValue.uuidString)")
  }

  private func instructionNumber(sectionIndex: Int, stepIndex: Int) -> Int {
    session.snapshot.instructionSections.prefix(sectionIndex).reduce(0) {
      $0 + $1.steps.count
    } + stepIndex + 1
  }

  private func instructionSymbol(_ state: SessionInstructionProgress) -> String {
    switch state {
    case .open: "circle"
    case .completed: "checkmark.circle.fill"
    case .skipped: "forward.circle.fill"
    }
  }

  private func instructionColor(_ state: SessionInstructionProgress) -> Color {
    state == .open ? .secondary : .accentColor
  }

  private func instructionValue(_ state: SessionInstructionProgress) -> LocalizedStringResource {
    switch state {
    case .open: .sessionProgressInstructionOpen
    case .completed: .sessionProgressInstructionCompleted
    case .skipped: .sessionProgressInstructionSkipped
    }
  }
}

struct CookingSessionCard<Content: View>: View {
  let title: LocalizedStringResource
  let symbol: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label(title, systemImage: symbol)
        .font(.title2.bold())
        .foregroundStyle(Color("IconMark"))
        .accessibilityHeading(.h2)
      content
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(20)
    .background(Color("ContentSurface"), in: .rect(cornerRadius: 16))
    .overlay {
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color("SubtleBorder"), lineWidth: 1)
    }
  }
}

private extension CookingSessionProjection {
  func ingredientProgress(for id: SessionIngredient.ID) -> SessionIngredientProgress {
    guard let value = progress.last(where: { $0.target == .ingredient(id) }) else { return .open }
    guard case let .ingredient(state) = value.state else { return .open }
    return state
  }

  func instructionProgress(for id: SessionInstruction.ID) -> SessionInstructionProgress {
    guard let value = progress.last(where: { $0.target == .instruction(id) }) else { return .open }
    guard case let .instruction(state) = value.state else { return .open }
    return state
  }
}
