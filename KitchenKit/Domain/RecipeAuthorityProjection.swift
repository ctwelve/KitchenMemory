// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import CryptoKit
import Foundation

public enum RecipeAuthorityProjector {
  public static func project(_ evidence: RecipeAuthorityEvidence) -> RecipeAuthorityProjection {
    if let disposition = pruneDisposition(evidence) { return disposition }
    let normalized: NormalizedRecipeAuthorityEvidence
    switch normalize(evidence) {
    case let .projection(projection): return projection
    case let .normalized(value): normalized = value
    }
    guard !normalized.saves.isEmpty else { return .unavailable(.noSaveEvidence) }
    guard !normalized.selections.isEmpty else { return .unavailable(.noSelectionEvidence) }

    switch coalescedPayloads(evidence.revisions) {
    case let .collision(identity): return .recovery(.payloadCollision(identity))
    case let .coalesced(revisions):
      return projectValidated(
        normalized.evidence,
        saves: normalized.saves,
        selections: normalized.selections,
        revisions: revisions
      )
    }
  }
}

private struct NormalizedRecipeAuthorityEvidence {
  let evidence: RecipeAuthorityEvidence
  let saves: [RecipeSaveEvidence]
  let selections: [RecipeSelectionEvidence]
}

private enum RecipeAuthorityNormalization {
  case normalized(NormalizedRecipeAuthorityEvidence)
  case projection(RecipeAuthorityProjection)
}

private extension RecipeAuthorityProjector {
  // Four immutable command families share the same collision rule. Keeping
  // their normalization together makes the validation order explicit.
  private static func normalize(
    _ evidence: RecipeAuthorityEvidence
  ) -> RecipeAuthorityNormalization {
    let saves: [RecipeSaveEvidence]
    switch IdentityCollection.coalesce(
      evidence.saves, id: \RecipeSaveEvidence.id,
      orderedBy: { uuidPrecedes($0.id, $1.id) }
    ) {
    case let .coalesced(values): saves = values
    case let .collision(id): return .projection(.recovery(.commandCollision(id)))
    }
    let selections: [RecipeSelectionEvidence]
    switch IdentityCollection.coalesce(
      evidence.selections, id: \RecipeSelectionEvidence.id,
      orderedBy: { uuidPrecedes($0.id, $1.id) }
    ) {
    case let .coalesced(values): selections = values
    case let .collision(id): return .projection(.recovery(.commandCollision(id)))
    }
    let deletions: [RecipeDeletionEvidence]
    switch IdentityCollection.coalesce(evidence.deletions, id: \RecipeDeletionEvidence.id) {
    case let .coalesced(values): deletions = values
    case let .collision(id): return .projection(.recovery(.commandCollision(id)))
    }
    let restorations: [RecipeRestorationEvidence]
    switch IdentityCollection.coalesce(evidence.restorations, id: \RecipeRestorationEvidence.id) {
    case let .coalesced(values): restorations = values
    case let .collision(id): return .projection(.recovery(.commandCollision(id)))
    }
    let normalized = RecipeAuthorityEvidence(
      kitchenID: evidence.kitchenID, recipeID: evidence.recipeID,
      saves: saves, selections: selections, revisions: evidence.revisions,
      deletions: deletions, restorations: restorations, prunes: evidence.prunes
    )
    guard evidenceHasConsistentOwnership(normalized, saves: saves, selections: selections) else {
      return .projection(.recovery(.crossOwnership))
    }
    let deletionIDs = Set(deletions.map(\.id))
    if let missing = restorations.map(\.deletionID).sorted(by: uuidPrecedes)
      .first(where: { !deletionIDs.contains($0) }) {
      return .projection(.unavailable(.missingDeletion(missing)))
    }
    return .normalized(NormalizedRecipeAuthorityEvidence(
      evidence: normalized, saves: saves, selections: selections
    ))
  }

