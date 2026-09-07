// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

#if os(iOS)
import BackgroundTasks
import Foundation

@MainActor
enum BackgroundMaintenance {
  static let identifier = "net.ctwelve.KitchenMemory.maintenance"

  static func requestOpportunity() {
    let request = BGAppRefreshTaskRequest(identifier: identifier)
    request.earliestBeginDate = Date().addingTimeInterval(6 * 3_600)
    // The system may deny or never grant this request. Ordinary app opportunities remain sufficient.
    try? BGTaskScheduler.shared.submit(request)
  }
}
#endif
