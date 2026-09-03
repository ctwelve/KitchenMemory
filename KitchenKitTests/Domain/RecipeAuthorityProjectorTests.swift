// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

@testable import KitchenKit
import Foundation
import XCTest

final class RecipeAuthorityProjectorTests: XCTestCase {
  func testLinearSelectionUsesEvidenceNotRevisionNumbersOrDates() throws {
    let fixture = Fixture()
    let first = fixture.revision(1, number: 99, title: "First")
    let second = fixture.revision(2, number: 1, title: "Second")
    let rootSelection = fixture.selection(11, revision: first)
    let currentSelection = fixture.selection(12, revision: second, observed: [rootSelection.id])
    let evidence = fixture.evidence(
      saves: [try fixture.save(2, revision: second, parents: [first.id]), try fixture.save(1, revision: first)],
      selections: [currentSelection, rootSelection],
      revisions: [second, first]
    )

    guard case let .available(projected) = RecipeAuthorityProjector.project(evidence) else {
      XCTFail("Expected available Recipe")
      return
    }
    XCTAssertEqual(projected.current, second)
    XCTAssertEqual(projected.revisions.first { $0.revision.id == first.id }?.state, .previous)
  }

  func testConcurrentSiblingRemainsCompetingBesideExplicitCurrentSelection() throws {
    let fixture = Fixture()
    let root = fixture.revision(1)
    let chosen = fixture.revision(2)
    let sibling = fixture.revision(3)
    let initial = fixture.selection(11, revision: root)
    let chosenSelection = fixture.selection(12, revision: chosen, observed: [initial.id])
    let evidence = fixture.evidence(
      saves: [
        try fixture.save(1, revision: root),
        try fixture.save(2, revision: chosen, parents: [root.id]),
        try fixture.save(3, revision: sibling, parents: [root.id]),
      ],
      selections: [initial, chosenSelection],
      revisions: [root, chosen, sibling]
    )

    guard case let .available(projected) = RecipeAuthorityProjector.project(evidence) else {
      XCTFail("Expected available Recipe")
      return
    }
    XCTAssertEqual(projected.current.id, chosen.id)
    XCTAssertEqual(projected.revisions.first { $0.revision.id == sibling.id }?.state, .competing)
  }

  func testMultiParentRevisionReconcilesBranches() throws {
    let fixture = Fixture()
    let root = fixture.revision(1)
    let firstBranch = fixture.revision(2)
    let secondBranch = fixture.revision(3)
    let reconciled = fixture.revision(4)
    let later = fixture.revision(5)
    let selections = [
      fixture.selection(11, revision: root),
      fixture.selection(12, revision: reconciled, observed: [fixture.id(11)]),
      fixture.selection(13, revision: later, observed: [fixture.id(12)]),
    ]
    let evidence = fixture.evidence(
      saves: [
        try fixture.save(1, revision: root),
        try fixture.save(2, revision: firstBranch, parents: [root.id]),
        try fixture.save(3, revision: secondBranch, parents: [root.id]),
        try fixture.save(4, revision: reconciled, parents: [secondBranch.id, firstBranch.id]),
        try fixture.save(5, revision: later, parents: [reconciled.id]),
      ],
      selections: selections,
      revisions: [later, secondBranch, root, reconciled, firstBranch]
    )

    guard case let .available(projected) = RecipeAuthorityProjector.project(evidence) else {
      XCTFail("Expected available Recipe")
      return
    }
    XCTAssertEqual(projected.current.id, later.id)
    XCTAssertEqual(projected.revisions.first { $0.revision.id == reconciled.id }?.state, .reconciled)
  }

  func testExactDuplicatesAndEveryInputPermutationProjectIdentically() throws {
    let fixture = Fixture()
    let first = fixture.revision(1)
    let second = fixture.revision(2)
    let firstSave = try fixture.save(1, revision: first)
    let secondSave = try fixture.save(2, revision: second, parents: [first.id])
    let firstSelection = fixture.selection(11, revision: first)
    let secondSelection = fixture.selection(12, revision: second, observed: [firstSelection.id])
    let expected = RecipeAuthorityProjector.project(fixture.evidence(
      saves: [firstSave, secondSave],
      selections: [firstSelection, secondSelection],
      revisions: [first, second]
    ))

    for saves in [[secondSave, firstSave], [firstSave, secondSave, firstSave]] {
      for selections in [[secondSelection, firstSelection], [firstSelection, secondSelection, firstSelection]] {
        XCTAssertEqual(
          RecipeAuthorityProjector.project(fixture.evidence(
            saves: saves,
            selections: selections,
            revisions: [second, first, first]
          )),
          expected
        )
      }
    }
  }