  private static func projectValidated(
    _ evidence: RecipeAuthorityEvidence,
    saves: [RecipeSaveEvidence],
    selections: [RecipeSelectionEvidence],
    revisions: [RecipeRevision]
  ) -> RecipeAuthorityProjection {
    var savedRevisionIDs = Set<RecipeRevision.ID>()
    for save in saves where !savedRevisionIDs.insert(save.revisionID).inserted {
      return .recovery(.commandCollision(save.id))
    }
    if let unsaved = revisions.map(\.id).sorted(by: idPrecedes)
      .first(where: { !savedRevisionIDs.contains($0) }) {
      return .unavailable(.missingSave(unsaved))
    }
    let revisionByID = Dictionary(uniqueKeysWithValues: revisions.map { ($0.id, $0) })
    var parentsByRevision: [RecipeRevision.ID: [RecipeRevision.ID]] = [:]
    for save in saves {
      let parents: [RecipeRevision.ID]
      do {
        parents = try RecipeIdentifierSetCodec.decode(
          formatVersion: save.ancestryFormatVersion,
          data: save.parentRevisionIDsData
        ).map(RecipeRevision.ID.init(rawValue:))
      } catch let RecipeAuthorityCodecError.unsupportedFormat(version) {
        return .unavailable(.unsupportedFormat(version))
      } catch {
        return .recovery(.malformedEncoding)
      }
      if let missing = parents.first(where: { parent in !saves.contains { $0.revisionID == parent } }) {
        return .unavailable(.missingParent(missing))
      }
      parentsByRevision[save.revisionID] = parents
      if let invalid = validatePayload(save, revision: revisionByID[save.revisionID]) { return invalid }
    }
    let revisionGraph = CausalGraph(parentsByNode: parentsByRevision, orderedBy: idPrecedes)
    if revisionGraph.containsCycle { return .recovery(.revisionCycle) }
    return projectSelections(
      evidence,
      saves: saves,
      selections: selections,
      revisions: revisions,
      revisionGraph: revisionGraph,
      parentsByRevision: parentsByRevision
    )
  }

  private static func validatePayload(
    _ save: RecipeSaveEvidence,
    revision: RecipeRevision?
  ) -> RecipeAuthorityProjection? {
    guard let revision else { return .unavailable(.missingRevision(save.revisionID)) }
    let expected: RecipePayloadManifest
    do {
      expected = try RecipePayloadManifestCodec.decode(
        formatVersion: save.payloadManifestFormatVersion,
        data: save.payloadManifestData
      )
    } catch let RecipeAuthorityCodecError.unsupportedFormat(version) {
      return .unavailable(.unsupportedFormat(version))
    } catch {
      return .recovery(.malformedEncoding)
    }
    let actual = RecipePayloadManifest(revision: revision)
    guard actual == expected else {
      return manifest(actual, isSubsetOf: expected)
        ? .unavailable(.incompleteManifest(save.revisionID))
        : .recovery(.manifestMismatch(save.revisionID))
    }
    guard save.revisionFormatVersion == RecipeRevisionCodec.formatVersion else {
      return .unavailable(.unsupportedFormat(save.revisionFormatVersion))
    }
    guard (try? RecipeRevisionCodec.encode(revision).digest) == save.revisionDigest else {
      return .recovery(.digestMismatch(save.revisionID))
    }
    return nil
  }

