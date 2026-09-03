// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import XCTest

final class RecipeAuthorityProjectorFailureTests: XCTestCase {
  func testMissingTopLevelEvidenceAndIdentityConflictsAreClassified() throws {
    let fixture = RecipeAuthorityFixture()
    let first = fixture.revision(1)
    let second = fixture.revision(2)
    let save = try fixture.save(1, revision: first)
    let selection = fixture.selection(11, revision: first)
    XCTAssertEqual(
      RecipeAuthorityProjector.project(fixture.evidence(saves: [], selections: [], revisions: [])),
      .unavailable(.noSaveEvidence)
    )
    XCTAssertEqual(
      RecipeAuthorityProjector.project(fixture.evidence(
        saves: [save], selections: [], revisions: [first]
      )),
      .unavailable(.noSelectionEvidence)
    )
    XCTAssertEqual(
      RecipeAuthorityProjector.project(fixture.evidence(
        saves: [save], selections: [selection], revisions: [first, second]
      )),
      .unavailable(.missingSave(second.id))
    )

    let collidingSave = fixture.copy(save, savedAt: save.savedAt.addingTimeInterval(1))
    XCTAssertEqual(
      RecipeAuthorityProjector.project(fixture.evidence(
        saves: [save, collidingSave], selections: [selection], revisions: [first]
      )),
      .recovery(.commandCollision(save.id))
    )
    let duplicateRevision = RecipeRevision(
      id: first.id, recipeID: first.recipeID,
      revisionNumber: first.revisionNumber, title: "Conflicting payload"
    )
    XCTAssertEqual(
      RecipeAuthorityProjector.project(fixture.evidence(
        saves: [save], selections: [selection], revisions: [first, duplicateRevision]
      )),
      .recovery(.payloadCollision(first.id))
    )
    XCTAssertEqual(
      RecipeAuthorityProjector.project(fixture.evidence(
        saves: [fixture.copy(save, kitchenID: Kitchen.ID())],
        selections: [selection], revisions: [first]
      )),
      .recovery(.crossOwnership)
    )
  }

  func testSaveAndManifestCodecFailuresDistinguishUnavailableFromRecovery() throws {
    let fixture = RecipeAuthorityFixture()
    let revision = fixture.revision(1)
    let save = try fixture.save(1, revision: revision)
    let selection = fixture.selection(11, revision: revision)
    func project(_ changed: RecipeSaveEvidence, revision value: RecipeRevision = revision)
      -> RecipeAuthorityProjection {
      RecipeAuthorityProjector.project(fixture.evidence(
        saves: [changed], selections: [selection], revisions: [value]
      ))
    }

    XCTAssertEqual(project(fixture.copy(save, ancestryFormatVersion: 2)),
                   .unavailable(.unsupportedFormat(2)))
    XCTAssertEqual(project(fixture.copy(save, parentRevisionIDsData: Data([0]))),
                   .recovery(.malformedEncoding))
    XCTAssertEqual(project(fixture.copy(save, payloadManifestFormatVersion: 2)),
                   .unavailable(.unsupportedFormat(2)))
    XCTAssertEqual(project(fixture.copy(save, payloadManifestData: Data())),
                   .recovery(.malformedEncoding))
    XCTAssertEqual(project(fixture.copy(save, revisionFormatVersion: 2)),
                   .unavailable(.unsupportedFormat(2)))

    let media = RecipeMedia(role: .hero, assetName: "hero")
    let expectedComplete = RecipeRevision(
      id: revision.id, recipeID: revision.recipeID,
      revisionNumber: revision.revisionNumber, title: revision.title, media: [media]
    )
    let incomplete = RecipePayloadManifestCodec.encode(RecipePayloadManifest(
      revision: expectedComplete
    ))
    XCTAssertEqual(
      project(fixture.copy(save, payloadManifestData: incomplete.data)),
      .unavailable(.incompleteManifest(revision.id))
    )

    let other = RecipeMedia(role: .gallery, assetName: "other")
    let authored = RecipeRevision(
      id: revision.id, recipeID: revision.recipeID,
      revisionNumber: revision.revisionNumber, title: revision.title, media: [media, other]
    )
    let reordered = RecipeRevision(
      id: authored.id, recipeID: authored.recipeID,
      revisionNumber: authored.revisionNumber, title: authored.title, media: [other, media]
    )
    let authoredSave = try fixture.save(2, revision: authored)
    let manifest = RecipePayloadManifestCodec.encode(RecipePayloadManifest(revision: reordered))
    XCTAssertEqual(
      project(fixture.copy(authoredSave, payloadManifestData: manifest.data), revision: authored),
      .recovery(.manifestMismatch(authored.id))
    )

  }

