// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct CookingSessionProgressView: View {
  let model: CookingSessionPresentationModel
  let session: CookingSessionProjection
  let layoutMode: CookingSessionLayoutMode

  @State private var scaleSelection: RecipeScalingState

  init(
    model: CookingSessionPresentationModel,
    session: CookingSessionProjection,
    layoutMode: CookingSessionLayoutMode
  ) {
    self.model = model
    self.session = session
    self.layoutMode = layoutMode
    _scaleSelection = State(initialValue: Self.scaleSelection(for: session))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      if !scaleSelection.bases.isEmpty {
        CookingSessionScaleControls(selection: $scaleSelection, isEnabled: session.lifecycle == .active)
      }
      progressContent
    }
    .onChange(of: scaleSelection) { _, selection in
      if let scale = selection.scale {
        model.replaceWorkingScale(with: scale)
      }
    }
    .onChange(of: session.workingScale) { _, _ in
      let restored = Self.scaleSelection(for: session)
      if restored != scaleSelection { scaleSelection = restored }
    }
  }

  @ViewBuilder
  private var progressContent: some View {
    switch layoutMode {
    case .compact:
      VStack(alignment: .leading, spacing: 20) {
        ingredients
        instructions
      }
    case .regular:
      HStack(alignment: .top, spacing: 20) {
        ingredients
        instructions
      }
    case .wide:
      HStack(alignment: .top, spacing: 24) {
        ingredients.frame(maxWidth: 420)
        instructions
      }
    }
  }

  private var ingredients: some View {
    CookingSessionIngredientList(model: model, session: session)
  }

  private var instructions: some View {
    CookingSessionInstructionList(model: model, session: session)
  }

  private static func scaleSelection(for session: CookingSessionProjection) -> RecipeScalingState {
    RecipeScalingState(
      recipeYield: session.snapshot.baseYield,
      workingYield: session.workingScale?.workingYield?.quantity?.lowerBound,
      exactScale: session.workingScale?.exactScale
    )
  }
}

private struct CookingSessionScaleControls: View {
  @Binding var selection: RecipeScalingState
  let isEnabled: Bool
  @Environment(\.locale) private var locale

  var body: some View {
    CookingSessionCard(title: .sessionScaleSection, symbol: "arrow.up.left.and.arrow.down.right") {
      if selection.bases.count > 1 {
        Picker(LocalizedStringResource.recipeScalingBaseYield, selection: basisBinding) {
          ForEach(selection.bases.indices, id: \.self) { index in
            Text(selection.basisLabel(selection.bases[index], locale: locale)).tag(index)
          }
        }
        .disabled(!isEnabled)
        .accessibilityIdentifier("session-scaling-basis")
      }
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text(.recipeScalingWorkingYield)
            .font(.headline)
          Text(selection.workingYieldLabel(locale: locale))
            .font(.title3.monospacedDigit())
            .foregroundStyle(Color("IconMark"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(.recipeScalingWorkingYield))
        .accessibilityValue(selection.workingYieldLabel(locale: locale))
        .accessibilityIdentifier("session-working-yield")

        Button {
          selection.adjustWorkingYield(by: -1)
        } label: {
          Image(systemName: "minus")
        }
        .disabled(!isEnabled || !selection.canDecreaseWorkingYield)
        .accessibilityLabel(Text(.recipeScalingActionDecrease))
        .accessibilityIdentifier("session-working-yield-decrement")

        Button {
          selection.adjustWorkingYield(by: 1)
        } label: {
          Image(systemName: "plus")
        }
        .disabled(!isEnabled || !selection.canIncreaseWorkingYield)
        .accessibilityLabel(Text(.recipeScalingActionIncrease))
        .accessibilityIdentifier("session-working-yield-increment")
      }
      HStack(alignment: .firstTextBaseline) {
        Text(.sessionScaleNote)
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer(minLength: 12)
        if selection.workingYield != selection.selectedBasis?.quantity {
          Button(.actionReset) {
            selection.resetWorkingYield()
          }
          .disabled(!isEnabled)
          .accessibilityLabel(Text(.recipeScalingActionResetAccessibilityLabel))
          .accessibilityIdentifier("session-scaling-reset")
        }
      }
    }
  }

  private var basisBinding: Binding<Int> {
    Binding(
      get: { selection.selectedBasisIndex },
      set: { selection.selectBasis($0) }
    )
  }
}
