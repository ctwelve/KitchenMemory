// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

/// Readable lineage uses retained Sessions; an absent predecessor never gates reading.
struct CookingSessionLineageView: View {
  let model: CookingSessionPresentationModel
  let session: CookingSessionProjection

  var body: some View {
    CookingSessionCard(title: .sessionHistoryLineage, symbol: "point.3.connected.trianglepath.dotted") {
      if let sourceID = session.sourceSessionID {
        Text(.sessionHistoryLineageSource)
          .font(.subheadline)
        if let source = model.retainedSession(sourceID) {
          CookingSessionHistoryRow(session: source)
        } else {
          Text(.sessionHistoryLineageUnavailable)
            .foregroundStyle(.secondary)
        }
      } else {
        Text(.sessionHistoryLineageOriginal)
          .foregroundStyle(.secondary)
      }
      ForEach(model.continuations(of: session.id), id: \.id) { continuation in
        Text(.sessionHistoryLineageContinuation)
          .font(.subheadline)
        CookingSessionHistoryRow(session: continuation)
      }
    }
    .accessibilityIdentifier("session-lineage")
  }
}
