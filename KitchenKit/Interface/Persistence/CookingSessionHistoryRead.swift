// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

/// One locally observed Cooking Session history read, with classifications and
/// retained provenance assembled from the same evidence. This value is neither
/// a persistent cache nor an authority record.
public struct CookingSessionHistoryRead: Sendable {
  /// Every known classification in deterministic Session identity order.
  public let sessions: [SessionProjectionResult]
  /// Closure-bearing classifications ordered by newest retained Finish time,
  /// then Session identity. Closure presence does not imply readable Finished content.
  public let finishedSessions: [SessionProjectionResult]
  /// All Session identities associated with each Recipe by retained roots in this Kitchen.
  /// Associations do not require the source Recipe to remain available.
  public let sessionIDsByRecipe: [Recipe.ID: Set<CookingSession.ID>]

  /// Assembles an ephemeral read value. Repository adapters supply classifications
  /// and metadata from one observed evidence pass.
  public init(
    sessions: [SessionProjectionResult],
    finishedSessions: [SessionProjectionResult],
    sessionIDsByRecipe: [Recipe.ID: Set<CookingSession.ID>]
  ) {
    self.sessions = sessions
    self.finishedSessions = finishedSessions
    self.sessionIDsByRecipe = sessionIDsByRecipe
  }
}
