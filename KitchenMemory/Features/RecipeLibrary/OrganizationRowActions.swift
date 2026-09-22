// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import Observation
import SwiftUI

@MainActor
@Observable
final class OrganizationActionPresentation {
  var edits: OrganizationNameEdit?
  var merge: RecipeOrganizationCommand?
  var deletion: RecipeOrganizationCommand?
}

struct OrganizationFolderActions: View {
  let model: RecipeOrganizationModel
  let folder: Folder
  @Bindable var presentation: OrganizationActionPresentation
  @Environment(\.locale) private var locale

  var body: some View {
    if let snapshot = model.snapshot {
      Button(.organizationRename) { presentation.edits = .init(folder: folder) }
      Menu(.organizationParent) {
        Button(.organizationRoot) {
          model.perform { try $0.prepare(folder: .move(id: folder.id, parentID: nil)) }
        }
        ForEach(
          snapshot.folders.destinations(locale: locale).filter {
            !snapshot.folders.subtree(of: folder.id).contains($0.id)
          }
        ) { parent in
          Button(parent.path) {
            model.perform { try $0.prepare(folder: .move(id: folder.id, parentID: parent.id)) }
          }
        }
      }
      if snapshot.folders.ordering == .manual {
        Button(.organizationFirst) {
          model.perform { try $0.prepare(folder: .reorder(id: folder.id, afterID: nil)) }
        }
        Menu(.organizationAfter) {
          ForEach(
            snapshot.folders.children(of: folder.parentID, locale: locale).filter { $0.id != folder.id }
          ) { anchor in
            Button(anchor.name) {
              model.perform { try $0.prepare(folder: .reorder(id: folder.id, afterID: anchor.id)) }
            }
          }
        }
      }
      Menu(.organizationMerge) {
        ForEach(
          snapshot.folders.folders.filter { $0.id != folder.id && $0.parentID == folder.parentID }
        ) { other in
          Button(other.name) {
            do {
              presentation.merge = try snapshot.prepare(
                folder: .merge(ids: [folder.id, other.id], survivorID: nil, name: folder.name))
            } catch { model.failed = true }
          }
        }
      }
      Button(.organizationDelete, role: .destructive) {
        presentation.deletion = try? snapshot.prepare(folder: .delete(id: folder.id))
      }
    }
  }
}

struct OrganizationTagActions: View {
  let model: RecipeOrganizationModel
  let tag: Tag
  @Bindable var presentation: OrganizationActionPresentation
  @Environment(\.locale) private var locale

  var body: some View {
    if let snapshot = model.snapshot {
      Button(.organizationRename) { presentation.edits = .init(tag: tag) }
      if snapshot.tags.ordering == .manual {
        Button(.organizationFirst) {
          model.perform { try $0.prepare(tag: .reorder(id: tag.id, afterID: nil)) }
        }
        Menu(.organizationAfter) {
          ForEach(snapshot.tags.orderedTags(locale: locale).filter { $0.id != tag.id }) { anchor in
            Button(anchor.displayName) {
              model.perform { try $0.prepare(tag: .reorder(id: tag.id, afterID: anchor.id)) }
            }
          }
        }
      }
      Menu(.organizationMerge) {
        ForEach(snapshot.tags.tags.filter { $0.id != tag.id }) { other in
          Button(other.displayName) {
            do {
              presentation.merge = try snapshot.prepare(
                tag: .merge(ids: [tag.id, other.id], survivorID: nil, name: tag.name))
            } catch { model.failed = true }
          }
        }
      }
      Button(.organizationDelete, role: .destructive) {
        presentation.deletion = try? snapshot.prepare(tag: .delete(id: tag.id))
      }
    }
  }
}

struct OrganizationActionDialogs: ViewModifier {
  let model: RecipeOrganizationModel?
  @Bindable var presentation: OrganizationActionPresentation
  func body(content: Content) -> some View {
    if let model {
      content
      .sheet(item: $presentation.edits) { OrganizationNameEditor(model: model, edit: $0) }
      .confirmationDialog(
        .organizationDelete, isPresented: Binding(
          get: { presentation.deletion != nil }, set: { if !$0 { presentation.deletion = nil } })
      ) {
        Button(.organizationDelete, role: .destructive) {
          if let deletion = presentation.deletion { model.perform { _ in deletion } }
          presentation.deletion = nil
        }
      } message: { Text(.organizationDeleteMessage) }
      .confirmationDialog(
        .organizationMergeConfirm, isPresented: Binding(
          get: { presentation.merge != nil }, set: { if !$0 { presentation.merge = nil } })
      ) {
        Button(.organizationMerge) {
          if let merge = presentation.merge { model.perform { _ in merge } }
          presentation.merge = nil
        }
        Button(.actionCancel, role: .cancel) { presentation.merge = nil }
      } message: { Text(.organizationMergeMessage) }
      .modifier(OrganizationFailurePresentation(model: model))
    } else { content }
  }
}
