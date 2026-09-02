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
        RecipeScalingControls(
          selection: $scaleSelection,
          context: .cookingSession(isEnabled: session.lifecycle == .active)
        )
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
