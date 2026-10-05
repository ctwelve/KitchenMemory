// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Local evidence of a successful managed import or export, never replica completion.
public struct SynchronizationObservation: Codable, Equatable, Sendable {
  /// The local beginning of this owner/store observation window.
  public let beganObservingAt: Date
  /// The latest observed successful managed transfer end date, without claiming replica completion.
  public private(set) var lastSuccessfulEventAt: Date?

  /// Creates an owner/store-scoped local observation without verifying synchronization.
  public init(beganObservingAt: Date, lastSuccessfulEventAt: Date? = nil) {
    self.beganObservingAt = beganObservingAt
    self.lastSuccessfulEventAt = lastSuccessfulEventAt
  }

  /// Retains the latest success on or after the observation start, ignoring older dates.
  public mutating func recordSuccess(at date: Date) {
    guard date >= beganObservingAt else { return }
    lastSuccessfulEventAt = max(lastSuccessfulEventAt ?? date, date)
  }

  /// Whether seven days have passed since the last success, or since observation began.
  ///
  /// A false result describes only a local observation and cannot prove that another
  /// device received any retained evidence.
  public func isStale(at date: Date) -> Bool {
    date.timeIntervalSince(lastSuccessfulEventAt ?? beganObservingAt) >= 7 * 86_400
  }
}
