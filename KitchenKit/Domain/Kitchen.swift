// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

/// The opaque identity of the account or participant that owns a Kitchen.
public enum KitchenOwner {
  public struct ID: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
      self.rawValue = rawValue
    }
  }
}

/// The ownership and collaboration boundary for Kitchen Memory content.
public struct Kitchen: Codable, Equatable, Identifiable, Sendable {
  public typealias ID = StableIdentifier<Kitchen>

  public let id: ID
  public let ownerID: KitchenOwner.ID?
  public var name: String

  public init(id: ID = ID(), ownerID: KitchenOwner.ID? = nil, name: String) {
    self.id = id
    self.ownerID = ownerID
    self.name = name
  }
}
