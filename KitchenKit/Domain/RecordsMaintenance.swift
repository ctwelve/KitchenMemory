// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Independent eligibility checks share one resumable opportunity budget.
public enum RecordsMaintenanceJob: String, CaseIterable, Codable, Sendable {
  case deletedRecipes
  case folders
  case tags
  case recipeTombstones
  case folderCheckpoints
  case tagCheckpoints
  case folderOrphans
  case tagOrphans

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

  public init() {}

  public func next(at date: Date) -> RecordsMaintenanceJob? {
    due(at: date).first
  }

  public func due(at date: Date) -> [RecordsMaintenanceJob] {
    let jobs = RecordsMaintenanceJob.allCases
    let offset = abs(nextIndex % jobs.count)
    return (0..<jobs.count).map { jobs[(offset + $0) % jobs.count] }.filter { job in
      guard let completed = completedAt[job] else { return true }
      // A wall-clock correction must not postpone maintenance indefinitely.
      return date < completed || date.timeIntervalSince(completed) >= job.interval
    }
  }

  public func continuation(for job: RecordsMaintenanceJob) -> String? { continuations[job] }

  public mutating func record(
    _ job: RecordsMaintenanceJob, at date: Date, completed: Bool, continuation: String? = nil
  ) {
    continuations[job] = continuation
    if completed { completedAt[job] = date }
    nextIndex = (RecordsMaintenanceJob.allCases.firstIndex(of: job)! + 1)
      % RecordsMaintenanceJob.allCases.count
  }
}
