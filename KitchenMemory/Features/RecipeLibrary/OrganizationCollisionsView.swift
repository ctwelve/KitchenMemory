// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct OrganizationCollisionsView: View {
  @Bindable var model: RecipeOrganizationModel
  var offersManagement = true
  @State private var merge: RecipeOrganizationCommand?
  var body: some View {
    Section {
      if model.snapshot == nil || model.pending != nil || model.storageInvalid {
        Button(.organizationRetry) { model.retry() }
      }
      if model.changeRejected { Button(.organizationDiscardRejected) { model.discardRejectedChange() } }
      if let snapshot = model.snapshot {
        ForEach(snapshot.folders.collisions, id: \.folderIDs) { collision in
          let names = snapshot.folders.folders.filter { collision.folderIDs.contains($0.id) }.map(\.name)
          HStack {
            Text(names.joined(separator: " / "))
            Button(.organizationMerge) {
              model.failed = false
              do {
                merge = try snapshot.prepare(folder: .merge(ids: collision.folderIDs, survivorID: nil,
                                                           name: names.first ?? ""))
              } catch { model.failed = true }
            }
          }
        }
        ForEach(snapshot.tags.collisions, id: \.tagIDs) { collision in
          let names = snapshot.tags.tags.filter { collision.tagIDs.contains($0.id) }.map(\.name)
          HStack {
            Text(names.joined(separator: " / "))
            Button(.organizationMerge) {
              do {
                merge = try snapshot.prepare(tag: .merge(ids: collision.tagIDs, survivorID: nil,
                                                        name: names.first ?? ""))
              } catch { model.failed = true }
            }
          }
        }
      }
      if offersManagement { OrganizationManagementButton(model: model) }
    } header: { Text(.organizationCollisions).accessibilityHeading(.h2) }
    .accessibilityIdentifier("organization-collisions")
    .confirmationDialog(
      .organizationMergeConfirm, isPresented: Binding(get: { merge != nil }, set: { if !$0 { merge = nil } })
    ) {
      Button(.organizationMerge) { if let merge { model.perform { _ in merge } }; merge = nil }
      Button(.actionCancel, role: .cancel) { merge = nil }
    } message: { Text(.organizationMergeMessage) }
  }
}
