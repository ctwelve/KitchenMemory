// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CryptoKit
import Foundation

/// A caller-owned command choosing which accepted Recipe Revision is current.
public struct RecipeSelectionCommand: Equatable, Sendable {
  public typealias ID = StableIdentifier<RecipeSelectionCommand>

  public let id: ID
  public let kitchenID: Kitchen.ID
  public let recipeID: Recipe.ID
  public let selectedRevisionID: RecipeRevision.ID
  public let selectedAt: Date
  public let observedSelectionIDs: [ID]

  public init(
    id: ID = ID(),
    kitchenID: Kitchen.ID,
    recipeID: Recipe.ID,
    selectedRevisionID: RecipeRevision.ID,
    selectedAt: Date = Date(),
    observedSelectionIDs: [ID] = []
  ) {
    self.id = id
    self.kitchenID = kitchenID
    self.recipeID = recipeID
    self.selectedRevisionID = selectedRevisionID
    self.selectedAt = selectedAt
    self.observedSelectionIDs = observedSelectionIDs
  }
}

/// One retry-safe intention to append immutable Recipe content and select it.
public struct RecipeSaveCommand: Equatable, Sendable {
  public typealias ID = StableIdentifier<RecipeSaveCommand>

  public let id: ID
  public let recipe: Recipe
  public let revision: RecipeRevision
  public let savedAt: Date
  public let parentRevisionIDs: [RecipeRevision.ID]
  public let selection: RecipeSelectionCommand

  public init(
    id: ID = ID(),
    recipe: Recipe,
    revision: RecipeRevision,
    savedAt: Date = Date(),
    parentRevisionIDs: [RecipeRevision.ID],
    selection: RecipeSelectionCommand
  ) {
    self.id = id
    self.recipe = recipe
    self.revision = revision
    self.savedAt = savedAt
    self.parentRevisionIDs = parentRevisionIDs
    self.selection = selection
  }
}

public enum RecipeAuthorityCodecError: Error, Equatable {
  case malformedData
  case noncanonicalData
  case unsupportedFormat(Int)
}

public struct EncodedRecipeIdentifierSet: Equatable, Sendable {
  public let formatVersion: Int
  public let data: Data
}

/// Canonical format-1 sets are sorted raw UUID bytes with no delimiters.
public enum RecipeIdentifierSetCodec {
  public static let formatVersion = 1

  public static func encode(_ identifiers: [UUID]) -> EncodedRecipeIdentifierSet {
    let bytes = identifiers.map(uuidBytes).sorted(by: lexicographicallyPrecedes)
    return EncodedRecipeIdentifierSet(
      formatVersion: formatVersion,
      data: Data(bytes.flatMap { $0 })
    )
  }

  public static func decode(formatVersion: Int, data: Data) throws -> [UUID] {
    guard formatVersion == self.formatVersion else {
      throw RecipeAuthorityCodecError.unsupportedFormat(formatVersion)
    }
    guard data.count.isMultiple(of: 16) else {
      throw RecipeAuthorityCodecError.malformedData
    }
    let bytes = [UInt8](data)
    let identifiers = stride(from: 0, to: bytes.count, by: 16).map { offset in
      uuid(from: Array(bytes[offset..<(offset + 16)]))
    }
    guard Set(identifiers).count == identifiers.count,
      encode(identifiers).data == data
    else {
      throw RecipeAuthorityCodecError.noncanonicalData
    }
    return identifiers
  }
}

/// The exact ordered payload rows needed to reconstruct one Recipe Revision.
public struct RecipePayloadManifest: Equatable, Sendable {
  public let revisionID: RecipeRevision.ID
  public let mediaIDs: [RecipeMedia.ID]
  public let equipmentIDs: [EquipmentItem.ID]
  public let ingredientSectionIDs: [IngredientSection.ID]
  public let ingredientIDs: [RecipeIngredient.ID]
  public let instructionSectionIDs: [InstructionSection.ID]
  public let instructionStepIDs: [InstructionStep.ID]

  public init(revision: RecipeRevision) {
    revisionID = revision.id
    mediaIDs = revision.media.map(\.id)
    equipmentIDs = revision.equipment.map(\.id)
    ingredientSectionIDs = revision.ingredientSections.map(\.id)
    ingredientIDs = revision.ingredientSections.flatMap { $0.ingredients.map(\.id) }
    instructionSectionIDs = revision.instructionSections.map(\.id)
    instructionStepIDs = revision.instructionSections.flatMap { $0.steps.map(\.id) }
  }

