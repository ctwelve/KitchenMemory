// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Local evidence of a successful managed import or export, never replica completion.
public struct SynchronizationObservation: Codable, Equatable, Sendable {
  public let beganObservingAt: Date
  public private(set) var lastSuccessfulEventAt: Date?

  public init(beganObservingAt: Date, lastSuccessfulEventAt: Date? = nil) {
    self.beganObservingAt = beganObservingAt
    self.lastSuccessfulEventAt = lastSuccessfulEventAt
  }

  public mutating func recordSuccess(at date: Date) {
    guard date >= beganObservingAt else { return }
    lastSuccessfulEventAt = max(lastSuccessfulEventAt ?? date, date)
  }

  public func isStale(at date: Date) -> Bool {
    date.timeIntervalSince(lastSuccessfulEventAt ?? beganObservingAt) >= 7 * 86_400
  }
}
