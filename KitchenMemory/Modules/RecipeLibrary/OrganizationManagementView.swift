// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct OrganizationManagementButton: View {
  let model: RecipeOrganizationModel
  @State private var presented = false
  var body: some View {
    Button(.organizationManage, systemImage: "ellipsis.circle") { presented = true }
      .accessibilityIdentifier("organization-management")
      .sheet(isPresented: $presented) { OrganizationManagementView(model: model) }
  }
}

struct OrganizationManagementView: View {
  @Bindable var model: RecipeOrganizationModel
  @Environment(\.dismiss) private var dismiss
  @Environment(\.locale) private var locale
  @State private var presentation = OrganizationActionPresentation()

  var body: some View {
    NavigationStack {
      Form {
        if let snapshot = model.snapshot {
          Section(.organizationFolders) {
            Button(.organizationNewFolder) { presentation.edits = .init(folder: nil) }
            ForEach(snapshot.folders.destinations(locale: locale)) { destination in
              Menu(destination.path) {
                OrganizationFolderActions(model: model, folder: destination.folder, presentation: presentation)
              }
            }
          }
          Section(.organizationTags) {
            Button(.organizationNewTag) { presentation.edits = .init(tag: nil) }
            ForEach(snapshot.tags.orderedTags(locale: locale)) { tag in
              Menu(tag.displayName) {
                OrganizationTagActions(model: model, tag: tag, presentation: presentation)
              }
            }
          }
          if model.requiresRecovery { OrganizationCollisionsView(model: model, offersManagement: false) }
        }
      }
      .formStyle(.grouped)
      .navigationTitle(.organizationTitle)
      .accessibilityIdentifier("organization-management-content")
      .accessibilityLabel(Text(.organizationTitle))
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button(.organizationDone) { dismiss() } } }
      .modifier(OrganizationActionDialogs(model: model, presentation: presentation))
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

struct OrganizationNameEditor: View {
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
            ForEach(snapshot.folders.destinations(locale: locale)) { destination in
              Text(destination.path).tag(Optional(destination.id))
            }
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