  init(
    revisionID: RecipeRevision.ID,
    mediaIDs: [RecipeMedia.ID],
    equipmentIDs: [EquipmentItem.ID],
    ingredientSectionIDs: [IngredientSection.ID],
    ingredientIDs: [RecipeIngredient.ID],
    instructionSectionIDs: [InstructionSection.ID],
    instructionStepIDs: [InstructionStep.ID]
  ) {
    self.revisionID = revisionID
    self.mediaIDs = mediaIDs
    self.equipmentIDs = equipmentIDs
    self.ingredientSectionIDs = ingredientSectionIDs
    self.ingredientIDs = ingredientIDs
    self.instructionSectionIDs = instructionSectionIDs
    self.instructionStepIDs = instructionStepIDs
  }
}

public struct EncodedRecipePayloadManifest: Equatable, Sendable {
  public let formatVersion: Int
  public let data: Data
}

/// Format 1 is the root UUID followed by six fixed-order, big-endian-counted UUID lists.
public enum RecipePayloadManifestCodec {
  public static let formatVersion = 1

  public static func encode(_ manifest: RecipePayloadManifest) -> EncodedRecipePayloadManifest {
    var data = Data(uuidBytes(manifest.revisionID.rawValue))
    for identifiers in arrays(from: manifest) {
      var count = UInt32(identifiers.count).bigEndian
      withUnsafeBytes(of: &count) { data.append(contentsOf: $0) }
      for identifier in identifiers {
        data.append(contentsOf: uuidBytes(identifier))
      }
    }
    return EncodedRecipePayloadManifest(formatVersion: formatVersion, data: data)
  }

  public static func decode(formatVersion: Int, data: Data) throws -> RecipePayloadManifest {
    guard formatVersion == self.formatVersion else {
      throw RecipeAuthorityCodecError.unsupportedFormat(formatVersion)
    }
    var reader = RecipeManifestReader(data: data)
    guard let revisionID = reader.readUUID() else {
      throw RecipeAuthorityCodecError.malformedData
    }
    var arrays: [[UUID]] = []
    for _ in 0..<6 {
      guard let identifiers = reader.readUUIDArray() else {
        throw RecipeAuthorityCodecError.malformedData
      }
      arrays.append(identifiers)
    }
    guard reader.isAtEnd else { throw RecipeAuthorityCodecError.malformedData }
    guard arrays.allSatisfy({ Set($0).count == $0.count }) else {
      throw RecipeAuthorityCodecError.noncanonicalData
    }
    let manifest = RecipePayloadManifest(
      revisionID: .init(rawValue: revisionID),
      mediaIDs: arrays[0].map(RecipeMedia.ID.init(rawValue:)),
      equipmentIDs: arrays[1].map(EquipmentItem.ID.init(rawValue:)),
      ingredientSectionIDs: arrays[2].map(IngredientSection.ID.init(rawValue:)),
      ingredientIDs: arrays[3].map(RecipeIngredient.ID.init(rawValue:)),
      instructionSectionIDs: arrays[4].map(InstructionSection.ID.init(rawValue:)),
      instructionStepIDs: arrays[5].map(InstructionStep.ID.init(rawValue:))
    )
    return manifest
  }

  private static func arrays(from manifest: RecipePayloadManifest) -> [[UUID]] {
    [
      manifest.mediaIDs.map(\.rawValue),
      manifest.equipmentIDs.map(\.rawValue),
      manifest.ingredientSectionIDs.map(\.rawValue),
      manifest.ingredientIDs.map(\.rawValue),
      manifest.instructionSectionIDs.map(\.rawValue),
      manifest.instructionStepIDs.map(\.rawValue),
    ]
  }
}

/// The compact authority retained when reconstructable Recipe payload is pruned.
public struct RecipeAuthorityFrontier: Equatable, Sendable {
  public let revisionHeads: [RecipeRevision.ID]
  public let selectionHeads: [RecipeSelectionCommand.ID]
  public let deletionIDs: [UUID]
  public let restorationIDs: [UUID]

  public init(
    revisionHeads: [RecipeRevision.ID],
    selectionHeads: [RecipeSelectionCommand.ID],
    deletionIDs: [UUID],
    restorationIDs: [UUID]
  ) {
    self.revisionHeads = revisionHeads
    self.selectionHeads = selectionHeads
    self.deletionIDs = deletionIDs
    self.restorationIDs = restorationIDs
  }
}

public struct EncodedRecipeAuthorityFrontier: Equatable, Sendable {
  public let formatVersion: Int
  public let data: Data
  public let digest: Data
}

/// Format 1 stores four fixed-order, counted canonical identifier sets.
public enum RecipeAuthorityFrontierCodec {
  public static let formatVersion = 1