  func testIncompleteRichManifestChecksEveryPayloadFamily() throws {
    let fixture = RecipeAuthorityFixture()
    let revision = fixture.revision(1)
    let selection = fixture.selection(11, revision: revision)
    let rich = RecipeRevision(
      id: revision.id, recipeID: revision.recipeID,
      revisionNumber: revision.revisionNumber, title: revision.title,
      media: [RecipeMedia(role: .hero, assetName: "hero")],
      equipment: [EquipmentItem(originalText: "Pan", name: "Pan")],
      ingredientSections: [
        IngredientSection(ingredients: [RecipeIngredient(originalText: "Salt")]),
      ],
      instructionSections: [
        InstructionSection(steps: [InstructionStep(text: "Stir")]),
      ]
    )
    var expectedRich = rich
    expectedRich.instructionSections[0].steps.append(InstructionStep(text: "Serve"))
    let richSave = try fixture.save(3, revision: rich)
    let expectedRichManifest = RecipePayloadManifestCodec.encode(
      RecipePayloadManifest(revision: expectedRich)
    )
    XCTAssertEqual(
      RecipeAuthorityProjector.project(fixture.evidence(
        saves: [fixture.copy(richSave, payloadManifestData: expectedRichManifest.data)],
        selections: [selection], revisions: [rich]
      )),
      .unavailable(.incompleteManifest(rich.id))
    )
  }

  func testSelectionReferenceAndCodecFailuresAreClassified() throws {
    let fixture = RecipeAuthorityFixture()
    let revision = fixture.revision(1)
    let save = try fixture.save(1, revision: revision)
    let unknown = fixture.revision(2)
    let selection = fixture.selection(11, revision: revision)
    func project(_ changed: RecipeSelectionEvidence) -> RecipeAuthorityProjection {
      RecipeAuthorityProjector.project(fixture.evidence(
        saves: [save], selections: [changed], revisions: [revision]
      ))
    }

    XCTAssertEqual(
      project(fixture.copy(selection, selectedRevisionID: unknown.id)),
      .recovery(.selectedRevisionIsNotAccepted(unknown.id))
    )
    let missingSelectionID = fixture.id(99)
    let missingFrontier = RecipeIdentifierSetCodec.encode([missingSelectionID])
    XCTAssertEqual(
      project(fixture.copy(selection, observedSelectionIDsData: missingFrontier.data)),
      .unavailable(.missingSelection(missingSelectionID))
    )
    XCTAssertEqual(project(fixture.copy(selection, frontierFormatVersion: 2)),
                   .unavailable(.unsupportedFormat(2)))
    XCTAssertEqual(project(fixture.copy(selection, observedSelectionIDsData: Data([0]))),
                   .recovery(.malformedEncoding))
  }

  func testPruneValidationRejectsCollisionsOwnershipCodecsAndDigests() {
    let fixture = RecipeAuthorityFixture()
    let encoded = RecipeAuthorityFrontierCodec.encode(RecipeAuthorityFrontier(
      revisionHeads: [], selectionHeads: [], deletionIDs: [], restorationIDs: []
    ))
    let prune = fixture.prune(encoded: encoded)
    func project(_ prunes: [RecipePruneEvidence]) -> RecipeAuthorityProjection {
      RecipeAuthorityProjector.project(fixture.evidence(
        saves: [], selections: [], revisions: [], prunes: prunes
      ))
    }

    let changedHorizon = fixture.copy(
      prune,
      antiResurrectionUntil: prune.antiResurrectionUntil.addingTimeInterval(1)
    )
    XCTAssertEqual(project([prune, changedHorizon]), .recovery(.commandCollision(prune.id)))
    XCTAssertEqual(project([fixture.copy(prune, kitchenID: Kitchen.ID())]),
                   .recovery(.crossOwnership))
    XCTAssertEqual(project([fixture.copy(prune, frontierFormatVersion: 2)]),
                   .unavailable(.unsupportedFormat(2)))
    XCTAssertEqual(project([fixture.copy(prune, frontierData: Data())]),
                   .recovery(.malformedEncoding))
    XCTAssertEqual(project([fixture.copy(prune, frontierDigest: Data())]),
                   .recovery(.malformedEncoding))
  }

