// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

/// The opaque identity of the account or participant that owns a Kitchen.
public enum KitchenOwner {
  /// An opaque owner token, independent of display names or framework account objects.
  ///
  /// The raw string is retained verbatim; constructing it does not authenticate ownership.
  public struct ID: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    /// The opaque ownership token exactly as supplied by the account boundary.
    public let rawValue: String

    /// Retains an opaque token without interpreting or validating account membership.
    public init(rawValue: String) {
      self.rawValue = rawValue
    }
  }
}

/// The ownership and collaboration boundary for Kitchen Memory content.
public struct Kitchen: Codable, Equatable, Identifiable, Sendable {
  /// A domain-typed stable UUID identity, independent of persistence record identity.
  public typealias ID = StableIdentifier<Kitchen>

  /// The stable ownership boundary shared by independently stored Kitchen aggregates.
  public let id: ID
  /// The known account-scoped owner, or nil when ownership has not been established.
  public let ownerID: KitchenOwner.ID?
  /// The authored Kitchen name; this value does not enforce display-name validation.
  public var name: String

  /// Creates the ownership value without loading its independently stored aggregates.
  public init(id: ID = ID(), ownerID: KitchenOwner.ID? = nil, name: String) {
    self.id = id
    self.ownerID = ownerID
    self.name = name
  }
}
