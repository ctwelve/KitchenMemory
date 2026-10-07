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
    return HStack(alignment: .top, spacing: 12) {
      Button {
        model.setIngredient(ingredient.id, to: isAccounted ? .open : .accounted)
      } label: {
        Image(systemName: isAccounted ? "checkmark.circle.fill" : "circle")
          .font(.title2)
          .foregroundStyle(isAccounted ? Color.accentColor : .secondary)
          .frame(width: 48, height: 48)
          .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .disabled(session.lifecycle != .active)
      .accessibilityLabel(RecipePresentationFormatter(locale: locale).ingredient(
        cookingSessionIngredientValue(ingredient, in: session)))
      .accessibilityValue(Text(isAccounted
        ? LocalizedStringResource.sessionProgressIngredientAccounted
        : .sessionProgressIngredientOpen))
      .accessibilityIdentifier("session-ingredient-\(ingredient.id.rawValue.uuidString)")
      Text(RecipePresentationFormatter(locale: locale).ingredient(
        cookingSessionIngredientValue(ingredient, in: session)))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
    }
  }
}

func cookingSessionIngredientValue(
  _ ingredient: SessionIngredient,
  in session: CookingSessionProjection
) -> RecipeIngredient {
  guard let quantity = session.workingScale?.quantities.first(where: {
    $0.ingredientID == ingredient.id
  })?.quantity else { return ingredient.value }
  var value = ingredient.value
  let quantityChanged = value.quantity != quantity
  value.quantity = quantity
  if quantityChanged, value.presentationMode == .original {
    // The immutable original wording remains in the snapshot. A transient
    // structured presentation is required so a changed amount is not hidden.
    value.presentationMode = .structured
  }
  return value
}

struct CookingSessionInstructionList: View {
  let model: CookingSessionPresentationModel
  let session: CookingSessionProjection

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
            CookingSessionInstructionRow(
              model: model, session: session, instruction: instruction,
              number: instructionNumber(sectionIndex: sectionIndex, stepIndex: stepIndex)
            )
          }
        }
      }
    }
  }

  private func instructionNumber(sectionIndex: Int, stepIndex: Int) -> Int {
    session.snapshot.instructionSections.prefix(sectionIndex).reduce(0) {
      $0 + $1.steps.count
    } + stepIndex + 1
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

extension CookingSessionProjection {
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
