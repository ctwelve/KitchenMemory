// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Combine
import Foundation

enum AppStartupState {
  case preparing
  case ready(PreparedApp)
  case unavailable

  static func prepare(using makePreparedApp: () async throws -> PreparedApp) async -> Self {
    do {
      return .ready(try await makePreparedApp())
    } catch {
      // Persistence and CloudKit errors can contain local paths or framework
      // identifiers. Do not read, interpolate, or retain the underlying error.
      return .unavailable
    }
  }

  var preparedApp: PreparedApp? {
    guard case .ready(let preparedApp) = self else { return nil }
    return preparedApp
  }
}

enum AppShellPresentation: Hashable {
  case loading
  case recovery
  case ready

  init(state: AppStartupState) {
    switch state {
    case .preparing:
      self = .loading
    case .ready:
      self = .ready
    case .unavailable:
      self = .recovery
    }
  }

  var permitsKitchenActions: Bool {
    self == .ready
  }
}

enum AppStartupMilestone: Equatable {
  case startupSurfacePresented
  case preparationStarted
  case preparationRetired
  case preparationReady
  case preparationUnavailable
}

struct AppStartupTimingMarker: Equatable {
  let milestone: AppStartupMilestone
  let elapsed: TimeInterval
}

@MainActor
final class AppStartupDiagnostics {
  static let maximumMilestones = 16
  static let live = AppStartupDiagnostics()

  private let maximumMilestones: Int
  private let uptime: @MainActor () -> TimeInterval
  private let launchUptime: TimeInterval
  private(set) var markers: [AppStartupTimingMarker] = []

  init(
    maximumMilestones: Int = AppStartupDiagnostics.maximumMilestones,
    uptime: @escaping @MainActor () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
  ) {
    self.maximumMilestones = max(0, maximumMilestones)
    self.uptime = uptime
    launchUptime = uptime()
  }

  static func recordLive(_ milestone: AppStartupMilestone) {
    live.record(milestone)
  }

  func record(_ milestone: AppStartupMilestone) {
#if DEBUG
    guard markers.count < maximumMilestones else { return }
    markers.append(
      AppStartupTimingMarker(
        milestone: milestone,
        elapsed: uptime() - launchUptime
      )
    )
#endif
  }
}

@MainActor
final class AppStartupCoordinator: ObservableObject {
  @Published private(set) var state: AppStartupState = .preparing

  private let prepareApplication: @MainActor () async -> AppStartupState
  private let recordMilestone: @MainActor (AppStartupMilestone) -> Void
  private var preparationTask: Task<Void, Never>?
  private var retryIsPending = false
  private var startupSurfaceHasPresented = false

  init(
    prepareApplication: @escaping @MainActor () async -> AppStartupState = AppRuntime.prepare,
    recordMilestone: @escaping @MainActor (AppStartupMilestone) -> Void =
      AppStartupDiagnostics.recordLive
  ) {
    self.prepareApplication = prepareApplication
    self.recordMilestone = recordMilestone
  }

  func startupSurfacePresented() {
    guard !startupSurfaceHasPresented else { return }
    startupSurfaceHasPresented = true
    recordMilestone(.startupSurfacePresented)
    prepareIfNeeded()
  }

  func retry() {
    state = .preparing
    guard let preparationTask else {
      prepareIfNeeded()
      return
    }
    retryIsPending = true
    preparationTask.cancel()
  }

  private func prepareIfNeeded() {
    guard preparationTask == nil else { return }
    recordMilestone(.preparationStarted)
    preparationTask = Task { [weak self] in
      guard let self else { return }
      let preparedState = await prepareApplication()
      if retryIsPending {
        recordMilestone(.preparationRetired)
        retryIsPending = false
        preparationTask = nil
        prepareIfNeeded()
        return
      }
      guard !Task.isCancelled else { return }
      state = preparedState
      preparationTask = nil
      switch preparedState {
      case .preparing:
        break
      case .ready:
        recordMilestone(.preparationReady)
      case .unavailable:
        recordMilestone(.preparationUnavailable)
      }
    }
  }
}
