// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct RecipeEquipmentEditorView: View {
  @Binding var session: RecipeEditSession
  @Environment(\.locale) private var locale

  var body: some View {
    Section(.recipeDetailEquipmentSection) {
      ForEach(items.indices, id: \.self) { index in
        EquipmentItemEditor(
          item: Binding(get: { items }, set: { items = $0 })[index],
          moveUp: { session.moveEquipment(at: index, by: -1) },
          moveDown: { session.moveEquipment(at: index, by: 1) },
          delete: { items.remove(at: index) },
          isFirst: index == 0, isLast: index == items.count - 1
        )
        .id(items[index].id)
      }
      Button(.recipeEditorEquipmentAdd, systemImage: "plus") {
        items.append(EquipmentItem(originalText: "", name: ""))
      }
      .accessibilityIdentifier("add-equipment")
    }
  }

  private var items: [EquipmentItem] {
    get { session.equipment ?? [] }
    nonmutating set { session.equipment = newValue }
  }
}

private struct EquipmentItemEditor: View {
  @Binding var item: EquipmentItem
  let moveUp: () -> Void
  let moveDown: () -> Void
  let delete: () -> Void
  let isFirst: Bool
  let isLast: Bool
  @Environment(\.locale) private var locale

  var body: some View {
    EditorDisclosureGroup(
      title: item.originalText.isEmpty && item.name.isEmpty
        ? LocalizedStringResource.recipeEditorEquipmentUntitled.localized(for: locale)
        : (item.originalText.isEmpty ? item.name : item.originalText),
      accessibilityIdentifier: "equipment-editor-\(item.id.rawValue.uuidString)"
    ) {
      EditorTextField(.recipeEditorEquipmentWording, text: $item.originalText, multiline: true)
      EditorTextField(.recipeEditorEquipmentName, text: $item.name)
      QuantityExpressionEditor(
        quantity: $item.quantity,
        availableKinds: [.none, .exact, .range, .approximate, .text],
        accessibilityIdentifier: "equipment-quantity-\(item.id.rawValue.uuidString)"
      )
      Toggle(isOn: $item.isOptional) { EditorFieldLabel(.fieldOptionalPrompt) }
      ViewThatFits(in: .horizontal) {
        HStack { actions }
        VStack(alignment: .leading) { actions }
      }
      .buttonStyle(.borderless)
    }
  }

  @ViewBuilder private var actions: some View {
    Button(.actionMoveUp, action: moveUp).disabled(isFirst)
    Button(.actionMoveDown, action: moveDown).disabled(isLast)
    Button(.actionDelete, role: .destructive, action: delete)
  }
}
