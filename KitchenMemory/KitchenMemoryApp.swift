// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI

@main
struct KitchenMemoryApp: App {
  @State private var startupState: AppStartupState

  init() {
    _startupState = State(initialValue: AppRuntime.prepare())
  }

  var body: some Scene {
#if os(macOS)
    WindowGroup {
      applicationContent
    }
    .commands {
      KitchenCommands()
    }

    Settings {
      settingsContent
    }
#else
    WindowGroup {
      applicationContent
    }
#endif
  }

  @ViewBuilder
  private var applicationContent: some View {
    switch startupState {
    case .ready(let dependencies):
      ContentView(
        model: dependencies.libraryModel,
        cloudSyncSettings: dependencies.cloudSyncSettings
      )
    case .unavailable:
      KitchenUnavailableView(retry: retryPreparation)
    }
  }

#if os(macOS)
  @ViewBuilder
  private var settingsContent: some View {
    switch startupState {
    case .ready(let dependencies):
      NavigationStack {
        KitchenSettingsView(
          model: dependencies.libraryModel,
          cloudSyncSettings: dependencies.cloudSyncSettings
        )
      }
    case .unavailable:
      KitchenUnavailableView(retry: retryPreparation)
    }
  }
#endif

  private func retryPreparation() {
    startupState = AppRuntime.prepare()
  }
}