  // The explicit graph inputs keep this pure transition readable at its only call site.
  // swiftlint:disable:next function_parameter_count
  private static func projectSelections(
    _ evidence: RecipeAuthorityEvidence,
    saves: [RecipeSaveEvidence],
    selections: [RecipeSelectionEvidence],
    revisions: [RecipeRevision],
    revisionGraph: CausalGraph<RecipeRevision.ID>,
    parentsByRevision: [RecipeRevision.ID: [RecipeRevision.ID]]
  ) -> RecipeAuthorityProjection {
    let acceptedRevisionIDs = Set(saves.map(\.revisionID))
    var parentsBySelection: [UUID: [UUID]] = [:]
    for selection in selections {
      guard acceptedRevisionIDs.contains(selection.selectedRevisionID) else {
        return .recovery(.selectedRevisionIsNotAccepted(selection.selectedRevisionID))
      }
      do {
        let parents = try RecipeIdentifierSetCodec.decode(
          formatVersion: selection.frontierFormatVersion,
          data: selection.observedSelectionIDsData
        )
        if let missing = parents.first(where: { parent in !selections.contains { $0.id == parent } }) {
          return .unavailable(.missingSelection(missing))
        }
        parentsBySelection[selection.id] = parents
      } catch let RecipeAuthorityCodecError.unsupportedFormat(version) {
        return .unavailable(.unsupportedFormat(version))
      } catch {
        return .recovery(.malformedEncoding)
      }
    }
    let graph = CausalGraph(parentsByNode: parentsBySelection, orderedBy: uuidPrecedes)
    if graph.containsCycle { return .recovery(.selectionCycle) }
    let headIDs = Set(graph.maximalNodes)
    let selected = IdentityCollection.stableUnique(
      selections.filter { headIDs.contains($0.id) }.map(\.selectedRevisionID).sorted(by: idPrecedes),
      id: \.self
    )
    guard selected.count == 1 else { return .recovery(.competingSelections(selected)) }
    let currentID = selected[0]
    let projected = AvailableRecipeAuthority(
      recipe: Recipe(
        id: evidence.recipeID,
        kitchenID: evidence.kitchenID,
        currentRevisionID: currentID
      ),
      revisions: revisionPresentations(
        revisions,
        currentID: currentID,
        graph: revisionGraph,
        parentsByRevision: parentsByRevision
      )
    )
    return hasUnresolvedDeletion(evidence) ? .deleted(projected) : .available(projected)
  }

  private static func revisionPresentations(
    _ revisions: [RecipeRevision],
    currentID: RecipeRevision.ID,
    graph: CausalGraph<RecipeRevision.ID>,
    parentsByRevision: [RecipeRevision.ID: [RecipeRevision.ID]]
  ) -> [ProjectedRecipeRevision] {
    let reconciledIDs = Set(parentsByRevision.filter { $0.value.count > 1 }.keys)
    return revisions.sorted { idPrecedes($0.id, $1.id) }.map { revision in
      let state: ProjectedRecipeRevision.State
      if revision.id == currentID {
        state = .current
      } else if reconciledIDs.contains(revision.id) {
        state = .reconciled
      } else if graph.isAncestor(revision.id, of: currentID) {
        state = .previous
      } else {
        state = .competing
      }
      return ProjectedRecipeRevision(revision: revision, state: state)
    }
  }

  private static func pruneDisposition(
    _ evidence: RecipeAuthorityEvidence
  ) -> RecipeAuthorityProjection? {
    guard !evidence.prunes.isEmpty else { return nil }
    let prunes: [RecipePruneEvidence]
    switch IdentityCollection.coalesce(
      evidence.prunes,
      id: \RecipePruneEvidence.id
    ) {
    case let .coalesced(values): prunes = values
    case let .collision(identity): return .recovery(.commandCollision(identity))
    }
    guard prunes.allSatisfy({ $0.kitchenID == evidence.kitchenID && $0.recipeID == evidence.recipeID })
    else { return .recovery(.crossOwnership) }
    for prune in prunes {
      do {
        _ = try RecipeAuthorityFrontierCodec.decode(
          formatVersion: prune.frontierFormatVersion,
          data: prune.frontierData
        )
      } catch let RecipeAuthorityCodecError.unsupportedFormat(version) {
        return .unavailable(.unsupportedFormat(version))
      } catch {
        return .recovery(.malformedEncoding)
      }
      guard Data(SHA256.hash(data: prune.frontierData)) == prune.frontierDigest else {
        return .recovery(.malformedEncoding)
      }
    }
    let carriesLateEvidence = !evidence.saves.isEmpty || !evidence.selections.isEmpty
      || !evidence.revisions.isEmpty || !evidence.deletions.isEmpty
      || !evidence.restorations.isEmpty
    return carriesLateEvidence ? .recovery(.lateEvidenceAfterPrune) : .pruned
  }

