// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct CookingSessionDeletionConfirmation: ViewModifier {
  @Binding var isPresented: Bool
  let model: CookingSessionPresentationModel
  let sessionID: CookingSession.ID

  func body(content: Content) -> some View {
    content.confirmationDialog(
      .sessionDeleteConfirmationTitle,
      isPresented: $isPresented,
      titleVisibility: .visible
    ) {
      Button(.sessionDeleteAction, role: .destructive) {
        model.deleteSession(sessionID)
      }
      .accessibilityIdentifier("confirm-delete-session")
      Button(.actionCancel, role: .cancel) {}
    } message: {
      Text(message)
    }
  }

  private var message: LocalizedStringResource {
    model.knownDescendantCount(of: sessionID) > 0
      ? .sessionDeleteDescendantMessage
      : .sessionDeleteConfirmationMessage
  }
}

extension View {
  func cookingSessionDeletionConfirmation(
    isPresented: Binding<Bool>,
    model: CookingSessionPresentationModel,
    sessionID: CookingSession.ID
  ) -> some View {
    modifier(CookingSessionDeletionConfirmation(
      isPresented: isPresented,
      model: model,
      sessionID: sessionID
    ))
  }
}
