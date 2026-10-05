// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Independent eligibility checks share one resumable opportunity budget.
public enum RecordsMaintenanceJob: String, CaseIterable, Codable, Sendable {
  /// Rechecks eligible deleted Recipe payload pruning.
  case deletedRecipes
  /// Rechecks eligible Folder evidence compaction.
  case folders
  /// Rechecks eligible Tag evidence compaction.
  case tags
  /// Rechecks expiry of compact Recipe anti-resurrection evidence.
  case recipeTombstones
  /// Rechecks expired Folder checkpoints only when newer evidence covers them.
  case folderCheckpoints
  /// Rechecks expired Tag checkpoints only when newer evidence covers them.
  case tagCheckpoints
  /// Rechecks old raw Folder copies whose exact receipts remain checkpointed.
  case folderOrphans
  /// Rechecks old raw Tag copies whose exact receipts remain checkpointed.
  case tagOrphans

  /// The suggested local opportunity interval, independent of retention eligibility.
  ///
  /// Compaction and pruning use six hours, compact-evidence expiry one day, and
  /// orphan sweeps one week; these are not execution deadlines.
  public var interval: TimeInterval {
    switch self {
    case .deletedRecipes, .folders, .tags: 6 * 3_600
    case .recipeTombstones, .folderCheckpoints, .tagCheckpoints: 86_400
    case .folderOrphans, .tagOrphans: 7 * 86_400
    }
  }
}

/// Device-local scheduling hints. Losing them repeats safe work rather than losing evidence.
public struct RecordsMaintenanceSchedule: Codable, Equatable, Sendable {
  private var completedAt: [RecordsMaintenanceJob: Date] = [:]
  private var nextIndex = 0
  private var continuations: [RecordsMaintenanceJob: String] = [:]

  /// Creates an empty local schedule, making every job initially due.
  public init() {}

  /// Returns the first due job in the rotating opportunity order, or nil when none are due.
  public func next(at date: Date) -> RecordsMaintenanceJob? {
    due(at: date).first
  }

  /// Returns each due job once in rotating order.
  ///
  /// Never-completed jobs are due. A backward wall-clock correction also makes a job
  /// due so a future completion timestamp cannot indefinitely postpone maintenance.
  public func due(at date: Date) -> [RecordsMaintenanceJob] {
    let jobs = RecordsMaintenanceJob.allCases
    let offset = abs(nextIndex % jobs.count)
    return (0..<jobs.count).map { jobs[(offset + $0) % jobs.count] }.filter { job in
      guard let completed = completedAt[job] else { return true }
      // A wall-clock correction must not postpone maintenance indefinitely.
      return date < completed || date.timeIntervalSince(completed) >= job.interval
    }
  }

  /// Returns the opaque local candidate cursor for this job, if one was retained.
  public func continuation(for job: RecordsMaintenanceJob) -> String? { continuations[job] }

  /// Stores the cursor and rotates the next opportunity past this job.
  ///
  /// Only a completed opportunity updates its completion date. These are replay-safe
  /// scheduling hints and never evidence that deletion or synchronization is safe.
  public mutating func record(
    _ job: RecordsMaintenanceJob, at date: Date, completed: Bool, continuation: String? = nil
  ) {
    continuations[job] = continuation
    if completed { completedAt[job] = date }
    nextIndex = (RecordsMaintenanceJob.allCases.firstIndex(of: job)! + 1)
      % RecordsMaintenanceJob.allCases.count
  }
}
