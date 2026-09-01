// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Combine
import SwiftUI

@MainActor
final class AppStartupCoordinator: ObservableObject {
  @Published private(set) var state: AppStartupState = .preparing

  private let prepareApplication: @MainActor () async -> AppStartupState
  private var preparationTask: Task<Void, Never>?

  init(
    prepareApplication: @escaping @MainActor () async -> AppStartupState = AppRuntime.prepare
  ) {
    self.prepareApplication = prepareApplication
  }

  func prepareIfNeeded() {
    guard preparationTask == nil else { return }
    preparationTask = Task { [weak self] in
      guard let self else { return }
      let preparedState = await prepareApplication()
      guard !Task.isCancelled else { return }
      state = preparedState
      preparationTask = nil
    }
  }

  func retry() {
    preparationTask?.cancel()
    preparationTask = nil
    state = .preparing
    prepareIfNeeded()
  }
}

@main
struct KitchenMemoryApp: App {
  @StateObject private var startup: AppStartupCoordinator

  init() {
    let startup = AppStartupCoordinator()
    startup.prepareIfNeeded()
    _startup = StateObject(wrappedValue: startup)
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
    switch startup.state {
    case .preparing:
      KitchenLoadingView()
    case .ready(let dependencies):
      ContentView(
        model: dependencies.libraryModel,
        sessionModel: dependencies.sessionModel,
        cloudSyncSettings: dependencies.cloudSyncSettings
      )
    case .unavailable:
      KitchenUnavailableView(retry: retryPreparation)
    }
  }

#if os(macOS)
  @ViewBuilder
  private var settingsContent: some View {
    switch startup.state {
    case .preparing:
      KitchenLoadingView()
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
    startup.retry()
  }
}
