// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct OrganizationManagementButton: View {
  let model: RecipeOrganizationModel
  @State private var presented = false
  var body: some View {
    Button(.organizationManage, systemImage: "folder.badge.gearshape") { presented = true }
      .accessibilityIdentifier("organization-management")
      .sheet(isPresented: $presented) { OrganizationManagementView(model: model) }
  }
}

struct OrganizationManagementView: View {
  @Bindable var model: RecipeOrganizationModel
  @Environment(\.dismiss) private var dismiss
  @Environment(\.locale) private var locale
  @State private var edits: OrganizationNameEdit?
  @State private var merge: RecipeOrganizationCommand?
  @State private var deletion: RecipeOrganizationCommand?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Toggle(.organizationShowFolders, isOn: $model.foldersEnabled)
          Toggle(.organizationShowTags, isOn: $model.tagsEnabled)
        }
        if let snapshot = model.snapshot {
          Section {
            Picker(.organizationOrdering, selection: Binding(get: { snapshot.folders.ordering }, set: { mode in
              model.perform { try $0.prepare(folder: .ordering(mode)) }
            })) {
              Text(.organizationAlphabetical).tag(FolderOrdering.alphabetical)
              Text(.organizationManual).tag(FolderOrdering.manual)
            }
            Toggle(.organizationShowUnfiled, isOn: Binding(get: { model.showsUnfiled }, set: { visible in
              model.perform { try $0.prepare(folder: .systemViewVisible(visible)) }
            }))
            Button(.organizationNewFolder) { edits = .init(folder: nil) }
            ForEach(snapshot.folders.destinations(locale: locale)) { destination in
              let folder = destination.folder
              HStack {
                Text(destination.path)
                Spacer()
                Menu(.organizationManage) {
                  Button(.organizationRename) { edits = .init(folder: folder) }
                  Menu(.organizationParent) {
                    Button(.organizationRoot) { model.perform { try $0.prepare(folder: .move(id: folder.id, parentID: nil)) } }
                    ForEach(snapshot.folders.destinations(locale: locale).filter { !snapshot.folders.subtree(of: folder.id).contains($0.id) }) { parent in
                      Button(parent.path) { model.perform { try $0.prepare(folder: .move(id: folder.id, parentID: parent.id)) } }
                    }
                  }
                  if snapshot.folders.ordering == .manual {
                    Button(.organizationFirst) { model.perform { try $0.prepare(folder: .reorder(id: folder.id, afterID: nil)) } }
                    Menu(.organizationAfter) {
                      ForEach(snapshot.folders.children(of: folder.parentID, locale: locale).filter { $0.id != folder.id }) { anchor in
                        Button(anchor.name) { model.perform { try $0.prepare(folder: .reorder(id: folder.id, afterID: anchor.id)) } }
                      }
                    }
                  }
                  Menu(.organizationMerge) {
                    ForEach(snapshot.folders.folders.filter { $0.id != folder.id && $0.parentID == folder.parentID }) { other in
                      Button(other.name) {
                        do { merge = try snapshot.prepare(folder: .merge(ids: [folder.id, other.id], survivorID: nil, name: folder.name)) }
                        catch { model.failed = true }
                      }
                    }
                  }
                  Button(.organizationDelete, role: .destructive) {
                    deletion = try? snapshot.prepare(folder: .delete(id: folder.id))
                  }
                }
                .accessibilityLabel(Text(folder.name))
              }
            }
          } header: { Text(.organizationFolders) }
          Section {
            Picker(.organizationOrdering, selection: Binding(get: { snapshot.tags.ordering }, set: { mode in
              model.perform { try $0.prepare(tag: .ordering(mode)) }
            })) {
              Text(.organizationAlphabetical).tag(TagOrdering.alphabetical)
              Text(.organizationManual).tag(TagOrdering.manual)
            }
            Toggle(.organizationShowUntagged, isOn: Binding(get: { model.showsUntagged }, set: { visible in
              model.perform { try $0.prepare(tag: .systemViewVisible(visible)) }
            }))
            Button(.organizationNewTag) { edits = .init(tag: nil) }
            ForEach(snapshot.tags.orderedTags(locale: locale)) { tag in
              HStack {
                Text(tag.displayName)
                Spacer()
                Menu(.organizationManage) {
                  Button(.organizationRename) { edits = .init(tag: tag) }
                  if snapshot.tags.ordering == .manual {
                    Button(.organizationFirst) { model.perform { try $0.prepare(tag: .reorder(id: tag.id, afterID: nil)) } }
                    Menu(.organizationAfter) {
                      ForEach(snapshot.tags.orderedTags(locale: locale).filter { $0.id != tag.id }) { anchor in
                        Button(anchor.displayName) { model.perform { try $0.prepare(tag: .reorder(id: tag.id, afterID: anchor.id)) } }
                      }
                    }
                  }
                  Menu(.organizationMerge) {
                    ForEach(snapshot.tags.tags.filter { $0.id != tag.id }) { other in
                      Button(other.displayName) {
                        do { merge = try snapshot.prepare(tag: .merge(ids: [tag.id, other.id], survivorID: nil, name: tag.name)) }
                        catch { model.failed = true }
                      }
                    }
                  }
                  Button(.organizationDelete, role: .destructive) { deletion = try? snapshot.prepare(tag: .delete(id: tag.id)) }
                }
                .accessibilityLabel(Text(tag.displayName))
              }
            }
          } header: { Text(.organizationTags) }
          if model.requiresRecovery { OrganizationCollisionsView(model: model, offersManagement: false) }
        }
      }
      .formStyle(.grouped)
      .navigationTitle(.organizationTitle)
      .accessibilityIdentifier("organization-management-content")
      .accessibilityLabel(Text(.organizationTitle))
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button(.organizationDone) { dismiss() } } }
      .sheet(item: $edits) { OrganizationNameEditor(model: model, edit: $0) }
      .confirmationDialog(.organizationDelete, isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } })) {
        Button(.organizationDelete, role: .destructive) {
          if let deletion { model.perform { _ in deletion } }
          deletion = nil
        }
      } message: { Text(.organizationDeleteMessage) }
      .confirmationDialog(.organizationMergeConfirm, isPresented: Binding(get: { merge != nil }, set: { if !$0 { merge = nil } })) {
        Button(.organizationMerge) { if let merge { model.perform { _ in merge } }; merge = nil }
        Button(.actionCancel, role: .cancel) { merge = nil }
      } message: { Text(.organizationMergeMessage) }
      .modifier(OrganizationFailurePresentation(model: model))
    }
