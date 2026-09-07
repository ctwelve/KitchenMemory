// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CoreData
import Foundation
import KitchenKit
import SwiftData
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Coalesces application opportunities; the repository owns all evidence eligibility.
@MainActor
final class AppRecordsMaintenance: NSObject {
  private let repository: RecordsMaintenanceRepository
  private let container: ModelContainer
  private let defaults: UserDefaults?
  private let key: String
  private var schedule: RecordsMaintenanceSchedule
  private var observation: SynchronizationObservation
  private let observesCloud: Bool
  private let refresh: () -> Void
  private let showRisk: (Bool) -> Void
  private let now: () -> Date
  private var task: Task<Void, Never>?
#if os(macOS)
  private let activity = NSBackgroundActivityScheduler(identifier: "net.ctwelve.KitchenMemory.maintenance")
#endif

  init(container: ModelContainer, kitchenID: Kitchen.ID, scope: String,
       defaults: UserDefaults?, observesCloud: Bool, automaticallyRuns: Bool = true,
       now: @escaping () -> Date = Date.init,
       refresh: @escaping () -> Void, showRisk: @escaping (Bool) -> Void) {
    self.container = container
    repository = RecordsMaintenanceRepository(modelContainer: container, kitchenID: kitchenID)
    self.defaults = defaults
    key = "records-maintenance.\(scope)"
    schedule = defaults?.data(forKey: key + ".schedule").flatMap {
      try? JSONDecoder().decode(RecordsMaintenanceSchedule.self, from: $0)
    } ?? RecordsMaintenanceSchedule()
    observation = defaults?.data(forKey: key + ".observation").flatMap {
      try? JSONDecoder().decode(SynchronizationObservation.self, from: $0)
    } ?? SynchronizationObservation(beganObservingAt: now())
    self.now = now
    self.observesCloud = observesCloud
    self.refresh = refresh
    self.showRisk = showRisk
    super.init()
    if observesCloud { saveObservation() }
    guard automaticallyRuns else { return }
    NotificationCenter.default.addObserver(self, selector: #selector(didSave),
      name: ModelContext.didSave, object: nil)
#if os(macOS)
    NotificationCenter.default.addObserver(self, selector: #selector(foreground),
      name: NSApplication.didBecomeActiveNotification, object: nil)
    activity.interval = 6 * 3_600
    activity.tolerance = 3 * 3_600
    activity.repeats = true
    activity.schedule { [weak self] completion in
      Task { @MainActor in
        await self?.performOpportunity()
        completion(.finished)
      }
    }
#else
    NotificationCenter.default.addObserver(self, selector: #selector(foreground),
      name: UIApplication.didBecomeActiveNotification, object: nil)
#endif
    opportunity()
  }

  isolated deinit {
    task?.cancel()
#if os(macOS)
    activity.invalidate()
#endif
    NotificationCenter.default.removeObserver(self)
  }

  var storeIdentifiers: Set<String> {
    Set(container.configurations.compactMap { configuration in
      guard !configuration.isStoredInMemoryOnly else { return nil }
      let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(
        ofType: NSSQLiteStoreType, at: configuration.url, options: nil
      )
      return metadata?[NSStoreUUIDKey] as? String
    })
  }

  func observedSuccessfulTransfer(at date: Date) {
    guard observesCloud else { return }
    observation.recordSuccess(at: date)
    saveObservation()
    showRisk(observation.isStale(at: now()))
    opportunity()
  }

  func performOpportunity() async {
    opportunity()
    await withTaskCancellationHandler {
      await task?.value
    } onCancel: {
      Task { @MainActor [weak self] in self?.task?.cancel() }
    }
  }

  func opportunity() {
    showRisk(observesCloud && observation.isStale(at: now()))
    guard task == nil else { return }
    task = Task { [weak self] in
      // Let the ready application surface render before any maintenance starts.
      await Task.yield()
      guard let self else { return }
      defer { task = nil }
      // One finite round, with a suspension point between atomic repository jobs.
      for job in schedule.due(at: now()) {
        guard !Task.isCancelled else { break }
        let date = now()
        let completed = (try? repository.run(job, at: date)) == true
        schedule.record(job, at: date, completed: completed)
        if let encoded = try? JSONEncoder().encode(schedule) {
          defaults?.set(encoded, forKey: key + ".schedule")
        }
        await Task.yield()
      }
      refresh()
    }
  }

  @objc nonisolated private func foreground() {
    Task { @MainActor [weak self] in self?.opportunity() }
  }

  @objc nonisolated private func didSave() {
    // A save is only an opportunity hint, never evidence of successful synchronization.
    Task { @MainActor [weak self] in self?.opportunity() }
  }

  private func saveObservation() {
    if let data = try? JSONEncoder().encode(observation) {
      defaults?.set(data, forKey: key + ".observation")
    }
  }
}

@MainActor
func makeRecordsMaintenance(
  plan: AppLaunchPlan, core: PreparedCore, sessionModel: CookingSessionPresentationModel
) -> AppRecordsMaintenance {
  AppRecordsMaintenance(
    container: core.modelContainer, kitchenID: core.kitchenID,
    scope: "\(core.ownerID.rawValue).\(plan.store.personalCloudContainerIdentifier ?? "local")",
    defaults: plan.store.isInMemory ? nil : .standard,
    observesCloud: plan.store.personalCloudContainerIdentifier != nil,
    automaticallyRuns: !plan.store.isInMemory,
    refresh: {
      performExternalStoreRefresh(libraryModel: core.libraryModel,
        sessionRepository: core.cookingSessionRepository, sessionModel: sessionModel)
    },
    showRisk: { core.libraryModel.synchronizationEvidenceIsStale = $0 }
  )
}
