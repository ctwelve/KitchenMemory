// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenMemory
import UndoKit

@MainActor
final class UndoQualificationRig {
  let directory: URL
  let scope = UUID()
  let working = UUID()
  let owners = HistorySessions()
  private(set) var host: UndoQualificationHost
  private(set) var operation: HistoryOperation<UndoQualificationChange>
  private(set) var session: HistorySession

  init() async throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let host = UndoQualificationHost(url: directory.appendingPathComponent("Host.json"), initial: [
      UndoQualificationItem(id: UUID(), title: "Soup"), UndoQualificationItem(id: UUID(), title: "Bread"),
    ])
    self.host = host
    operation = try qualificationOperation(host)
    session = await owners.open(configuration: qualificationConfiguration(directory, scope: scope,
      working: working, mode: .create), lease: host, operations: [operation.erased])
  }

  func reopen(withholdOutcomes: Bool = false) async throws {
    await session.close()
    host = UndoQualificationHost(url: directory.appendingPathComponent("Host.json"), initial: [])
    host.withholdOutcomes = withholdOutcomes
    operation = try qualificationOperation(host)
    session = await owners.open(configuration: qualificationConfiguration(directory, scope: scope,
      working: working, mode: .existing), lease: host, operations: [operation.erased])
  }

  func remove() async {
    await owners.closeAll()
    try? FileManager.default.removeItem(at: directory)
  }
}
