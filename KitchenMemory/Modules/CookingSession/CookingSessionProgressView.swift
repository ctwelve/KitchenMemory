// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct CookingSessionProgressView: View {
  let model: CookingSessionPresentationModel
  let session: CookingSessionProjection
  let layoutMode: CookingSessionLayoutMode
  var showsProgress = true

  @State private var scaleSelection: RecipeScalingState
  @Environment(\.locale) private var locale

  init(
    model: CookingSessionPresentationModel,
    session: CookingSessionProjection,
    layoutMode: CookingSessionLayoutMode,
    showsProgress: Bool = true
  ) {
    self.model = model
    self.session = session
    self.layoutMode = layoutMode
    self.showsProgress = showsProgress
    _scaleSelection = State(initialValue: Self.scaleSelection(for: session))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      if session.lifecycle == .finished {
        if session.snapshot.baseYield != nil || session.workingScale != nil {
          CookingSessionCard(title: .sessionScaleSection, symbol: "arrow.up.left.and.arrow.down.right") {
            if session.snapshot.baseYield != nil {
              Text(scaleSelection.displayedYield(locale: locale))
            }
            if let factor = session.workingScale?.exactScale {
              Text(RecipePresentationFormatter(locale: locale).rational(factor) + "×")
            }
          }
        }
      } else if !scaleSelection.bases.isEmpty {
        RecipeScalingControls(
          selection: $scaleSelection,
          context: .cookingSession(isEnabled: session.lifecycle == .active)
        )
      }
      if showsProgress { progressContent }
    }
    .onChange(of: scaleSelection) { _, selection in
      if session.lifecycle == .active, let scale = selection.scale {
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
