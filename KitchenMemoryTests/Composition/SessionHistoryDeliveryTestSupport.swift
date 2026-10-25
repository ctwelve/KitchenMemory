// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import UndoKit

@MainActor
final class InterruptedProgressHistoryRepository: RecipeOrganizationHistoryRepository {
  let base: SwiftDataRecipeOrganizationRepository
  var rejectNextAcceptance = false
  var failNextAcceptance = false
  init(_ base: SwiftDataRecipeOrganizationRepository) { self.base = base }
  func historySessionIDs(in scope: RecipeOrganizationHistoryScope, generation: UUID) throws -> Set<CookingSession.ID> {
    try base.historySessionIDs(in: scope, generation: generation)
  }
  func prepareHistoryProgress(_ sessionID: CookingSession.ID, to progress: SessionProgress,
                              in scope: RecipeOrganizationHistoryScope) throws -> RecipeOrganizationHistoryChange? {
    try base.prepareHistoryProgress(sessionID, to: progress, in: scope)
  }
  func load(in kitchenID: Kitchen.ID) throws -> RecipeOrganization { try base.load(in: kitchenID) }
  func accept(_ command: RecipeOrganizationCommand, firstSave: RecipeSaveCommand?) throws {
    try base.accept(command, firstSave: firstSave)
  }
  func prepareHistoryMove(_ recipeID: Recipe.ID, to folderID: Folder.ID?, in scope: RecipeOrganizationHistoryScope)
    throws -> RecipeOrganizationHistoryChange? { try base.prepareHistoryMove(recipeID, to: folderID, in: scope) }
  func prepareHistoryMove(_ recipeIDs: Set<Recipe.ID>, to folderID: Folder.ID?,
                          in scope: RecipeOrganizationHistoryScope)
    throws -> RecipeOrganizationHistoryChange? { try base.prepareHistoryMove(recipeIDs, to: folderID, in: scope) }
  func prepareHistoryTags(_ recipeIDs: Set<Recipe.ID>, tagID: Tag.ID, adding: Bool,
                          in scope: RecipeOrganizationHistoryScope) throws -> RecipeOrganizationHistoryChange? {
    try base.prepareHistoryTags(recipeIDs, tagID: tagID, adding: adding, in: scope)
  }
  func prepareHistoryDelivery(_ change: RecipeOrganizationHistoryChange, memberID: UUID, token: UndoKit.HistoryToken,
                              in scope: RecipeOrganizationHistoryScope) throws -> RecipeOrganizationHistoryDelivery {
    try base.prepareHistoryDelivery(change, memberID: memberID, token: token, in: scope)
  }
  func acceptHistory(_ delivery: RecipeOrganizationHistoryDelivery) throws -> RecipeOrganizationHistoryReceipt {
    if failNextAcceptance { failNextAcceptance = false; throw LostReply() }
    if rejectNextAcceptance {
      rejectNextAcceptance = false
      throw RecipeOrganizationHistoryError.ineligible
    }
    return try base.acceptHistory(delivery)
  }
  func recoverHistory(_ delivery: RecipeOrganizationHistoryDelivery) throws -> RecipeOrganizationHistoryReceipt {
    return try base.recoverHistory(delivery)
  }
  func historyReceipt(for token: UndoKit.HistoryToken, in scope: RecipeOrganizationHistoryScope)
    throws -> RecipeOrganizationHistoryReceipt? {
    try base.historyReceipt(for: token, in: scope)
  }
  func historyIsEligible(in scope: RecipeOrganizationHistoryScope, generation: UUID) throws -> Bool {
    return try base.historyIsEligible(in: scope, generation: generation)
  }
  private struct LostReply: Error {}
}
