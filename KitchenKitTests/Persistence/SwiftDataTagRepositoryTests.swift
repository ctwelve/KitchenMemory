// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
@testable import KitchenKit
import SwiftData
import XCTest

@MainActor
final class SwiftDataTagRepositoryTests: XCTestCase {
  func testRelaunchAndCompactionPreserveTagAndSuppressExactRetry() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "Tags.store")
    let kitchen = Kitchen(name: "Home")
    let tagID = Tag.ID()
    let command: TagCommand
    do {
      let container = try KitchenMemorySchema.makeContainer(storeURL: url)
      try SwiftDataRecipeRepository(modelContainer: container).save(kitchen)
      let repository = SwiftDataTagRepository(modelContainer: container)
      command = try repository.library(in: kitchen.id).prepare(
        .create(id: tagID, name: "Meals"), at: Date(timeIntervalSince1970: 0)
      )
      try repository.append(command)
      try repository.append(command)
      XCTAssertNotNil(try repository.compact(in: kitchen.id, at: Date(timeIntervalSince1970: 40 * 86_400)))
    }
    let reopened = SwiftDataTagRepository(modelContainer: try KitchenMemorySchema.makeContainer(storeURL: url))
    XCTAssertEqual(try reopened.library(in: kitchen.id).tags.map(\.id), [tagID])
    try reopened.append(command)
    XCTAssertNil(try reopened.compact(in: kitchen.id, at: Date(timeIntervalSince1970: 50 * 86_400)))
    XCTAssertEqual(try reopened.library(in: kitchen.id).tags.map(\.name), ["Meals"])
  }
  func testConvergenceAndResetIncludeRawActionsAndCheckpoints() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let recipes = SwiftDataRecipeRepository(modelContainer: container)
    let tags = SwiftDataTagRepository(modelContainer: container)
    let legacy = Kitchen(name: "Legacy")
    try recipes.save(legacy)
    let first = try tags.library(in: legacy.id).prepare(
      .create(id: Tag.ID(), name: "Old"), at: Date(timeIntervalSince1970: 0)
    )
    try tags.append(first)
    try tags.compact(in: legacy.id, at: Date(timeIntervalSince1970: 40 * 86_400))
    let second = try tags.library(in: legacy.id).prepare(.create(id: Tag.ID(), name: "New"))
    try tags.append(second)
    let personal = Kitchen(name: "Personal")
    try recipes.convergeKitchens(into: personal, ownedBy: KitchenOwner.ID(rawValue: "tag-test-owner"))
    XCTAssertEqual(Set(try tags.library(in: personal.id).tags.map(\.name)), ["Old", "New"])
    XCTAssertTrue(try tags.library(in: legacy.id).tags.isEmpty)
    try SwiftDataKitchenResetRepository(modelContainer: container).reset(kitchenID: personal.id, to: [])
    XCTAssertTrue(try tags.library(in: personal.id).tags.isEmpty)
  }

  func testDamagedCheckpointRemainsRecoveryInsteadOfAnEmptyLibrary() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let kitchen = Kitchen(name: "Home")
    try SwiftDataRecipeRepository(modelContainer: container).save(kitchen)
    let tags = SwiftDataTagRepository(modelContainer: container)
    try tags.append(tags.library(in: kitchen.id).prepare(
      .create(id: Tag.ID(), name: "Meals"), at: Date(timeIntervalSince1970: 0)
    ))
    try tags.compact(in: kitchen.id, at: Date(timeIntervalSince1970: 40 * 86_400))
    let context = ModelContext(container)
    let checkpoint = try XCTUnwrap(context.fetch(FetchDescriptor<OrganizationCheckpointRecord>()).first)
    checkpoint.formatVersion = 999
    try context.save()
    XCTAssertThrowsError(try tags.library(in: kitchen.id))
    checkpoint.formatVersion = 1
    checkpoint.checkpointDigest = Data([0])
    try context.save()
    XCTAssertThrowsError(try tags.library(in: kitchen.id))
  }

  func testActionIdentityCannotBeReusedAcrossKitchens() throws {
    let container = try KitchenMemorySchema.makeContainer(inMemory: true)
    let recipes = SwiftDataRecipeRepository(modelContainer: container)
    let tags = SwiftDataTagRepository(modelContainer: container)
    let home = Kitchen(name: "Home")
    let away = Kitchen(name: "Away")
    try recipes.save(home)
    try recipes.save(away)
    let command = try tags.library(in: home.id).prepare(.create(id: Tag.ID(), name: "Home"))
    try tags.append(command)
    let impostor = try tags.library(in: away.id).prepare(.create(id: Tag.ID(), name: "Away"),
                                                            id: command.id)
    XCTAssertThrowsError(try tags.append(impostor)) { error in
      XCTAssertEqual(error as? TagError, .wrongKitchen)
    }
    XCTAssertEqual(try tags.library(in: home.id).tags.map(\.name), ["Home"])
    XCTAssertTrue(try tags.library(in: away.id).tags.isEmpty)
  }

}
