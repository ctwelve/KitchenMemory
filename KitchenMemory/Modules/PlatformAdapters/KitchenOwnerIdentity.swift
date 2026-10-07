// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit

enum KitchenOwnerIdentity {
  private static let defaultsKey = "KitchenMemory.kitchenOwnerID"

  static func resolve(
    plan: AppLaunchPlan,
    inputs: AppLaunchInputs
  ) async throws -> KitchenOwner.ID {
    if plan.store.isInMemory {
      return KitchenOwner.ID(rawValue: "testing:personal-kitchen-owner")
    }
    if inputs.buildEnvironment.synchronizesWithPersonalCloud,
      let containerIdentifier = inputs.infoDictionary[AppLaunchInputs.cloudKitContainerInfoKey]
        as? String {
      return try await resolveCloudOwner(containerIdentifier: containerIdentifier)
    }
    if let cached = UserDefaults.standard.string(forKey: defaultsKey) {
      return KitchenOwner.ID(rawValue: cached)
    }
    let ownerID = KitchenOwner.ID(rawValue: "local:\(UUID().uuidString)")
    UserDefaults.standard.set(ownerID.rawValue, forKey: defaultsKey)
    return ownerID
  }

  private static func resolveCloudOwner(
    containerIdentifier: String
  ) async throws -> KitchenOwner.ID {
    do {
      let ownerID = try await CloudKitKitchenOwnerIDResolver(
        containerIdentifier: containerIdentifier
      ).ownerID()
      UserDefaults.standard.set(ownerID.rawValue, forKey: defaultsKey)
      return ownerID
    } catch {
      guard let cached = UserDefaults.standard.string(forKey: defaultsKey) else {
        throw error
      }
      return KitchenOwner.ID(rawValue: cached)
    }
  }
}
