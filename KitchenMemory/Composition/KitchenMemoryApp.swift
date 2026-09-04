// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import SwiftUI

/// The native application entry point and owner of scene-level presentation.
///
/// Startup remains visible while ``AppStartupCoordinator`` prepares the
/// application graph. The same prepared dependencies then feed the iOS window,
/// the macOS window, and the macOS Settings scene.
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
      SidebarCommands()
      RecipeLibraryCommands()
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
