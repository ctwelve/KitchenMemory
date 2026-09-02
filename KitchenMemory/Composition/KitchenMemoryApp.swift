// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import SwiftUI

@main
struct KitchenMemoryApp: App {
  @StateObject private var startup: AppStartupCoordinator

  init() {
    _startup = StateObject(wrappedValue: AppStartupCoordinator())
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
    ContentView(
      startupState: startup.state,
      retryStartup: retryPreparation
    )
    .background(startupFrameObserver)
  }

#if os(macOS)
  @ViewBuilder
  private var settingsContent: some View {
    switch startup.state {
    case .preparing:
      KitchenLoadingView()
        .background(startupFrameObserver)
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

  private var startupFrameObserver: some View {
    StartupFrameObserver {
      startup.startupSurfacePresented()
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }

  private func retryPreparation() {
    startup.retry()
  }
}
