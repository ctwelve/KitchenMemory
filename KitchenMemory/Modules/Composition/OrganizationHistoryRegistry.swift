// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CryptoKit
import Foundation
import KitchenKit
import Observation

/// Owns durable scene identities independently from their current native presentations.
@MainActor
@Observable
final class OrganizationHistoryRegistry {
  private static var active: [String: WeakOrganizationHistoryRegistry] = [:]
  private var sceneSessions: [String: UUID] = [:]
  private let repository: any RecipeOrganizationHistoryRepository
  private let organization: RecipeOrganizationModel
  private let ownerID: KitchenOwner.ID
  private let storeID: String
  private let kitchenID: Kitchen.ID
  private let directory: URL
  private(set) var generation: UUID
  private var presentations: [UUID: OrganizationHistoryPresentation] = [:]
  private var unavailable = false

  init(repository: any RecipeOrganizationHistoryRepository, organization: RecipeOrganizationModel,
       ownerID: KitchenOwner.ID, storeID: String, kitchenID: Kitchen.ID, directory: URL) throws {
    self.repository = repository
    self.organization = organization
    self.ownerID = ownerID
    self.storeID = storeID
    self.kitchenID = kitchenID
    self.directory = directory
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Self.retirePreviousScope(beforeOpening: directory)
    let marker = directory.appendingPathComponent("Generation.json")
    if FileManager.default.fileExists(atPath: marker.path) {
      generation = try JSONDecoder().decode(UUID.self, from: Data(contentsOf: marker))
    } else {
      generation = UUID()
      try JSONEncoder().encode(generation).write(to: marker, options: .atomic)
    }
    unavailable = FileManager.default.fileExists(atPath: directory.appendingPathComponent("Invalidating").path)
    let sessionsURL = directory.appendingPathComponent("SceneSessions.json")
    if FileManager.default.fileExists(atPath: sessionsURL.path) {
      sceneSessions = try JSONDecoder().decode([String: UUID].self, from: Data(contentsOf: sessionsURL))
    }
    let ownershipKey = directory.deletingLastPathComponent().path
    if let previous = Self.active[ownershipKey]?.value, previous.directory != directory {
      previous.presentations.values.forEach { $0.block() }
      previous.unavailable = true
    }
    Self.active[ownershipKey] = WeakOrganizationHistoryRegistry(value: self)
  }

  func presentation(for sceneID: UUID) -> OrganizationHistoryPresentation {
    if let existing = presentations[sceneID] { return existing }
    let disposed = directory.appendingPathComponent(sceneID.uuidString + ".disposed")
    let value = OrganizationHistoryPresentation(
      history: RecipeOrganizationHistory(repository: repository), organization: organization,
      scope: RecipeOrganizationHistoryScope(ownerID: ownerID, storeID: storeID,
        kitchenID: kitchenID, logicalSceneID: sceneID),
      historyURL: directory.appendingPathComponent(generation.uuidString, isDirectory: true)
        .appendingPathComponent(sceneID.uuidString, isDirectory: true).appendingPathComponent("History.sqlite"),
      available: !unavailable && !FileManager.default.fileExists(atPath: disposed.path),
      dispose: { [weak self] in self?.dispose(sceneID) },
      recordSession: { [weak self] sessionID in self?.recordSession(sessionID, for: sceneID) })
    presentations[sceneID] = value
    return value
  }

  /// Invalidation intent survives a failed generation write. Reset cannot touch domain data until this succeeds.
  func prepareForReset() throws {
    presentations.values.forEach { $0.block() }
    unavailable = true
    let intent = directory.appendingPathComponent("Invalidating")
    try Data("reset".utf8).write(to: intent, options: .atomic)
    let next = UUID()
    try JSONEncoder().encode(next).write(to: directory.appendingPathComponent("Generation.json"), options: .atomic)
    generation = next
    try FileManager.default.removeItem(at: intent)
    presentations = [:]
    unavailable = false
  }

  static func discardSceneSessions(_ identifiers: Set<String>) {
    for registry in active.values.compactMap(\.value) {
      for identifier in identifiers {
        if let sceneID = registry.sceneSessions[identifier] { registry.dispose(sceneID) }
      }
    }
  }

  private func recordSession(_ identifier: String, for sceneID: UUID) {
    guard sceneSessions[identifier] != sceneID else { return }
    sceneSessions[identifier] = sceneID
    do {
      let data = try JSONEncoder().encode(sceneSessions)
      try data.write(to: directory.appendingPathComponent("SceneSessions.json"), options: .atomic)
    } catch { presentations[sceneID]?.block() }
  }

  private func dispose(_ sceneID: UUID) {
    presentations[sceneID]?.block()
    do {
      let marker = directory.appendingPathComponent(sceneID.uuidString + ".disposed")
      try Data("disposed".utf8).write(to: marker, options: .atomic)
    } catch {
      // A failed disposal marker also retires the whole scope before a later restoration can expose it.
      try? prepareForReset()
    }
  }

  private static func retirePreviousScope(beforeOpening directory: URL) throws {
    let root = directory.deletingLastPathComponent()
    let pointer = root.appendingPathComponent("ActiveScope.json")
    let current = directory.lastPathComponent
    if FileManager.default.fileExists(atPath: pointer.path) {
      let previous = try JSONDecoder().decode(String.self, from: Data(contentsOf: pointer))
      guard previous.count == 64, previous.allSatisfy({ $0.isHexDigit }) else {
        throw CocoaError(.fileReadCorruptFile)
      }
      if previous != current {
        let retired = root.appendingPathComponent(previous, isDirectory: true)
        let intent = retired.appendingPathComponent("Invalidating")
        try Data("scope-change".utf8).write(to: intent, options: .atomic)
        try JSONEncoder().encode(UUID()).write(to: retired.appendingPathComponent("Generation.json"), options: .atomic)
        try FileManager.default.removeItem(at: intent)
      }
    }
    try JSONEncoder().encode(current).write(to: pointer, options: .atomic)
  }

  static func directory(ownerID: KitchenOwner.ID, storeID: String, kitchenID: Kitchen.ID,
                        inMemory: Bool) throws -> URL {
    let base = inMemory ? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
      : try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                    appropriateFor: nil, create: true)
    let identity = try JSONEncoder().encode([ownerID.rawValue, storeID, kitchenID.rawValue.uuidString])
    let digest = SHA256.hash(data: identity).map { String(format: "%02x", $0) }.joined()
    return base.appendingPathComponent("RecipeOrganizationHistory", isDirectory: true)
      .appendingPathComponent(digest, isDirectory: true)
  }
}

@MainActor
private final class WeakOrganizationHistoryRegistry {
  weak var value: OrganizationHistoryRegistry?
  init(value: OrganizationHistoryRegistry) { self.value = value }
}
