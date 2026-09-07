// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenKit
import XCTest

final class OrganizationCollationTests: XCTestCase {
  func testLocaleOrderingMatchesSystemCollationWithoutRewritingUserNames() throws {
    let kitchen = Kitchen.ID()
    let names = ["Äpfel", "Zitrone", "Épices", "Ñame", "2 herbs", "10 herbs"]
    let emptyFolders = try FolderLibrary(kitchenID: kitchen, commands: [])
    let emptyTags = try TagLibrary(kitchenID: kitchen, commands: [])
    let folders = try FolderLibrary(kitchenID: kitchen, commands: names.map {
      try emptyFolders.prepare(.create(id: Folder.ID(), name: $0, parentID: nil))
    })
    let tags = try TagLibrary(kitchenID: kitchen, commands: names.reversed().map {
      try emptyTags.prepare(.create(id: Tag.ID(), name: $0))
    })
    for language in ["en-US", "es-MX", "fr-CA", "sv-SE"] {
      let locale = Locale(identifier: language)
      let expected = names.sorted { $0.compare($1, options: .caseInsensitive, locale: locale) == .orderedAscending }
      XCTAssertEqual(folders.children(of: nil, locale: locale).map(\.name), expected)
      XCTAssertEqual(tags.orderedTags(locale: locale).map(\.name), expected)
      XCTAssertEqual(Set(folders.folders.map(\.name)), Set(names))
      XCTAssertEqual(Set(tags.tags.map(\.name)), Set(names))
    }
    XCTAssertNotEqual(folders.children(of: nil, locale: Locale(identifier: "en-US")).map(\.id),
      folders.children(of: nil, locale: Locale(identifier: "sv-SE")).map(\.id))
  }
}
