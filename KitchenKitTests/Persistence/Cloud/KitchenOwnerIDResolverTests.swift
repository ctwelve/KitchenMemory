// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import XCTest

final class KitchenOwnerIDResolverTests: XCTestCase {
  func testCloudKitIdentityRemainsOpaqueAndContainerScoped() {
    XCTAssertEqual(
      CloudKitKitchenOwnerIDResolver.ownerID(
        containerIdentifier: "iCloud.net.ctwelve.KitchenMemory",
        userRecordName: "opaque-current-user"
      ),
      KitchenOwner.ID(
        rawValue: "cloudkit:iCloud.net.ctwelve.KitchenMemory:opaque-current-user"
      )
    )
  }
}
