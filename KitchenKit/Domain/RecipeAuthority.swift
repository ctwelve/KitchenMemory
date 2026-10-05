// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CryptoKit
import Foundation

// These related public values and their caller contracts form one domain boundary.
// Keep their documentation beside the declarations rather than splitting the contract.
// swiftlint:disable file_length

/// A caller-owned command choosing which accepted Recipe Revision is current.
public struct RecipeSelectionCommand: Codable, Equatable, Sendable {
  /// A domain-typed stable UUID identity, independent of persistence record identity.
  public typealias ID = StableIdentifier<RecipeSelectionCommand>

  /// The caller-owned immutable operation identity.
  ///
  /// Exact retries reuse it with identical content; conflicting reuse requires rejection
  /// or recovery rather than another accepted effect.
  public let id: ID
  /// The Kitchen ownership boundary for this value; transport identity cannot substitute for it.
  public let kitchenID: Kitchen.ID
  /// The stable maintained Recipe identity, independent of a particular Revision.
  public let recipeID: Recipe.ID
  /// The existing accepted Revision chosen for presentation.
  public let selectedRevisionID: RecipeRevision.ID
  /// The authored choice date; competing choices are resolved causally rather than by this clock.
  public let selectedAt: Date
  /// The complete prior Selection frontier observed when the choice was prepared.
  ///
  /// Retain this frontier on retry; a concurrent unobserved choice can remain competing.
  public let observedSelectionIDs: [ID]

  /// Freezes a selection intention with caller-owned identity and observed context.
  ///
  /// Retain the whole value for retry; construction does not verify that its Revision
  /// is accepted or that the supplied frontier is complete.
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
public struct RecipeSaveCommand: Codable, Equatable, Sendable {
  /// A domain-typed stable UUID identity, independent of persistence record identity.
  public typealias ID = StableIdentifier<RecipeSaveCommand>

  /// The caller-owned immutable operation identity.
  ///
  /// Exact retries reuse it with identical content; conflicting reuse requires rejection
  /// or recovery rather than another accepted effect.
  public let id: ID
  /// The stable aggregate receiving the new immutable content.
  public let recipe: Recipe
  /// The complete content accepted by this Save, with its caller-owned Revision identity.
  public let revision: RecipeRevision
  /// The authored Save date, retained across retries and excluded from currentness decisions.
  public let savedAt: Date
  /// The explicit complete ancestry of this Revision; empty means a root, multiple means reconciliation.
  public let parentRevisionIDs: [RecipeRevision.ID]
  /// The paired immutable choice selecting the saved Revision against observed prior selections.
  public let selection: RecipeSelectionCommand

  /// Freezes content, ancestry, and Selection as one retryable publication intention.
  ///
  /// Construction does not validate ownership or cross-field consistency; acceptance
  /// belongs to the repository and must retain these identities on retry.
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

/// A failure to read the frozen Recipe authority byte representation.
///
/// Unknown versions can become available to a newer reader; malformed or noncanonical
/// bytes are positive integrity failures rather than partially usable evidence.
public enum RecipeAuthorityCodecError: Error, Equatable {
  /// The byte layout or decoded content cannot represent the declared format.
  case malformedData
  /// The value decodes but its bytes violate canonical ordering, uniqueness, or re-encoding.
  case noncanonicalData
  /// The declared version is unknown to this reader; retain its bytes for a future reader.
  case unsupportedFormat(Int)
}

/// A format-tagged canonical UUID set ready for an authority envelope.
public struct EncodedRecipeIdentifierSet: Equatable, Sendable {
  /// The frozen codec version interpreting these bytes.
  public let formatVersion: Int
  /// The canonical bytes to persist unchanged in the authority envelope.
  public let data: Data
}

/// Canonical format-1 sets are sorted raw UUID bytes with no delimiters.
public enum RecipeIdentifierSetCodec {
  /// The supported raw UUID set format, currently version 1.
  public static let formatVersion = 1

  /// Deduplicates UUIDs, sorts their raw bytes, and concatenates them without delimiters.
  ///
  /// An empty set encodes to empty data; input order carries no authority.
  public static func encode(_ identifiers: [UUID]) -> EncodedRecipeIdentifierSet {
    let bytes = Set(identifiers).map(uuidBytes).sorted(by: lexicographicallyPrecedes)
    return EncodedRecipeIdentifierSet(
      formatVersion: formatVersion,
      data: Data(bytes.flatMap { $0 })
    )
  }

