// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import SwiftUI

struct InstructionSectionEditor: View {
  @Binding var section: InstructionSection
  let moveUp: () -> Void; let moveDown: () -> Void; let delete: () -> Void
  var body: some View {
    EditorDisclosureGroup(
      title: section.title ?? "Instruction section",
      accessibilityIdentifier: "instruction-editor-section-\(section.id.rawValue.uuidString)"
    ) {
      EditorTextField("Section name", text: titleBinding, prompt: "Optional")
      ForEach(section.steps.indices, id: \.self) { index in
        InstructionEditor(
            step: $section.steps[index],
            moveUp: { move(index, by: -1) },
            moveDown: { move(index, by: 1) },
            delete: { section.steps.remove(at: index) }
        )
      }
      Button("Add Step", systemImage: "plus") { section.steps.append(InstructionStep(text: "")) }
      HStack {
        Button("Move Up", action: moveUp)
        Button("Move Down", action: moveDown)
        Spacer()
        Button("Delete Section", role: .destructive, action: delete)
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
  var body: some View {
    EditorDisclosureGroup(
      title: step.text.isEmpty ? "New step" : step.text,
      accessibilityIdentifier: "instruction-editor-step-\(step.id.rawValue.uuidString)"
    ) {
      EditorTextField("Step title", text: nameBinding, prompt: "Optional")
      EditorTextField("Instruction", text: $step.text, multiline: true)
      HStack {
        Button("Move Up", action: moveUp)
        Button("Move Down", action: moveDown)
        Spacer()
        Button("Delete", role: .destructive, action: delete)
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
      .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
      .accessibilityHint(isExpanded ? "Collapse" : "Expand")

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
  let label: String
  @Binding var text: String
  let prompt: String?
  let multiline: Bool

  init(
    _ label: String,
    text: Binding<String>,
    prompt: String? = nil,
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
          .labelsHidden()
      }
    } label: {
      EditorFieldLabel(label)
    }
  }

  private var multilineField: some View {
    TextField(label, text: $text, prompt: promptText, axis: .vertical)
      .labelsHidden()
      .lineLimit(2...8)
      .fixedSize(horizontal: false, vertical: true)
  }

  private var promptText: Text? {
    prompt.map { Text($0) }
  }
}

struct EditorFieldLabel: View {
  let text: String

  init(_ text: String) {
    self.text = text
  }

  var body: some View {
    Text(text)
      .font(.subheadline.weight(.semibold))
      .foregroundStyle(Color("AccentColor"))
  }
}
