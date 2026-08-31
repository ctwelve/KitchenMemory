// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CoreData
import Foundation
import KitchenKit
import SwiftData

@main
private enum CloudKitProductionSchemaAdmin {
  static let acceptedContainer = "iCloud.net.ctwelve.KitchenMemory"
  static let expectedArguments = ["initialize", "--candidate"]

  static func main() {
    guard CommandLine.arguments.count == 4,
          Array(CommandLine.arguments[1...2]) == expectedArguments else {
      fputs("Usage: CloudKitProductionSchemaAdmin initialize --candidate <commit>\n", stderr)
      exit(64)
    }

    let candidate = CommandLine.arguments[3]
    guard candidate.range(of: #"^[0-9a-f]{40}$"#, options: .regularExpression) != nil else {
      fputs("The accepted candidate must be a full lowercase Git commit.\n", stderr)
      exit(64)
    }

    do {
      try initialize(candidate: candidate)
    } catch {
      fputs("Schema initialization failed: \(type(of: error))\n", stderr)
      exit(1)
    }
  }

  private static func initialize(candidate: String) throws {
    let schema = Schema(versionedSchema: KitchenMemorySchemaV4.self)
    guard let model = NSManagedObjectModel.makeManagedObjectModel(
      for: KitchenMemorySchemaV4.models
    ) else {
      throw SchemaAdministrationError.managedObjectModelUnavailable
    }

    let disposableRoot = FileManager.default.temporaryDirectory.appending(
      path: "KitchenMemoryProductionSchemaAdmin-\(UUID().uuidString)",
      directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
      at: disposableRoot,
      withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: disposableRoot) }

    let configuration = ModelConfiguration(
      "KitchenMemoryProductionSchemaAdmin",
      schema: schema,
      url: disposableRoot.appending(path: "Schema.sqlite"),
      cloudKitDatabase: .private(acceptedContainer)
    )
    let description = NSPersistentStoreDescription(url: configuration.url)
    description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
      containerIdentifier: acceptedContainer
    )
    description.shouldAddStoreAsynchronously = false

    let container = NSPersistentCloudKitContainer(
      name: "KitchenMemoryProductionSchemaAdmin",
      managedObjectModel: model
    )
    container.persistentStoreDescriptions = [description]
    var loadError: (any Error)?
    container.loadPersistentStores { _, error in loadError = error }
    if let loadError { throw loadError }

    try container.initializeCloudKitSchema()
    guard let store = container.persistentStoreCoordinator.persistentStores.first else {
      throw SchemaAdministrationError.persistentStoreUnavailable
    }
    try container.persistentStoreCoordinator.remove(store)

    let output = "{\"candidate\":\"\(candidate)\","
      + "\"container\":\"production-container\",\"environment\":\"development\","
      + "\"schema\":\"V4\",\"result\":\"operation-succeeded\","
      + "\"productionDeployed\":false}"
    print(output)
  }
}

private enum SchemaAdministrationError: Error {
  case managedObjectModelUnavailable
  case persistentStoreUnavailable
}
