// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

#if os(iOS)
import BackgroundTasks
import Foundation

@MainActor
enum BackgroundMaintenance {
  static let identifier = "net.ctwelve.KitchenMemory.maintenance"

  static func requestOpportunity() async {
    let taskIdentifier = identifier
    // Submission may block; keep it off the main actor and wait before the refresh handler finishes.
    await Task.detached(priority: .utility) {
      let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
      request.earliestBeginDate = Date().addingTimeInterval(6 * 3_600)
      // The system may deny or never grant this request. Ordinary app opportunities remain sufficient.
      try? await BGTaskScheduler.shared.submitTaskRequest(request)
    }.value
  }
}
#endif
