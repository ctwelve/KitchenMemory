// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import UndoKit

/// Domain-owned stable intent and anchor. Its encoded meaning belongs to KitchenKit.
public struct RecipeOrganizationHistoryChange: Codable, Equatable, Sendable {
  let anchorID: UUID
  let recipeID: Recipe.ID
  let before: Folder.ID?
  let after: Folder.ID?
  let baseline: Data
  let folderBaseline: Data
  /// Present for an atomic multi-Recipe move. Omitted by older persisted single moves.
  let members: [RecipeOrganizationHistoryMember]?
  let tagChange: RecipeOrganizationTagHistoryChange?

  init(anchorID: UUID, recipeID: Recipe.ID, before: Folder.ID?, after: Folder.ID?, baseline: Data,
       folderBaseline: Data, members: [RecipeOrganizationHistoryMember]? = nil,
       tagChange: RecipeOrganizationTagHistoryChange? = nil) {
    self.anchorID = anchorID; self.recipeID = recipeID; self.before = before; self.after = after
    self.baseline = baseline; self.folderBaseline = folderBaseline; self.members = members; self.tagChange = tagChange
  }

  var changedMembers: [RecipeOrganizationHistoryMember] {
    members ?? [
      RecipeOrganizationHistoryMember(anchorID: anchorID, recipeID: recipeID,
        before: before, after: after, baseline: baseline, folderBaseline: folderBaseline),
    ]
  }

  var inverse: Self {
    if let tagChange { return Self(tagChange: tagChange.inverse) }
    let reversed = changedMembers.map { $0.inverse }
    let first = reversed[0]
    return Self(anchorID: first.anchorID, recipeID: first.recipeID, before: first.before, after: first.after,
      baseline: first.baseline, folderBaseline: first.folderBaseline, members: members == nil ? nil : reversed)
  }

  private enum CodingKeys: String, CodingKey {
    case version, members, tagChange, anchorID, recipeID, before, after, baseline, folderBaseline
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    let version = try values.decodeIfPresent(Int.self, forKey: .version)
    if let version, version != 2 && version != 3 {
      throw DecodingError.dataCorruptedError(forKey: .version, in: values,
        debugDescription: "Unsupported history change version")
    }
    if version == 3 {
      let tag = try values.decode(RecipeOrganizationTagHistoryChange.self, forKey: .tagChange)
      let ids = tag.members.map(\.recipeID)
      guard !ids.isEmpty, Set(ids).count == ids.count,
            ids == ids.sorted(by: { $0.rawValue.uuidString < $1.rawValue.uuidString }),
            tag.members.allSatisfy({ !$0.logicalDots.isEmpty
              && Set($0.logicalDots).count == $0.logicalDots.count }) else {
        throw DecodingError.dataCorruptedError(forKey: .tagChange, in: values, debugDescription: "Invalid Tag members")
      }
      self = Self(tagChange: tag)
      return
    }
    tagChange = nil
    if version == 2 {
      let decoded = try values.decode([RecipeOrganizationHistoryMember].self, forKey: .members)
      let sortedIDs = decoded.map(\.recipeID).sorted { $0.rawValue.uuidString < $1.rawValue.uuidString }
      guard decoded.count > 1, decoded.map(\.recipeID).count == Set(decoded.map(\.recipeID)).count,
            decoded.map(\.recipeID) == sortedIDs else {
        throw DecodingError.dataCorruptedError(forKey: .members, in: values, debugDescription: "Invalid batch members")
      }
      let first = decoded[0]
      anchorID = first.anchorID; recipeID = first.recipeID; before = first.before; after = first.after
      baseline = first.baseline; folderBaseline = first.folderBaseline; members = decoded
    } else {
      anchorID = try values.decode(UUID.self, forKey: .anchorID)
      recipeID = try values.decode(Recipe.ID.self, forKey: .recipeID)
      before = try values.decodeIfPresent(Folder.ID.self, forKey: .before)
      after = try values.decodeIfPresent(Folder.ID.self, forKey: .after)
      baseline = try values.decode(Data.self, forKey: .baseline)
      folderBaseline = try values.decode(Data.self, forKey: .folderBaseline)
      members = nil
    }
  }

