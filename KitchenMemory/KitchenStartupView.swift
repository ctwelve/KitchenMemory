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
      ProgressView(.startupLoading)
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
        Text(.startupSamplesTitle)
          .font(.title2.bold())
        Text(.startupSamplesMessage)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }

      HStack {
        Button(.actionNotNow, action: decline)
        Button(.samplesActionAdd, action: accept)
          .buttonStyle(.borderedProminent)
      }

      Text(.startupSamplesLaterMessage)
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
