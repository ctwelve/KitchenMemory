// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import CryptoKit
import Foundation

struct CookingSessionSnapshotFactory {
  let encoding: any CookingSessionEncoding

  func root(
    for intention: StartCookingSessionIntention,
    kitchenID: Kitchen.ID,
    revision: RecipeRevision
  ) throws -> CookingSessionRootEvidence {
    guard !intention.sessionID.rawValue.isZero,
          !kitchenID.rawValue.isZero,
          !intention.recipeID.rawValue.isZero,
          !intention.recipeRevisionID.rawValue.isZero,
          intention.startedAt != .distantPast,
          !revision.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          sourceTargetsAreUnique(revision),
          scaleIsValid(intention.workingScale, for: revision)
    else { throw CookingSessionLogicError.insufficientSnapshot }

    let snapshot = ExecutionSnapshot(
      title: revision.title,
      summary: revision.summary,
      contentLanguage: revision.contentLanguage,
      authorName: revision.authorName,
      source: revision.source,
      baseYield: revision.recipeYield,
      initialWorkingScale: workingScale(
        revision: revision,
        scale: intention.workingScale,
        sessionID: intention.sessionID
      ),
      prepDuration: revision.prepDuration,
      cookDuration: revision.cookDuration,
      totalDuration: revision.totalDuration,
      equipment: revision.equipment,
      ingredientSections: ingredientSections(revision, sessionID: intention.sessionID),
      instructionSections: instructionSections(revision, sessionID: intention.sessionID),
      media: media(revision, sessionID: intention.sessionID)
    )
    let encoded: EncodedSessionValue
    do {
      encoded = try encoding.snapshot(snapshot)
    } catch {
      throw CookingSessionLogicError.encodingFailed
    }
    return CookingSessionRootEvidence(
      id: intention.sessionID,
      kitchenID: kitchenID,
      recipeID: intention.recipeID,
      recipeRevisionID: intention.recipeRevisionID,
      startedAt: intention.startedAt,
      snapshotFormatVersion: encoded.formatVersion,
      snapshotData: encoded.data,
      snapshotDigest: encoded.digest
    )
  }

  private func ingredientSections(
    _ revision: RecipeRevision,
    sessionID: CookingSession.ID
  ) -> [SessionIngredientSection] {
    revision.ingredientSections.map { section in
      SessionIngredientSection(
        title: section.title,
        ingredients: section.ingredients.map { ingredient in
          SessionIngredient(
            id: .init(rawValue: derivedID(
              namespace: sessionID.rawValue,
              kind: "ingredient",
              source: ingredient.id.rawValue
            )),
            sourceIngredientID: ingredient.id,
            value: ingredient
          )
        }
      )
    }
  }

  private func instructionSections(
    _ revision: RecipeRevision,
    sessionID: CookingSession.ID
  ) -> [SessionInstructionSection] {
    revision.instructionSections.map { section in
      SessionInstructionSection(
        title: section.title,
        steps: section.steps.map { step in
          SessionInstruction(
            id: .init(rawValue: derivedID(
              namespace: sessionID.rawValue,
              kind: "instruction",
              source: step.id.rawValue
            )),
            sourceInstructionID: step.id,
            value: step
          )
        }
      )
    }
  }

  private func media(
    _ revision: RecipeRevision,
    sessionID: CookingSession.ID
  ) -> [SessionMediaReference] {
    revision.media.map { item in
      SessionMediaReference(
        id: .init(rawValue: derivedID(
          namespace: sessionID.rawValue,
          kind: "media",
          source: item.id.rawValue
        )),
        sourceMediaID: item.id,
        role: item.role,
        accessibilityDescription: item.accessibilityLabel
      )
    }
  }

  private func workingScale(
    revision: RecipeRevision,
    scale: RecipeScale?,
    sessionID: CookingSession.ID
  ) -> SessionWorkingScale {
    let exactScale = scale?.multiplier ?? RationalQuantity(numerator: 1)
    let workingYield = scale.map { selectedScale -> RecipeYield? in
      guard var value = revision.recipeYield else { return nil }
      value.quantity = QuantityExpression(kind: .exact, lowerBound: selectedScale.workingYield)
      return value
    } ?? revision.recipeYield
    let quantities: [SessionIngredientQuantity] = revision.ingredientSections
      .flatMap(\.ingredients).compactMap { ingredient in
      let value = scale.map { ingredient.scaled(using: $0).ingredient } ?? ingredient
      guard let quantity = value.quantity else { return nil }
      return SessionIngredientQuantity(
        ingredientID: .init(rawValue: derivedID(
          namespace: sessionID.rawValue,
          kind: "ingredient",
          source: ingredient.id.rawValue
        )),
        quantity: quantity
      )
      }
    return SessionWorkingScale(
      workingYield: workingYield,
      exactScale: exactScale,
      quantities: quantities
    )
  }

  private func sourceTargetsAreUnique(_ revision: RecipeRevision) -> Bool {
    let ingredients = revision.ingredientSections.flatMap(\.ingredients).map(\.id)
    let instructions = revision.instructionSections.flatMap(\.steps).map(\.id)
    return Set(ingredients).count == ingredients.count
      && Set(instructions).count == instructions.count
  }

  private func scaleIsValid(_ scale: RecipeScale?, for revision: RecipeRevision) -> Bool {
    guard let scale else { return true }
    return revision.recipeYield?.scalingBases.contains {
      $0.quantity == scale.baseYield
    } == true
  }
}

// Session-owned child identities must survive a retry with the same root ID;
// generating fresh UUIDs here would turn an accepted retry into a root collision.
func derivedID(namespace: UUID, kind: String, source: UUID) -> UUID {
  var input = Data()
  var namespaceBytes = namespace.uuid
  var sourceBytes = source.uuid
  withUnsafeBytes(of: &namespaceBytes) { input.append(contentsOf: $0) }
  input.append(contentsOf: kind.utf8)
  withUnsafeBytes(of: &sourceBytes) { input.append(contentsOf: $0) }
  var bytes = Array(SHA256.hash(data: input).prefix(16))
  bytes[6] = (bytes[6] & 0x0F) | 0x80
  bytes[8] = (bytes[8] & 0x3F) | 0x80
  return UUID(uuid: (
    bytes[0], bytes[1], bytes[2], bytes[3],
    bytes[4], bytes[5], bytes[6], bytes[7],
    bytes[8], bytes[9], bytes[10], bytes[11],
    bytes[12], bytes[13], bytes[14], bytes[15]
  ))
}

private extension UUID {
  var isZero: Bool {
    self == UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
  }
}
