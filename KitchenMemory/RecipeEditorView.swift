// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryApplication
import SwiftUI

struct RecipeEditorView: View {
  enum Mode {
    case create
    case revise

    var title: String { self == .create ? "New Recipe" : "Edit Recipe" }
    var saveLabel: String { self == .create ? "Create Recipe" : "Save Revision" }
  }

  let mode: Mode
  let initialDraft: RecipeDraft
  let save: (RecipeDraft) -> Bool

  @Environment(\.dismiss) private var dismiss
  @State private var title: String
  @State private var summary: String
  @State private var ingredientText: String
  @State private var instructionText: String

  init(mode: Mode, draft: RecipeDraft = RecipeDraft(), save: @escaping (RecipeDraft) -> Bool) {
    self.mode = mode
    initialDraft = draft
    self.save = save
    _title = State(initialValue: draft.title)
    _summary = State(initialValue: draft.summary ?? "")
    _ingredientText = State(initialValue: draft.ingredientLines.joined(separator: "\n"))
    _instructionText = State(initialValue: draft.instructionLines.joined(separator: "\n"))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Recipe") {
          TextField("Title", text: $title)
            .accessibilityIdentifier("recipe-editor-title")
          TextField("Summary", text: $summary, axis: .vertical)
            .lineLimit(2...4)
            .accessibilityIdentifier("recipe-editor-summary")
        }

        Section("Ingredients") {
          TextEditor(text: $ingredientText)
            .frame(minHeight: 130)
            .accessibilityLabel("Ingredients, one per line")
            .accessibilityIdentifier("recipe-editor-ingredients")
          Text("One ingredient per line. Kitchen Memory keeps the wording you enter.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }

        Section("Instructions") {
          TextEditor(text: $instructionText)
            .frame(minHeight: 160)
            .accessibilityLabel("Instructions, one step per line")
            .accessibilityIdentifier("recipe-editor-instructions")
          Text("One step per line.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .navigationTitle(mode.title)
#if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
#endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(mode.saveLabel) {
            if save(draft) { dismiss() }
          }
          .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          .accessibilityIdentifier("recipe-editor-save")
        }
      }
    }
  }

  private var draft: RecipeDraft {
    RecipeDraft(
      title: title,
      summary: summary,
      ingredientLines: lines(in: ingredientText),
      instructionLines: lines(in: instructionText)
    )
  }

  private func lines(in text: String) -> [String] {
    text.components(separatedBy: .newlines)
  }
}
