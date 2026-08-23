// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI

struct KitchenLoadingView: View {
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "fork.knife")
        .font(.system(size: 44))
        .foregroundStyle(.tint)
        .accessibilityHidden(true)
      ProgressView("Preparing Your Kitchen…")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color("AppBackground"))
    .accessibilityIdentifier("kitchen-loading")
  }
}

struct SampleRecipeDecisionView: View {
  let accept: () -> Void
  let decline: () -> Void

  var body: some View {
    VStack(spacing: 20) {
      Image(systemName: "book.pages")
        .font(.system(size: 48))
        .foregroundStyle(.tint)
        .accessibilityHidden(true)

      VStack(spacing: 8) {
        Text("Add Sample Recipes?")
          .font(.title2.bold())
        Text("Kitchen Memory includes a small collection of sample recipes. Add them to your recipe library?")
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }

      HStack {
        Button("Not Now", action: decline)
        Button("Add Sample Recipes", action: accept)
          .buttonStyle(.borderedProminent)
      }

      Text("You can add them later from Settings.")
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    .padding(32)
    .frame(maxWidth: 520, maxHeight: .infinity)
    .frame(maxWidth: .infinity)
    .background(Color("AppBackground"))
    .accessibilityIdentifier("sample-recipe-decision")
  }
}
