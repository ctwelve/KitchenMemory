// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import Foundation
import KitchenMemoryDomain

extension CookingSessionSnapshotFactory {
  func continuationRoot(
    intention: ContinueCookingSessionIntention,
    kitchenID: Kitchen.ID,
    source: CookingSessionProjection,
    sourceEvidence: SessionEvidence,
    sourceClosureID: SessionClosure.ID
  ) throws -> CookingSessionRootEvidence {
    guard intention.sessionID != intention.sourceSessionID,
          source.id == intention.sourceSessionID,
          intention.startedAt != .distantPast,
          let sourceRoot = sourceEvidence.roots.first,
          sourceRoot.kitchenID == kitchenID
    else { throw CookingSessionLogicError.invalidIntention }

    let snapshot = continuedSnapshot(source.snapshot, projection: source, id: intention.sessionID)
    let encoded: EncodedSessionValue
    do { encoded = try encoding.snapshot(snapshot) } catch {
      throw CookingSessionLogicError.encodingFailed
    }
    return CookingSessionRootEvidence(
      id: intention.sessionID,
      kitchenID: kitchenID,
      recipeID: sourceRoot.recipeID,
      recipeRevisionID: sourceRoot.recipeRevisionID,
      startedAt: intention.startedAt,
      snapshotFormatVersion: encoded.formatVersion,
      snapshotData: encoded.data,
      snapshotDigest: encoded.digest,
      sourceSessionID: intention.sourceSessionID,
      sourceClosureID: sourceClosureID
    )
  }

  // Listing every snapshot field here is what makes continuation visibly
  // self-contained when the source Session later becomes unavailable.
  // swiftlint:disable:next function_body_length
  private func continuedSnapshot(
    _ source: ExecutionSnapshot,
    projection: CookingSessionProjection,
    id: CookingSession.ID
  ) -> ExecutionSnapshot {
    let ingredients = source.ingredientSections.map { section in
      SessionIngredientSection(title: section.title, ingredients: section.ingredients.map {
        SessionIngredient(
          id: .init(rawValue: derivedID(
            namespace: id.rawValue,
            kind: "continuation-ingredient",
            source: $0.id.rawValue
          )),
          sourceIngredientID: $0.sourceIngredientID,
          value: $0.value
        )
      })
    }
    let instructions = source.instructionSections.map { section in
      SessionInstructionSection(title: section.title, steps: section.steps.map {
        SessionInstruction(
          id: .init(rawValue: derivedID(
            namespace: id.rawValue,
            kind: "continuation-instruction",
            source: $0.id.rawValue
          )),
          sourceInstructionID: $0.sourceInstructionID,
          value: $0.value
        )
      })
    }
    return ExecutionSnapshot(
      title: source.title,
      summary: source.summary,
      contentLanguage: source.contentLanguage,
      authorName: source.authorName,
      source: source.source,
      baseYield: source.baseYield,
      initialWorkingScale: remap(projection.workingScale, id: id),
      prepDuration: source.prepDuration,
      cookDuration: source.cookDuration,
      totalDuration: source.totalDuration,
      equipment: source.equipment,
      ingredientSections: ingredients,
      instructionSections: instructions,
      media: source.media.map { item in
        SessionMediaReference(
          id: .init(rawValue: derivedID(
            namespace: id.rawValue,
            kind: "continuation-media",
            source: item.id.rawValue
          )),
          sourceMediaID: item.sourceMediaID,
          role: item.role,
          accessibilityDescription: item.accessibilityDescription
        )
      },
      continuationBaseline: baseline(projection, id: id)
    )
  }

  private func baseline(
    _ source: CookingSessionProjection,
    id: CookingSession.ID
  ) -> SessionContinuationBaseline {
    SessionContinuationBaseline(
      workingScale: remap(source.workingScale, id: id),
      progress: source.progress.map { progress in
        SessionProgress(target: remap(progress.target, id: id), state: progress.state)
      },
      entries: source.entries.map { entry in
        SessionContinuationEntry(
          entry: SessionEntry(
            id: .init(rawValue: derivedID(
              namespace: id.rawValue,
              kind: "continuation-entry",
              source: entry.id.rawValue
            )),
            target: entry.target.map { remap($0, id: id) },
            text: entry.text
          ),
          sourceEntryID: entry.id
        )
      },
      targetMappings: sourceTargets(source.snapshot).map {
        SessionContinuationTargetMapping(target: remap($0, id: id), sourceTarget: $0)
      }
    )
  }

  private func remap(
    _ scale: SessionWorkingScale?,
    id: CookingSession.ID
  ) -> SessionWorkingScale? {
    scale.map { value in
      SessionWorkingScale(
        workingYield: value.workingYield,
        exactScale: value.exactScale,
        quantities: value.quantities.map { quantity in
          SessionIngredientQuantity(
            ingredientID: .init(rawValue: derivedID(
              namespace: id.rawValue,
              kind: "continuation-ingredient",
              source: quantity.ingredientID.rawValue
            )),
            quantity: quantity.quantity
          )
        }
      )
    }
  }

  private func remap(
    _ target: SessionProgressTarget,
    id: CookingSession.ID
  ) -> SessionProgressTarget {
    switch target {
    case let .ingredient(source):
      .ingredient(.init(rawValue: derivedID(
        namespace: id.rawValue,
        kind: "continuation-ingredient",
        source: source.rawValue
      )))
    case let .instruction(source):
      .instruction(.init(rawValue: derivedID(
        namespace: id.rawValue,
        kind: "continuation-instruction",
        source: source.rawValue
      )))
    }
  }

  private func sourceTargets(_ snapshot: ExecutionSnapshot) -> [SessionProgressTarget] {
    snapshot.ingredientSections.flatMap(\.ingredients).map { .ingredient($0.id) }
      + snapshot.instructionSections.flatMap(\.steps).map { .instruction($0.id) }
  }
}