  func testDispositionDuplicatesAndDanglingRestorationAreValidated() throws {
    let fixture = RecipeAuthorityFixture()
    let revision = fixture.revision(1)
    let save = try fixture.save(1, revision: revision)
    let selection = fixture.selection(11, revision: revision)
    let deletion = RecipeDeletionEvidence(
      id: fixture.id(30), kitchenID: fixture.kitchenID, recipeID: fixture.recipeID,
      deletedAt: Date(timeIntervalSince1970: 30)
    )
    let collision = RecipeDeletionEvidence(
      id: deletion.id, kitchenID: deletion.kitchenID, recipeID: deletion.recipeID,
      deletedAt: Date(timeIntervalSince1970: 31)
    )
    XCTAssertEqual(
      RecipeAuthorityProjector.project(fixture.evidence(
        saves: [save], selections: [selection], revisions: [revision],
        deletions: [deletion, collision]
      )),
      .recovery(.commandCollision(deletion.id))
    )

    let missingDeletionID = fixture.id(87)
    let restoration = RecipeRestorationEvidence(
      id: fixture.id(31), deletionID: fixture.id(88), kitchenID: fixture.kitchenID,
      recipeID: fixture.recipeID, restoredAt: Date(timeIntervalSince1970: 31)
    )
    let earlierMissingRestoration = RecipeRestorationEvidence(
      id: fixture.id(32), deletionID: missingDeletionID, kitchenID: fixture.kitchenID,
      recipeID: fixture.recipeID, restoredAt: Date(timeIntervalSince1970: 32)
    )
    XCTAssertEqual(
      RecipeAuthorityProjector.project(fixture.evidence(
        saves: [save], selections: [selection], revisions: [revision],
        restorations: [restoration, earlierMissingRestoration]
      )),
      .unavailable(.missingDeletion(missingDeletionID))
    )
    let restorationCollision = RecipeRestorationEvidence(
      id: restoration.id, deletionID: deletion.id, kitchenID: restoration.kitchenID,
      recipeID: restoration.recipeID, restoredAt: restoration.restoredAt
    )
    XCTAssertEqual(
      RecipeAuthorityProjector.project(fixture.evidence(
        saves: [save], selections: [selection], revisions: [revision],
        deletions: [deletion], restorations: [restoration, restorationCollision]
      )),
      .recovery(.commandCollision(restoration.id))
    )
  }
}

extension RecipeAuthorityFixture {
  func copy(
    _ save: RecipeSaveEvidence,
    kitchenID: Kitchen.ID? = nil,
    savedAt: Date? = nil,
    ancestryFormatVersion: Int? = nil,
    parentRevisionIDsData: Data? = nil,
    payloadManifestFormatVersion: Int? = nil,
    payloadManifestData: Data? = nil,
    revisionFormatVersion: Int? = nil
  ) -> RecipeSaveEvidence {
    RecipeSaveEvidence(
      id: save.id, kitchenID: kitchenID ?? save.kitchenID, recipeID: save.recipeID,
      revisionID: save.revisionID, savedAt: savedAt ?? save.savedAt,
      ancestryFormatVersion: ancestryFormatVersion ?? save.ancestryFormatVersion,
      parentRevisionIDsData: parentRevisionIDsData ?? save.parentRevisionIDsData,
      payloadManifestFormatVersion: payloadManifestFormatVersion ?? save.payloadManifestFormatVersion,
      payloadManifestData: payloadManifestData ?? save.payloadManifestData,
      revisionFormatVersion: revisionFormatVersion ?? save.revisionFormatVersion,
      revisionDigest: save.revisionDigest
    )
  }

  func copy(
    _ selection: RecipeSelectionEvidence,
    selectedRevisionID: RecipeRevision.ID? = nil,
    frontierFormatVersion: Int? = nil,
    observedSelectionIDsData: Data? = nil
  ) -> RecipeSelectionEvidence {
    RecipeSelectionEvidence(
      id: selection.id, kitchenID: selection.kitchenID, recipeID: selection.recipeID,
      selectedRevisionID: selectedRevisionID ?? selection.selectedRevisionID,
      selectedAt: selection.selectedAt,
      frontierFormatVersion: frontierFormatVersion ?? selection.frontierFormatVersion,
      observedSelectionIDsData: observedSelectionIDsData ?? selection.observedSelectionIDsData
    )
  }

  func prune(encoded: EncodedRecipeAuthorityFrontier) -> RecipePruneEvidence {
    RecipePruneEvidence(
      id: id(40), kitchenID: kitchenID, recipeID: recipeID,
      prunedAt: Date(timeIntervalSince1970: 40),
      antiResurrectionUntil: Date(timeIntervalSince1970: 50),
      frontierFormatVersion: encoded.formatVersion, frontierData: encoded.data,
      frontierDigest: encoded.digest
    )
  }

  func copy(
    _ prune: RecipePruneEvidence,
    kitchenID: Kitchen.ID? = nil,
    antiResurrectionUntil: Date? = nil,
    frontierFormatVersion: Int? = nil,
    frontierData: Data? = nil,
    frontierDigest: Data? = nil
  ) -> RecipePruneEvidence {
    RecipePruneEvidence(
      id: prune.id, kitchenID: kitchenID ?? prune.kitchenID, recipeID: prune.recipeID,
      prunedAt: prune.prunedAt,
      antiResurrectionUntil: antiResurrectionUntil ?? prune.antiResurrectionUntil,
      frontierFormatVersion: frontierFormatVersion ?? prune.frontierFormatVersion,
      frontierData: frontierData ?? prune.frontierData,
      frontierDigest: frontierDigest ?? prune.frontierDigest
    )
  }
}