  func testConflictingDuplicateAndCompetingSelectionHeadsRequireRecovery() throws {
    let fixture = Fixture()
    let first = fixture.revision(1)
    let second = fixture.revision(2)
    let third = fixture.revision(3)
    let root = fixture.selection(11, revision: first)
    let secondSelection = fixture.selection(12, revision: second, observed: [root.id])
    let thirdSelection = fixture.selection(13, revision: third, observed: [root.id])
    let saves = [
      try fixture.save(1, revision: first),
      try fixture.save(2, revision: second, parents: [first.id]),
      try fixture.save(3, revision: third, parents: [first.id]),
    ]
    let collision = RecipeSelectionEvidence(
      id: root.id,
      kitchenID: fixture.kitchenID,
      recipeID: fixture.recipeID,
      selectedRevisionID: second.id,
      selectedAt: root.selectedAt,
      frontierFormatVersion: root.frontierFormatVersion,
      observedSelectionIDsData: root.observedSelectionIDsData
    )
    XCTAssertEqual(
      RecipeAuthorityProjector.project(fixture.evidence(
        saves: saves,
        selections: [root, collision],
        revisions: [first, second, third]
      )),
      .recovery(.commandCollision(root.id))
    )
    XCTAssertEqual(
      RecipeAuthorityProjector.project(fixture.evidence(
        saves: saves,
        selections: [root, secondSelection, thirdSelection],
        revisions: [first, second, third]
      )),
      .recovery(.competingSelections([second.id, third.id]))
    )
  }

  func testMissingAndCyclicEvidenceClassifyWithoutChoosingAWinner() throws {
    let fixture = Fixture()
    let first = fixture.revision(1)
    let missing = RecipeRevision.ID(rawValue: fixture.id(99))
    XCTAssertEqual(
      RecipeAuthorityProjector.project(fixture.evidence(
        saves: [try fixture.save(1, revision: first, parents: [missing])],
        selections: [fixture.selection(11, revision: first)],
        revisions: [first]
      )),
      .unavailable(.missingParent(missing))
    )

    let second = fixture.revision(2)
    XCTAssertEqual(
      RecipeAuthorityProjector.project(fixture.evidence(
        saves: [
          try fixture.save(1, revision: first, parents: [second.id]),
          try fixture.save(2, revision: second, parents: [first.id]),
        ],
        selections: [fixture.selection(11, revision: first)],
        revisions: [first, second]
      )),
      .recovery(.revisionCycle)
    )

    let firstSelection = fixture.selection(11, revision: first, observed: [fixture.id(12)])
    let secondSelection = fixture.selection(12, revision: first, observed: [fixture.id(11)])
    XCTAssertEqual(
      RecipeAuthorityProjector.project(fixture.evidence(
        saves: [try fixture.save(1, revision: first)],
        selections: [firstSelection, secondSelection],
        revisions: [first]
      )),
      .recovery(.selectionCycle)
    )
  }

  func testMissingPayloadIsUnavailableWhileDigestMismatchRequiresRecovery() throws {
    let fixture = Fixture()
    let revision = fixture.revision(1)
    let save = try fixture.save(1, revision: revision)
    let selection = fixture.selection(11, revision: revision)
    XCTAssertEqual(
      RecipeAuthorityProjector.project(fixture.evidence(
        saves: [save], selections: [selection], revisions: []
      )),
      .unavailable(.missingRevision(revision.id))
    )

    let corrupt = RecipeSaveEvidence(
      id: save.id,
      kitchenID: save.kitchenID,
      recipeID: save.recipeID,
      revisionID: save.revisionID,
      savedAt: save.savedAt,
      ancestryFormatVersion: save.ancestryFormatVersion,
      parentRevisionIDsData: save.parentRevisionIDsData,
      payloadManifestFormatVersion: save.payloadManifestFormatVersion,
      payloadManifestData: save.payloadManifestData,
      revisionFormatVersion: save.revisionFormatVersion,
      revisionDigest: Data(repeating: 0, count: 32)
    )
    XCTAssertEqual(
      RecipeAuthorityProjector.project(fixture.evidence(
        saves: [corrupt], selections: [selection], revisions: [revision]
      )),
      .recovery(.digestMismatch(revision.id))
    )
  }
}