  private static func hasUnresolvedDeletion(_ evidence: RecipeAuthorityEvidence) -> Bool {
    let validDeletions = evidence.deletions.filter {
      $0.kitchenID == evidence.kitchenID && $0.recipeID == evidence.recipeID
    }
    let resolved = Set(evidence.restorations.filter {
      ($0.kitchenID == nil || $0.kitchenID == evidence.kitchenID)
        && $0.recipeID == evidence.recipeID
    }.map(\.deletionID))
    return validDeletions.contains { !resolved.contains($0.id) }
  }

  private static func evidenceHasConsistentOwnership(
    _ evidence: RecipeAuthorityEvidence,
    saves: [RecipeSaveEvidence],
    selections: [RecipeSelectionEvidence]
  ) -> Bool {
    saves.allSatisfy { $0.kitchenID == evidence.kitchenID && $0.recipeID == evidence.recipeID }
      && selections.allSatisfy {
        $0.kitchenID == evidence.kitchenID && $0.recipeID == evidence.recipeID
      }
      && evidence.revisions.allSatisfy { $0.recipeID == evidence.recipeID }
      && evidence.deletions.allSatisfy {
        $0.kitchenID == evidence.kitchenID && $0.recipeID == evidence.recipeID
      }
      && evidence.restorations.allSatisfy {
        ($0.kitchenID == nil || $0.kitchenID == evidence.kitchenID)
          && $0.recipeID == evidence.recipeID
      }
  }

  private static func coalescedPayloads(
    _ revisions: [RecipeRevision]
  ) -> IdentityCoalescingResult<RecipeRevision, RecipeRevision.ID> {
    IdentityCollection.coalesce(revisions, id: \RecipeRevision.id, orderedBy: {
      idPrecedes($0.id, $1.id)
    })
  }

  private static func manifest(
    _ actual: RecipePayloadManifest,
    isSubsetOf expected: RecipePayloadManifest
  ) -> Bool {
    let actualFamilies: [Set<UUID>] = [
      Set(actual.mediaIDs.map(\.rawValue)),
      Set(actual.equipmentIDs.map(\.rawValue)),
      Set(actual.ingredientSectionIDs.map(\.rawValue)),
      Set(actual.ingredientIDs.map(\.rawValue)),
      Set(actual.instructionSectionIDs.map(\.rawValue)),
      Set(actual.instructionStepIDs.map(\.rawValue)),
    ]
    let expectedFamilies: [Set<UUID>] = [
      Set(expected.mediaIDs.map(\.rawValue)),
      Set(expected.equipmentIDs.map(\.rawValue)),
      Set(expected.ingredientSectionIDs.map(\.rawValue)),
      Set(expected.ingredientIDs.map(\.rawValue)),
      Set(expected.instructionSectionIDs.map(\.rawValue)),
      Set(expected.instructionStepIDs.map(\.rawValue)),
    ]
    return actual.revisionID == expected.revisionID
      && zip(actualFamilies, expectedFamilies).allSatisfy { $0.isSubset(of: $1) }
      && zip(actualFamilies, expectedFamilies).contains { $0.count < $1.count }
  }

  private static func idPrecedes<Entity>(
    _ lhs: StableIdentifier<Entity>,
    _ rhs: StableIdentifier<Entity>
  ) -> Bool {
    uuidPrecedes(lhs.rawValue, rhs.rawValue)
  }

  private static func uuidPrecedes(_ lhs: UUID, _ rhs: UUID) -> Bool {
    lhs.uuidString < rhs.uuidString
  }
}