  public func encode(to encoder: Encoder) throws {
    var values = encoder.container(keyedBy: CodingKeys.self)
    if let tagChange {
      try values.encode(3, forKey: .version)
      try values.encode(tagChange, forKey: .tagChange)
    } else if let members {
      try values.encode(2, forKey: .version)
      try values.encode(members, forKey: .members)
    } else {
      try values.encode(anchorID, forKey: .anchorID); try values.encode(recipeID, forKey: .recipeID)
      try values.encodeIfPresent(before, forKey: .before); try values.encodeIfPresent(after, forKey: .after)
      try values.encode(baseline, forKey: .baseline); try values.encode(folderBaseline, forKey: .folderBaseline)
    }
  }
}

public struct RecipeOrganizationHistoryMember: Codable, Equatable, Sendable {
  let anchorID: UUID
  let recipeID: Recipe.ID
  let before: Folder.ID?
  let after: Folder.ID?
  let baseline: Data
  let folderBaseline: Data

  var inverse: Self {
    Self(anchorID: anchorID, recipeID: recipeID, before: after, after: before,
      baseline: baseline, folderBaseline: folderBaseline)
  }
}

/// An exact frozen transaction retained locally before attempting domain acceptance.
public struct RecipeOrganizationHistoryDelivery: Codable, Equatable, Sendable {
  let scope: RecipeOrganizationHistoryScope
  let token: OrganizationHistoryToken
  let memberID: UUID
  let change: RecipeOrganizationHistoryChange
  let command: RecipeOrganizationCommand
  let beforeWitness: Data
}

/// Canonical accepted evidence, written atomically with the organization change.
public struct RecipeOrganizationHistoryReceipt: Codable, Equatable, Sendable {
  let delivery: RecipeOrganizationHistoryDelivery
  let afterWitness: Data

  var outcome: HistoryTypedOutcome<RecipeOrganizationHistoryChange> {
    .accepted([
      HistoryTypedEffect(memberID: delivery.memberID, undo: delivery.change.inverse, redo: delivery.change),
    ])
  }
}

/// Public organization/recovery seam; implementations own guarded atomic domain acceptance.
@MainActor
public protocol RecipeOrganizationHistoryRepository: RecipeOrganizationRepository {
  func prepareHistoryMove(_ recipeID: Recipe.ID, to folderID: Folder.ID?,
                          in scope: RecipeOrganizationHistoryScope) throws -> RecipeOrganizationHistoryChange?
  func prepareHistoryMove(_ recipeIDs: Set<Recipe.ID>, to folderID: Folder.ID?,
                          in scope: RecipeOrganizationHistoryScope) throws -> RecipeOrganizationHistoryChange?
  func prepareHistoryTags(_ recipeIDs: Set<Recipe.ID>, tagID: Tag.ID, adding: Bool,
                          in scope: RecipeOrganizationHistoryScope) throws -> RecipeOrganizationHistoryChange?
  func prepareHistoryDelivery(_ change: RecipeOrganizationHistoryChange, memberID: UUID, token: HistoryToken,
                              in scope: RecipeOrganizationHistoryScope) throws -> RecipeOrganizationHistoryDelivery
  func acceptHistory(_ delivery: RecipeOrganizationHistoryDelivery) throws -> RecipeOrganizationHistoryReceipt
  func recoverHistory(_ delivery: RecipeOrganizationHistoryDelivery) throws -> RecipeOrganizationHistoryReceipt
  func historyReceipt(for token: HistoryToken, in scope: RecipeOrganizationHistoryScope)
    throws -> RecipeOrganizationHistoryReceipt?
  func historyIsEligible(in scope: RecipeOrganizationHistoryScope, generation: UUID) throws -> Bool
}

struct OrganizationHistoryToken: Codable, Equatable, Sendable {
  let scope: UUID
  let generation: UUID
  let sequence: Int64
  let command: UUID

  init(_ value: HistoryToken) {
    scope = value.scope; generation = value.generation; sequence = value.sequence; command = value.command
  }
  var value: HistoryToken { HistoryToken(scope: scope, generation: generation, sequence: sequence, command: command) }
  var recoveryReceiptID: UUID { derivedID(namespace: receiptID, kind: "recovery", source: receiptID) }
  var receiptID: UUID {
    derivedID(namespace: generation, kind: "organization-history-receipt/\(scope)/\(sequence)", source: command)
  }
}