extension RecipeAuthorityProjectorTests {
  func testDeletionAndRestorationChangeVisibilityWithoutChangingCurrentness() throws {
    let fixture = Fixture()
    let revision = fixture.revision(1)
    let save = try fixture.save(1, revision: revision)
    let selection = fixture.selection(11, revision: revision)
    let deletion = RecipeDeletionEvidence(
      id: fixture.id(30),
      kitchenID: fixture.kitchenID,
      recipeID: fixture.recipeID,
      deletedAt: Date(timeIntervalSince1970: 30)
    )
    let deletedEvidence = RecipeAuthorityEvidence(
      kitchenID: fixture.kitchenID,
      recipeID: fixture.recipeID,
      saves: [save],
      selections: [selection],
      revisions: [revision],
      deletions: [deletion]
    )
    guard case let .deleted(projected) = RecipeAuthorityProjector.project(deletedEvidence) else {
      XCTFail("Expected deleted Recipe")
      return
    }
    XCTAssertEqual(projected.current, revision)

    let restoration = RecipeRestorationEvidence(
      id: fixture.id(31),
      deletionID: deletion.id,
      kitchenID: fixture.kitchenID,
      recipeID: fixture.recipeID,
      restoredAt: Date(timeIntervalSince1970: 31)
    )
    let restoredEvidence = RecipeAuthorityEvidence(
      kitchenID: fixture.kitchenID,
      recipeID: fixture.recipeID,
      saves: [save],
      selections: [selection],
      revisions: [revision],
      deletions: [deletion],
      restorations: [restoration]
    )
    guard case let .available(restored) = RecipeAuthorityProjector.project(restoredEvidence) else {
      XCTFail("Expected restored Recipe")
      return
    }
    XCTAssertEqual(restored.current, revision)
  }

  func testPruneTombstoneRejectsLatePayloadEvidence() {
    let fixture = Fixture()
    let encoded = RecipeAuthorityFrontierCodec.encode(RecipeAuthorityFrontier(
      revisionHeads: [],
      selectionHeads: [],
      deletionIDs: [],
      restorationIDs: []
    ))
    let prune = RecipePruneEvidence(
      id: fixture.id(40),
      kitchenID: fixture.kitchenID,
      recipeID: fixture.recipeID,
      prunedAt: Date(timeIntervalSince1970: 40),
      antiResurrectionUntil: Date(timeIntervalSince1970: 50),
      frontierFormatVersion: encoded.formatVersion,
      frontierData: encoded.data,
      frontierDigest: encoded.digest
    )
    let pruned = RecipeAuthorityEvidence(
      kitchenID: fixture.kitchenID,
      recipeID: fixture.recipeID,
      saves: [],
      selections: [],
      revisions: [],
      prunes: [prune]
    )
    XCTAssertEqual(RecipeAuthorityProjector.project(pruned), .pruned)

    let late = RecipeAuthorityEvidence(
      kitchenID: fixture.kitchenID,
      recipeID: fixture.recipeID,
      saves: [],
      selections: [],
      revisions: [fixture.revision(1)],
      prunes: [prune]
    )
    XCTAssertEqual(
      RecipeAuthorityProjector.project(late),
      .recovery(.lateEvidenceAfterPrune)
    )
  }
}

private struct Fixture {
  let kitchenID = Kitchen.ID(rawValue: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!)
  let recipeID = Recipe.ID(rawValue: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!)

  func id(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
  }

  func revision(_ value: Int, number: Int? = nil, title: String? = nil) -> RecipeRevision {
    RecipeRevision(
      id: .init(rawValue: id(value)),
      recipeID: recipeID,
      revisionNumber: number ?? value,
      title: title ?? "Revision \(value)"
    )
  }

  func save(
    _ value: Int,
    revision: RecipeRevision,
    parents: [RecipeRevision.ID] = []
  ) throws -> RecipeSaveEvidence {
    let ancestry = RecipeIdentifierSetCodec.encode(parents.map(\.rawValue))
    let manifest = RecipePayloadManifestCodec.encode(RecipePayloadManifest(revision: revision))
    let encoded = try RecipeRevisionCodec.encode(revision)
    return RecipeSaveEvidence(
      id: id(100 + value),
      kitchenID: kitchenID,
      recipeID: recipeID,
      revisionID: revision.id,
      savedAt: Date(timeIntervalSince1970: TimeInterval(10_000 - value)),
      ancestryFormatVersion: ancestry.formatVersion,
      parentRevisionIDsData: ancestry.data,
      payloadManifestFormatVersion: manifest.formatVersion,
      payloadManifestData: manifest.data,
      revisionFormatVersion: encoded.formatVersion,
      revisionDigest: encoded.digest
    )
  }

  func selection(
    _ value: Int,
    revision: RecipeRevision,
    observed: [UUID] = []
  ) -> RecipeSelectionEvidence {
    let frontier = RecipeIdentifierSetCodec.encode(observed)
    return RecipeSelectionEvidence(
      id: id(value),
      kitchenID: kitchenID,
      recipeID: recipeID,
      selectedRevisionID: revision.id,
      selectedAt: Date(timeIntervalSince1970: TimeInterval(value)),
      frontierFormatVersion: frontier.formatVersion,
      observedSelectionIDsData: frontier.data
    )
  }

  func evidence(
    saves: [RecipeSaveEvidence],
    selections: [RecipeSelectionEvidence],
    revisions: [RecipeRevision]
  ) -> RecipeAuthorityEvidence {
    RecipeAuthorityEvidence(
      kitchenID: kitchenID,
      recipeID: recipeID,
      saves: saves,
      selections: selections,
      revisions: revisions
    )
  }
}
