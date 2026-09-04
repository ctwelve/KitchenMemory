// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct InstructionSectionEditor: View {
  @Binding var section: InstructionSection
  let moveUp: () -> Void; let moveDown: () -> Void; let delete: () -> Void
  @Environment(\.locale) private var locale
  var body: some View {
    EditorDisclosureGroup(
      title: section.title
        ?? LocalizedStringResource.recipeEditorInstructionSectionFallbackTitle.localized(for: locale),
      accessibilityIdentifier: "instruction-editor-section-\(section.id.rawValue.uuidString)"
    ) {
      EditorTextField(.recipeEditorSectionNameField, text: titleBinding, prompt: .fieldOptionalPrompt)
      ForEach(section.steps.indices, id: \.self) { index in
        InstructionEditor(
            step: $section.steps[index],
            moveUp: { move(index, by: -1) },
            moveDown: { move(index, by: 1) },
            delete: { section.steps.remove(at: index) }
        )
      }
      Button(.recipeEditorInstructionsActionAddStep, systemImage: "plus") {
        section.steps.append(InstructionStep(text: ""))
      }
      HStack {
        Button(.actionMoveUp, action: moveUp)
        Button(.actionMoveDown, action: moveDown)
        Spacer()
        Button(.actionDeleteSection, role: .destructive, action: delete)
      }
    }
  }
  private var titleBinding: Binding<String> {
    Binding(
      get: { section.title ?? "" },
      set: { section.title = $0 }
    )
  }
  private func move(_ index: Int, by offset: Int) {
    let destination = index + offset
    guard section.steps.indices.contains(destination) else { return }
    section.steps.swapAt(index, destination)
  }
}
private struct InstructionEditor: View {
  @Binding var step: InstructionStep
  let moveUp: () -> Void; let moveDown: () -> Void; let delete: () -> Void
  @Environment(\.locale) private var locale
  var body: some View {
    EditorDisclosureGroup(
      title: step.text.isEmpty
        ? LocalizedStringResource.recipeEditorInstructionFallbackTitle.localized(for: locale)
        : step.text,
      accessibilityIdentifier: "instruction-editor-step-\(step.id.rawValue.uuidString)"
    ) {
      EditorTextField(.recipeEditorInstructionTitleField, text: nameBinding, prompt: .fieldOptionalPrompt)
      EditorTextField(.recipeEditorInstructionTextField, text: $step.text, multiline: true)
      HStack {
        Button(.actionMoveUp, action: moveUp)
        Button(.actionMoveDown, action: moveDown)
        Spacer()
        Button(.actionDelete, role: .destructive, action: delete)
      }
    }
  }
  private var nameBinding: Binding<String> {
    Binding(
      get: { step.name ?? "" },
      set: { step.name = $0 }
    )
  }
}

struct EditorDisclosureGroup<Content: View>: View {
  let title: String
  let accessibilityIdentifier: String
  @ViewBuilder let content: Content

  @State private var isExpanded = false

  init(
    title: String,
    accessibilityIdentifier: String,
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.accessibilityIdentifier = accessibilityIdentifier
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Button {
        withAnimation(.easeInOut(duration: 0.15)) {
          isExpanded.toggle()
        }
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "chevron.right")
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
            .foregroundStyle(.secondary)
          Text(title)
            .lineLimit(1)
          Spacer(minLength: 0)
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier(accessibilityIdentifier)
      .accessibilityLabel(title)
      .accessibilityValue(
        Text(isExpanded ? .accessibilityDisclosureExpandedValue : .accessibilityDisclosureCollapsedValue)
      )
      .accessibilityHint(
        Text(isExpanded ? .accessibilityDisclosureCollapseHint : .accessibilityDisclosureExpandHint)
      )

      if isExpanded {
        VStack(alignment: .leading, spacing: 10) {
          content
        }
        .padding(.leading, 20)
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
  }
}

/// An editor field whose purpose remains visible after it contains a value.
///
/// Placeholder-only labels are compact, but become ambiguous as soon as a
/// recipe supplies text. `LabeledContent` gives macOS its traditional
/// label-and-control layout and retains the same semantic pairing elsewhere.
struct EditorTextField: View {
  let label: LocalizedStringResource
  @Binding var text: String
  let prompt: LocalizedStringResource?
  let multiline: Bool

  init(
    _ label: LocalizedStringResource,
    text: Binding<String>,
    prompt: LocalizedStringResource? = nil,
    multiline: Bool = false
  ) {
    self.label = label
    _text = text
    self.prompt = prompt
    self.multiline = multiline
  }

  var body: some View {
#if os(iOS)
    if multiline {
      VStack(alignment: .leading, spacing: 6) {
        EditorFieldLabel(label)
        multilineField
      }
    } else {
      labeledField
    }
#else
    labeledField
#endif
  }

  private var labeledField: some View {
    LabeledContent {
      if multiline {
        multilineField
      } else {
        TextField(label, text: $text, prompt: promptText)
          .textFieldStyle(.roundedBorder)
          .labelsHidden()
      }
    } label: {
      EditorFieldLabel(label)
    }
  }

  private var multilineField: some View {
    TextField(label, text: $text, prompt: promptText, axis: .vertical)
      .textFieldStyle(.roundedBorder)
      .labelsHidden()
      .lineLimit(2...8)
      .fixedSize(horizontal: false, vertical: true)
  }

  private var promptText: Text? {
    prompt.map { Text($0) }
  }
}

struct EditorFieldLabel: View {
  let text: LocalizedStringResource

  init(_ text: LocalizedStringResource) {
    self.text = text
  }

  var body: some View {
    Text(text)
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(Color("AccentColor"))
  }
}
