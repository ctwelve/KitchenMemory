// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation
import KitchenKit
import Observation

/// Owns device-local staging, ordered retry, and retirement. The existing store
/// provides its usual guarantees; this does not imply synchronized delivery or
/// stronger crash durability than UserDefaults offers.
///
/// ``CookingSessionPresentationModel`` invokes this owner from user actions,
/// first load, explicit retry, and external-store refresh. Commands are stored
/// with final identities before submission; accepted Entry draft effects are
/// stored before retirement. These steps permit the same intention to be retried
/// if service acceptance succeeds before local retirement is recorded.
@MainActor
@Observable
final class CookingSessionDelivery {
  enum Failure {
    case command(CookingSessionLogicError)
    case attention(CookingSessionAttention)
    case unavailable
  }

  enum Event {
    case resolved(PendingCookingSessionCommand, PendingCookingSessionResolution)
    case failed(PendingCookingSessionCommand?, Failure)
  }

  struct Report {
    let requested: PendingCookingSessionCommand?
    let events: [Event]

    var wasAccepted: Bool {
      events.contains {
        guard case .resolved(let command, .accepted(let session)) = $0 else { return false }
        return command == requested && command.hasAcceptedEntry(in: session)
      }
    }

    var completedRestore: Bool {
      events.contains {
        guard case .resolved(let command, .retiredCompletedRestore) = $0 else { return false }
        return command == requested
      }
    }
  }

  private let service: any CookingSessionServing
  private let store: any CookingSessionPresentationStoring
  private var outbox: CookingSessionOutbox
  private(set) var entryDrafts: [CookingSessionEntryDraft]

  init(service: any CookingSessionServing, store: any CookingSessionPresentationStoring) {
    self.service = service
    self.store = store
    outbox = CookingSessionOutbox(persistedCommands: store.pendingCommands)
    entryDrafts = store.entryDrafts
  }

  var pendingCommands: [PendingCookingSessionCommand] { outbox.commands }

  /// Prepare ordinary commands only after earlier work is retired. In
  /// particular, restore consent must observe the post-retry deletion frontier.
  func submit(_ makeCommand: () throws -> PendingCookingSessionCommand?) -> Report {
    var events = retry()
    guard outbox.isEmpty else { return Report(requested: nil, events: events) }
    do {
      guard let command = try makeCommand() else { return Report(requested: nil, events: events) }
      outbox.enqueue(command)
      store.pendingCommands = outbox.commands
      events += retry()
      return Report(requested: command, events: events)
    } catch {
      events.append(.failed(nil, .unavailable))
    }
    return Report(requested: nil, events: events)
  }

  /// Progress and scale may queue behind activity for the same Session, but
  /// cannot overtake ordinary commands or activity for another Session.
  func submitIndependent(_ command: PendingCookingSessionCommand) -> Report {
    guard command.isIndependentActivity(for: command.sessionID),
          outbox.allSatisfy({ $0.isIndependentActivity(for: command.sessionID) }) else {
      return Report(requested: command, events: [])
    }
    outbox.enqueue(command)
    store.pendingCommands = outbox.commands
    return Report(requested: command, events: retry())
  }

  /// Drains the FIFO until the first unresolved result, preserving exact identities.
  ///
  /// Acceptance applies draft effects before removing the head. Terminal
  /// classifications also retire the head; attention and thrown failures leave
  /// it pending and stop later work from overtaking it. Returned events let
  /// presentation choose dialogs and navigation after delivery is resolved.
  func retry() -> [Event] {
    var events: [Event] = []
    while let pending = outbox.head {
      do {
        let result = try pending.perform(using: service)
        let resolution = PendingCookingSessionResolution(result: result, pending: pending)
        if case .attention(let attention) = resolution {
          events.append(.failed(pending, .attention(attention)))
          return events
        }
        // Navigation happens later in the report consumer. A window veto there
        // cannot roll back acceptance or put this retired identity back in the FIFO.
        if case .accepted(let session) = resolution {
          applyDraftAcceptance(for: pending, session: session)
        }
        outbox.retireHead()
        store.pendingCommands = outbox.commands
        events.append(.resolved(pending, resolution))
      } catch let error as CookingSessionLogicError {
        events.append(.failed(pending, .command(error)))
        return events
      } catch {
        events.append(.failed(pending, .unavailable))
        return events
      }
    }
    return events
  }

  func replaceDraft(_ draft: CookingSessionEntryDraft) {
    entryDrafts.removeAll { $0.sessionID == draft.sessionID }
    entryDrafts.append(draft)
    store.entryDrafts = entryDrafts
  }

  func removeDraft(for sessionID: CookingSession.ID) {
    entryDrafts.removeAll { $0.sessionID == sessionID }
    store.entryDrafts = entryDrafts
  }

  /// Called only after the durable Kitchen reset succeeds, matching the existing
  /// presentation-store reset (including local selection and visit timestamps).
  func reset() {
    store.clear()
    outbox = CookingSessionOutbox(persistedCommands: [])
    entryDrafts = []
  }

  private func applyDraftAcceptance(for pending: PendingCookingSessionCommand,
                                    session: CookingSessionProjection) {
    switch pending {
    case let .submitEntry(_, sessionID, _, text, target):
      guard pending.hasAcceptedEntry(in: session),
            let draft = entryDrafts.first(where: { $0.sessionID == sessionID }),
            draft.text == text, draft.target == target else { return }
      removeDraft(for: sessionID)
    case let .continueSession(destinationID, sourceID, _):
      guard let draft = entryDrafts.first(where: { $0.sessionID == sourceID }) else { return }
      let target = draft.target.flatMap { sourceTarget in
        session.snapshot.continuationBaseline?.targetMappings.first {
          $0.sourceTarget == sourceTarget
        }?.target
      }
      entryDrafts.removeAll { $0.sessionID == sourceID || $0.sessionID == destinationID }
      entryDrafts.append(.init(sessionID: destinationID, text: draft.text, target: target))
      store.entryDrafts = entryDrafts
    case .start, .stop, .resume, .progress, .replaceWorkingScale, .reviseEntry,
         .retargetEntry, .withdrawEntry, .setOutcome, .clearOutcome, .finish,
         .delete, .restore, .resolveClosure:
      break
    }
  }
}


extension PendingCookingSessionCommand {
  /// Entry acceptance must include the exact authored fact, not merely a Session read.
  func hasAcceptedEntry(in session: CookingSessionProjection) -> Bool {
    guard case let .submitEntry(factID, sessionID, _, text, target) = self else { return true }
    return session.id == sessionID && session.entries.contains {
      $0.id.rawValue == factID.rawValue && $0.text == text && $0.target == target
    }
  }
}