  public static func encode(
    _ frontier: RecipeAuthorityFrontier
  ) -> EncodedRecipeAuthorityFrontier {
    var data = Data()
    for identifiers in canonicalArrays(frontier) {
      var count = UInt32(identifiers.count).bigEndian
      withUnsafeBytes(of: &count) { data.append(contentsOf: $0) }
      for identifier in identifiers {
        data.append(contentsOf: uuidBytes(identifier))
      }
    }
    return EncodedRecipeAuthorityFrontier(
      formatVersion: formatVersion,
      data: data,
      digest: Data(SHA256.hash(data: data))
    )
  }

  public static func decode(
    formatVersion: Int,
    data: Data
  ) throws -> RecipeAuthorityFrontier {
    guard formatVersion == self.formatVersion else {
      throw RecipeAuthorityCodecError.unsupportedFormat(formatVersion)
    }
    var reader = RecipeManifestReader(data: data)
    var arrays: [[UUID]] = []
    for _ in 0..<4 {
      guard let identifiers = reader.readUUIDArray() else {
        throw RecipeAuthorityCodecError.malformedData
      }
      arrays.append(identifiers)
    }
    guard reader.isAtEnd else { throw RecipeAuthorityCodecError.malformedData }
    guard arrays.allSatisfy({ Set($0).count == $0.count }) else {
      throw RecipeAuthorityCodecError.noncanonicalData
    }
    let frontier = RecipeAuthorityFrontier(
      revisionHeads: arrays[0].map(RecipeRevision.ID.init(rawValue:)),
      selectionHeads: arrays[1].map(RecipeSelectionCommand.ID.init(rawValue:)),
      deletionIDs: arrays[2],
      restorationIDs: arrays[3]
    )
    guard encode(frontier).data == data else {
      throw RecipeAuthorityCodecError.noncanonicalData
    }
    return frontier
  }

  private static func canonicalArrays(_ frontier: RecipeAuthorityFrontier) -> [[UUID]] {
    [
      frontier.revisionHeads.map(\.rawValue),
      frontier.selectionHeads.map(\.rawValue),
      frontier.deletionIDs,
      frontier.restorationIDs,
    ].map { identifiers in
      RecipeIdentifierSetCodec.encode(identifiers).data.uuidArray
    }
  }
}

public struct EncodedRecipeRevision: Equatable, Sendable {
  public let formatVersion: Int
  public let data: Data
  public let digest: Data
}

/// Persistence-independent canonical bytes for complete Recipe Revision values.
public enum RecipeRevisionCodec {
  public static let formatVersion = 1

  public static func encode(_ revision: RecipeRevision) throws -> EncodedRecipeRevision {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(revision)
    return EncodedRecipeRevision(
      formatVersion: formatVersion,
      data: data,
      digest: Data(SHA256.hash(data: data))
    )
  }

  public static func decode(formatVersion: Int, data: Data) throws -> RecipeRevision {
    guard formatVersion == self.formatVersion else {
      throw RecipeAuthorityCodecError.unsupportedFormat(formatVersion)
    }
    let revision: RecipeRevision
    do {
      revision = try JSONDecoder().decode(RecipeRevision.self, from: data)
    } catch {
      throw RecipeAuthorityCodecError.malformedData
    }
    guard try encode(revision).data == data else {
      throw RecipeAuthorityCodecError.noncanonicalData
    }
    return revision
  }
}

private struct RecipeManifestReader {
  let data: Data
  var offset = 0

  var isAtEnd: Bool { offset == data.count }

  mutating func readUUID() -> UUID? {
    guard offset + 16 <= data.count else { return nil }
    let bytes = Array(data[offset..<(offset + 16)])
    offset += 16
    return uuid(from: bytes)
  }

  mutating func readUUIDArray() -> [UUID]? {
    guard offset + 4 <= data.count else { return nil }
    let countBytes = data[offset..<(offset + 4)]
    offset += 4
    let count = countBytes.reduce(UInt32.zero) { ($0 << 8) | UInt32($1) }
    guard count <= UInt32((data.count - offset) / 16) else { return nil }
    return (0..<Int(count)).compactMap { _ in readUUID() }
  }
}

private func uuidBytes(_ identifier: UUID) -> [UInt8] {
  var value = identifier.uuid
  return withUnsafeBytes(of: &value) { Array($0) }
}

private func uuid(from bytes: [UInt8]) -> UUID {
  UUID(uuid: (
    bytes[0], bytes[1], bytes[2], bytes[3],
    bytes[4], bytes[5], bytes[6], bytes[7],
    bytes[8], bytes[9], bytes[10], bytes[11],
    bytes[12], bytes[13], bytes[14], bytes[15]
  ))
}

private func lexicographicallyPrecedes(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
  lhs.lexicographicallyPrecedes(rhs)
}

private extension Data {
  var uuidArray: [UUID] {
    let bytes = [UInt8](self)
    return stride(from: 0, to: bytes.count, by: 16).map { offset in
      uuid(from: Array(bytes[offset..<(offset + 16)]))
    }
  }
}
