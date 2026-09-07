// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
@testable import KitchenMemory
import XCTest

@MainActor
final class AppRecordsMaintenanceTests: XCTestCase {
  func testLocalObservationSurvivesRelaunchAndWarningRecovers() async throws {
    let fixture = try makeTestUserDefaults(suiteNamePrefix: "maintenance-observation")
    let app = try AppRuntime.testing(.init(library: .empty))
    var date = Date(timeIntervalSince1970: 1_700_000_000)
    var warnings: [Bool] = []
    var refreshes = 0
    func makeAdapter(cloud: Bool = true) -> AppRecordsMaintenance {
      AppRecordsMaintenance(container: app.modelContainer, kitchenID: KitchenBootstrapService.personalKitchenID,
        scope: "test", defaults: fixture.defaults, observesCloud: cloud, automaticallyRuns: false,
        now: { date }, refresh: { refreshes += 1 }, showRisk: { warnings.append($0) })
    }
    var adapter: AppRecordsMaintenance? = makeAdapter()
    XCTAssertTrue(try XCTUnwrap(adapter).storeIdentifiers.isEmpty)
    await adapter?.performOpportunity()
    XCTAssertFalse(try XCTUnwrap(warnings.last))
    XCTAssertEqual(refreshes, 1)
    adapter = nil
    date = date.addingTimeInterval(8 * 86_400)
    adapter = makeAdapter()
    await adapter?.performOpportunity()
    XCTAssertTrue(try XCTUnwrap(warnings.last))
    adapter?.observedSuccessfulTransfer(at: date)
    await adapter?.performOpportunity()
    XCTAssertFalse(try XCTUnwrap(warnings.last))
    adapter = nil
    adapter = makeAdapter()
    await adapter?.performOpportunity()
    XCTAssertFalse(try XCTUnwrap(warnings.last))
    date = date.addingTimeInterval(8 * 86_400)
    adapter = makeAdapter(cloud: false)
    await adapter?.performOpportunity()
    XCTAssertFalse(try XCTUnwrap(warnings.last))
  }
}