#if os(macOS)
    .frame(minWidth: 480, minHeight: 480)
#endif
  }
}

struct OrganizationNameEdit: Identifiable {
  enum Target { case folder(Folder?), tag(Tag?) }
  let id = UUID()
  let target: Target
  var isFolder: Bool { if case .folder = target { return true }; return false }
  var folder: Folder? { if case let .folder(value) = target { return value }; return nil }
  var tag: Tag? { if case let .tag(value) = target { return value }; return nil }
  init(folder: Folder?) { target = .folder(folder) }
  init(tag: Tag?) { target = .tag(tag) }
}

private struct OrganizationNameEditor: View {
  @Bindable var model: RecipeOrganizationModel
  let edit: OrganizationNameEdit
  @Environment(\.dismiss) private var dismiss
  @Environment(\.locale) private var locale
  @State private var name = ""
  @State private var parentID: Folder.ID?
  var body: some View {
    NavigationStack {
      Form {
        TextField(.organizationName, text: $name)
        if edit.isFolder, edit.folder == nil, let snapshot = model.snapshot {
          Picker(.organizationParent, selection: $parentID) {
            Text(.organizationRoot).tag(Folder.ID?.none)
            ForEach(snapshot.folders.destinations(locale: locale)) { destination in Text(destination.path).tag(Optional(destination.id)) }
          }
        }
      }
      .padding()
      .navigationTitle(edit.isFolder ? .organizationFolders : .organizationTags)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button(.actionCancel) { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(.organizationApply) {
            model.perform { snapshot in
              if edit.isFolder {
                return try snapshot.prepare(folder: edit.folder.map { .rename(id: $0.id, name: name) }
                  ?? .create(id: Folder.ID(), name: name, parentID: parentID))
              }
              return try snapshot.prepare(tag: edit.tag.map { .rename(id: $0.id, name: name) }
                ?? .create(id: Tag.ID(), name: name))
            }
            if !model.failed { dismiss() }
          }
          .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
      .onAppear { name = edit.folder?.name ?? edit.tag?.name ?? "" }
      .modifier(OrganizationFailurePresentation(model: model))
    }
  }
}

struct OrganizationFailurePresentation: ViewModifier {
  @Bindable var model: RecipeOrganizationModel
  func body(content: Content) -> some View {
    content.alert(.organizationFailed, isPresented: $model.failed) {
      Button(.actionCancel, role: .cancel) {}
    } message: { Text(.organizationFailureMessage) }
  }
}