  /// Reads a format-1 set without repairing retained evidence.
  ///
  /// Throws for unknown versions, non-16-byte alignment, duplicates, or unsorted bytes.
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
  /// The root Revision whose ordered child identities this manifest commits.
  public let revisionID: RecipeRevision.ID
  /// Media identities in authored order, including references whose bytes are unavailable.
  public let mediaIDs: [RecipeMedia.ID]
  /// Equipment row identities in authored order.
  public let equipmentIDs: [EquipmentItem.ID]
  /// Ingredient group identities in authored order.
  public let ingredientSectionIDs: [IngredientSection.ID]
  /// Ingredient row identities flattened in section and row order.
  public let ingredientIDs: [RecipeIngredient.ID]
  /// Instruction group identities in authored order.
  public let instructionSectionIDs: [InstructionSection.ID]
  /// Instruction identities flattened in section and step order.
  public let instructionStepIDs: [InstructionStep.ID]

  /// Captures the exact ordered identities needed to reconstruct the supplied Revision.
  ///
  /// Authored values and media references are committed by the canonical Revision
  /// digest. Local image bytes are excluded; their integrity is checked against
  /// the private content-addressed reference.
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

/// A format-tagged ordered payload manifest, without the payload values themselves.
public struct EncodedRecipePayloadManifest: Equatable, Sendable {
  /// The frozen codec version interpreting these bytes.
  public let formatVersion: Int
  /// The canonical bytes to persist unchanged in the authority envelope.
  public let data: Data
}

/// Format 1 is the root UUID followed by six fixed-order, big-endian-counted UUID lists.
public enum RecipePayloadManifestCodec {
  /// The supported counted ordered-manifest format, currently version 1.
  public static let formatVersion = 1

  /// Encodes the root UUID and six ordered child lists with big-endian counts.
  ///
  /// Order is authored content and is preserved; this method does not remove repeated IDs.
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

  /// Reads six ordered child lists while requiring a complete byte layout and unique IDs per family.
  ///
  /// Throws for unsupported versions, truncation, trailing bytes, or repeated identities;
  /// it preserves list order rather than sorting it.
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
  /// The maximal accepted Revision identities retained after pruning.
  public let revisionHeads: [RecipeRevision.ID]
  /// The maximal Selection identities retained after pruning.
  public let selectionHeads: [RecipeSelectionCommand.ID]
  /// Deletion identities covered by the compact authority evidence.
  public let deletionIDs: [UUID]
  /// Restoration identities covered by the compact authority evidence.
  public let restorationIDs: [UUID]

  /// Retains a proposed compact frontier; canonical set normalization occurs in its codec.
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

/// Canonical compact authority bytes and the SHA-256 digest committing them.
public struct EncodedRecipeAuthorityFrontier: Equatable, Sendable {
  /// The frozen codec version interpreting these bytes.
  public let formatVersion: Int
  /// The canonical bytes to persist unchanged in the authority envelope.
  public let data: Data
  /// SHA-256 of `data`, binding the retained envelope to these exact canonical bytes.
  public let digest: Data
}

/// Format 1 stores four fixed-order, counted canonical identifier sets.
public enum RecipeAuthorityFrontierCodec {
  /// The supported four-set compact frontier format, currently version 1.
  public static let formatVersion = 1

  /// Deduplicates and sorts each frontier family, then commits the counted bytes with SHA-256.
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

  /// Reads four canonical identifier sets without repairing duplicates or ordering.
  ///
  /// Throws for unsupported versions, malformed layout, repeated IDs, or noncanonical
  /// bytes. Digest verification belongs to the containing evidence boundary.
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

/// Canonical Recipe content bytes with their format version and SHA-256 commitment.
public struct EncodedRecipeRevision: Equatable, Sendable {
  /// The frozen codec version interpreting these bytes.
  public let formatVersion: Int
  /// The canonical bytes to persist unchanged in the authority envelope.
  public let data: Data
  /// SHA-256 of `data`, binding the retained envelope to these exact canonical bytes.
  public let digest: Data
}

/// Persistence-independent canonical bytes for complete Recipe Revision values.
public enum RecipeRevisionCodec {
  /// The supported canonical Recipe JSON format, currently version 1.
  public static let formatVersion = 1

  /// Produces sorted-key canonical JSON and its SHA-256 digest.
  ///
  /// Optional local image bytes are removed from the encoded copy; authored references
  /// and descriptions remain committed. Encoding errors propagate to the caller.
  public static func encode(_ revision: RecipeRevision) throws -> EncodedRecipeRevision {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    // Image transport availability is independent of immutable Recipe authority.
    // The media reference itself includes the digest of the selected bytes.
    var authority = revision
    authority.media = revision.media.map { media in
      var reference = media
      reference.imageData = nil
      return reference
    }
    let data = try encoder.encode(authority)
    return EncodedRecipeRevision(
      formatVersion: formatVersion,
      data: data,
      digest: Data(SHA256.hash(data: data))
    )
  }

  /// Reads only the supported canonical JSON representation and requires byte-identical re-encoding.
  ///
  /// Throws for unsupported versions, malformed content, or noncanonical bytes. It
  /// does not validate Save ancestry or compare an external authority digest.
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

// swiftlint:enable file_length
