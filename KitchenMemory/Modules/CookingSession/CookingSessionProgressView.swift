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

  @Environment(\.locale) private var locale

  private var scaleSelection: RecipeScalingState {
    Self.scaleSelection(for: session)
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
      }
      if showsProgress { progressContent }
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
