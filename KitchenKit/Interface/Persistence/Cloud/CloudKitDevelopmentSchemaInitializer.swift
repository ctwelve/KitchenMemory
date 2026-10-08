// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

#if DEVELOP && os(macOS)
import CoreData
import Foundation
import SwiftData

/// Creates or additively updates the development CloudKit schema on demand.
///
/// This follows Apple's required handoff: Core Data temporarily owns the same
/// store long enough to initialize its generated CloudKit schema, unloads it,
/// and only then lets the app create its ordinary SwiftData container. Normal
/// launches never perform schema administration.
public enum CloudKitDevelopmentSchemaInitializer {
  enum InitializationError: Error {
    case managedObjectModelUnavailable
    case persistentStoreUnavailable
  }

  /// Explicitly initializes the additive Development schema using the current generated model.
  /// Run before constructing the ordinary SwiftData container for this store; Core Data
  /// temporarily owns and then unloads it. Available only in Develop macOS builds.
  /// Model generation, store loading, initialization, or unloading failures throw.
  public static func initialize(containerIdentifier: String) throws {
    try autoreleasepool {
      let schema = Schema(versionedSchema: CurrentKitchenMemorySchema.self)
      let configuration = ModelConfiguration(
        "KitchenMemory",
        schema: schema,
        cloudKitDatabase: .private(containerIdentifier)
      )
      let description = NSPersistentStoreDescription(url: configuration.url)
      description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
        containerIdentifier: containerIdentifier
      )
      description.shouldAddStoreAsynchronously = false

      guard let model = NSManagedObjectModel.makeManagedObjectModel(
        for: CurrentKitchenMemorySchema.models
      ) else {
        throw InitializationError.managedObjectModelUnavailable
      }

      let container = NSPersistentCloudKitContainer(
        name: "KitchenMemory",
        managedObjectModel: model
      )
      container.persistentStoreDescriptions = [description]
      var loadError: (any Error)?
      container.loadPersistentStores { _, error in loadError = error }
      if let loadError { throw loadError }

      try container.initializeCloudKitSchema()
      print("Kitchen Memory CloudKit development schema initialized.")
      guard let store = container.persistentStoreCoordinator.persistentStores.first else {
        throw InitializationError.persistentStoreUnavailable
      }
      try container.persistentStoreCoordinator.remove(store)
    }
  }
}
#endif
