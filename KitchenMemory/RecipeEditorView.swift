// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryApplication
import KitchenMemoryDomain
import SwiftUI

struct RecipeEditorView: View {
  enum Mode {
    case create
    case revise

    var title: String { self == .create ? "New Recipe" : "Edit Recipe" }
    var saveLabel: String { self == .create ? "Create Recipe" : "Save Revision" }
  }

  let mode: Mode
  let save: (RecipeDraft) -> Bool

  @Environment(\.dismiss) private var dismiss
  @State private var title: String
  @State private var summary: String
  @State private var authorName: String
  @State private var yieldText: String
  @State private var prepMinutes: String
  @State private var cookMinutes: String
  @State private var totalMinutes: String
  @State private var sourceKind: RecipeSource.Kind
  @State private var sourceTitle: String
  @State private var sourceAuthor: String
  @State private var sourcePublisher: String
  @State private var sourceURL: String
  @State private var ingredientSections: [IngredientSection]
  @State private var instructionSections: [InstructionSection]

  init(mode: Mode, draft: RecipeDraft = RecipeDraft(), save: @escaping (RecipeDraft) -> Bool) {
    self.mode = mode
    self.save = save
    _title = State(initialValue: draft.title)
    _summary = State(initialValue: draft.summary ?? "")
    _authorName = State(initialValue: draft.authorName ?? "")
    _yieldText = State(initialValue: draft.recipeYield?.originalText ?? "")
    _prepMinutes = State(initialValue: Self.minutes(draft.prepDuration))
    _cookMinutes = State(initialValue: Self.minutes(draft.cookDuration))
    _totalMinutes = State(initialValue: Self.minutes(draft.totalDuration))
    _sourceKind = State(initialValue: draft.source?.kind ?? .original)
    _sourceTitle = State(initialValue: draft.source?.title ?? "")
    _sourceAuthor = State(initialValue: draft.source?.authorName ?? "")
    _sourcePublisher = State(initialValue: draft.source?.publisherName ?? "")
    _sourceURL = State(initialValue: draft.source?.canonicalURL?.absoluteString ?? "")
    _ingredientSections = State(initialValue: draft.ingredientSections)
    _instructionSections = State(initialValue: draft.instructionSections)
  }

  var body: some View {
    NavigationStack {
      Group {
#if os(macOS)
        // Form adopts its content's ideal height in a macOS sheet, so bounding
        // the sheet alone can clip the content without creating a scrollable
        // viewport. List owns its scroll view and still provides native Section
        // presentation and form controls.
        List {
          editorSections
        }
        .listStyle(.inset)
        .accessibilityIdentifier("recipe-editor-scroll")
#else
        Form {
          editorSections
        }
        .accessibilityIdentifier("recipe-editor-scroll")
#endif
      }
      .navigationTitle(mode.title)
#if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
#endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(mode.saveLabel) { if save(draft) { dismiss() } }
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("recipe-editor-save")
        }
      }
#if os(macOS)
      .frame(
        minWidth: 680,
        idealWidth: 760,
        maxWidth: 900,
        minHeight: 520,
        idealHeight: 680,
        maxHeight: 760
      )
#endif
    }
  }

  @ViewBuilder
  private var editorSections: some View {
    recipeSection
    timingSection
    sourceSection
    ingredientsSection
    instructionsSection
  }

  private var recipeSection: some View {
    Section("Recipe") {
      EditorTextField("Title", text: $title)
        .accessibilityIdentifier("recipe-editor-title")
      EditorTextField("Summary", text: $summary, multiline: true)
        .accessibilityIdentifier("recipe-editor-summary")
      EditorTextField("Recipe author", text: $authorName)
      EditorTextField("Yield", text: $yieldText, prompt: "e.g. Serves 4")
    }
  }

  private var timingSection: some View {
    Section("Times") {
      EditorTextField("Prep minutes", text: $prepMinutes)
      EditorTextField("Cook minutes", text: $cookMinutes)
      EditorTextField("Total minutes", text: $totalMinutes)
    }
  }

  private var sourceSection: some View {
    Section("Source") {
      Picker(selection: $sourceKind) {
        ForEach(RecipeSource.Kind.allCases, id: \.self) { Text($0.label).tag($0) }
      } label: {
        EditorFieldLabel("Source type")
      }
      EditorTextField("Source title", text: $sourceTitle)
      EditorTextField("Source author", text: $sourceAuthor)
      EditorTextField("Publisher", text: $sourcePublisher)
      EditorTextField("Source URL", text: $sourceURL)
    }
  }

  private var ingredientsSection: some View {
    Section {
      ForEach(ingredientSections.indices, id: \.self) { sectionIndex in
        IngredientSectionEditor(
          section: $ingredientSections[sectionIndex],
          moveUp: { moveIngredientSection(sectionIndex, by: -1) },
          moveDown: { moveIngredientSection(sectionIndex, by: 1) },
          delete: { ingredientSections.remove(at: sectionIndex) }
        )
        .id("ingredient-section-\(ingredientSections[sectionIndex].id.rawValue.uuidString)")
      }
      Button("Add Ingredient Section", systemImage: "plus") {
        ingredientSections.append(IngredientSection(title: nil, ingredients: []))
      }
      .accessibilityIdentifier("add-ingredient-section")
    } header: { Text("Ingredients") } footer: {
      Text("Original wording is retained separately from the structured interpretation.")
    }
  }

  private var instructionsSection: some View {
    Section {
      ForEach(instructionSections.indices, id: \.self) { sectionIndex in
        InstructionSectionEditor(
          section: $instructionSections[sectionIndex],
          moveUp: { moveInstructionSection(sectionIndex, by: -1) },
          moveDown: { moveInstructionSection(sectionIndex, by: 1) },
          delete: { instructionSections.remove(at: sectionIndex) }
        )
        .id("instruction-section-\(instructionSections[sectionIndex].id.rawValue.uuidString)")
      }
      Button("Add Instruction Section", systemImage: "plus") {
        instructionSections.append(InstructionSection(title: nil, steps: []))
      }
      .accessibilityIdentifier("add-instruction-section")
    } header: { Text("Instructions") }
  }

  private var draft: RecipeDraft {
    RecipeDraft(
      title: title, summary: summary, authorName: authorName, source: source,
      recipeYield: text(yieldText).map { RecipeYield(originalText: $0) },
      prepDuration: duration(prepMinutes), cookDuration: duration(cookMinutes), totalDuration: duration(totalMinutes),
      ingredientSections: ingredientSections, instructionSections: instructionSections
    )
  }

  private var source: RecipeSource? {
    guard (
      text(sourceTitle) != nil ||
        text(sourceAuthor) != nil ||
        text(sourcePublisher) != nil ||
        URL(string: sourceURL) != nil
    ) else { return nil }
    return RecipeSource(
        kind: sourceKind,
        title: text(sourceTitle),
        authorName: text(sourceAuthor),
        publisherName: text(sourcePublisher),
        canonicalURL: URL(string: sourceURL)
    )
  }

  private func moveIngredientSection(_ index: Int, by offset: Int) {
    let destination = index + offset
    guard ingredientSections.indices.contains(destination) else { return }
    ingredientSections.swapAt(index, destination)
  }
  private func moveInstructionSection(_ index: Int, by offset: Int) {
    let destination = index + offset
    guard instructionSections.indices.contains(destination) else { return }
    instructionSections.swapAt(index, destination)
  }
  private func text(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
  private func duration(_ minutes: String) -> RecipeDuration? {
    guard let value = Int(minutes), value >= 0 else { return nil }
    return RecipeDuration(seconds: value * 60)
  }
  private static func minutes(_ duration: RecipeDuration?) -> String {
    duration.map { String($0.seconds / 60) } ?? ""
  }
}

private struct IngredientSectionEditor: View {
  @Binding var section: IngredientSection
  let moveUp: () -> Void
  let moveDown: () -> Void
  let delete: () -> Void

  var body: some View {
    EditorDisclosureGroup(
      title: section.title ?? "Ingredient section",
      accessibilityIdentifier: "ingredient-editor-section-\(section.id.rawValue.uuidString)"
    ) {
      EditorTextField("Section name", text: titleBinding, prompt: "Optional")
      ForEach(section.ingredients.indices, id: \.self) { index in
        IngredientEditor(
            ingredient: $section.ingredients[index],
            moveUp: { move(index, by: -1) },
            moveDown: { move(index, by: 1) },
            delete: { section.ingredients.remove(at: index) }
        )
      }
      Button("Add Ingredient", systemImage: "plus") {
        section.ingredients.append(RecipeIngredient(parseState: .edited))
      }
        .accessibilityIdentifier("add-ingredient-\(section.id.rawValue.uuidString)")
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
    guard section.ingredients.indices.contains(destination) else { return }
    section.ingredients.swapAt(index, destination)
  }
}

private struct IngredientEditor: View {
  @Binding var ingredient: RecipeIngredient
  let moveUp: () -> Void
  let moveDown: () -> Void
  let delete: () -> Void
  var body: some View {
    EditorDisclosureGroup(
      title: ingredient.effectiveDisplayText == "Ingredient"
        ? "New ingredient"
        : ingredient.effectiveDisplayText,
      accessibilityIdentifier: "ingredient-editor-row-\(ingredient.id.rawValue.uuidString)"
    ) {
      LabeledContent {
        Text(ingredient.originalText.isEmpty ? "Not available" : ingredient.originalText)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      } label: {
        EditorFieldLabel("Original wording")
      }
      Picker(selection: $ingredient.presentationMode) {
        ForEach(RecipeIngredient.PresentationMode.allCases, id: \.self) {
          Text($0.label).tag($0)
        }
      } label: {
        EditorFieldLabel("Presentation")
      }
      if ingredient.presentationMode == .custom {
        EditorTextField("Custom text", text: optionalBinding(\.customDisplayText))
      }
      EditorTextField("Ingredient name", text: optionalBinding(\.ingredientText))
      IngredientQuantityEditor(quantity: $ingredient.quantity, package: $ingredient.package)
      EditorTextField("Unit", text: optionalBinding(\.unitText))
      EditorTextField("Preparation", text: optionalBinding(\.preparation))
      EditorTextField("Note", text: optionalBinding(\.note))
      Toggle(isOn: $ingredient.isOptional) {
        EditorFieldLabel("Optional")
      }
      Picker(selection: $ingredient.scalingBehavior) {
        ForEach(RecipeIngredient.ScalingBehavior.allCases, id: \.self) { Text($0.label).tag($0) }
      } label: {
        EditorFieldLabel("Scaling")
      }
        HStack {
            Button("Move Up", action: moveUp)
            Button("Move Down", action: moveDown)
            Spacer()
            Button("Delete", role: .destructive, action: delete)
        }
    }
  }
  private func optionalBinding(_ keyPath: WritableKeyPath<RecipeIngredient, String?>) -> Binding<String> {
    Binding(
      get: { ingredient[keyPath: keyPath] ?? "" },
      set: { ingredient[keyPath: keyPath] = $0 }
    )
  }
}

private struct IngredientQuantityEditor: View {
  @Binding var quantity: QuantityExpression?
  @Binding var package: PackageDescription?
  @State private var showsPreciseEntry: Bool

  init(
    quantity: Binding<QuantityExpression?>,
    package: Binding<PackageDescription?>
  ) {
    _quantity = quantity
    _package = package
    _showsPreciseEntry = State(
      initialValue: quantity.wrappedValue.map { $0.kind != .text } ?? false
    )
  }

  var body: some View {
    if showsPreciseEntry {
      preciseEntry
    } else if hasPreciseQuantity || package != nil {
      preciseSummary
    } else {
      simpleEntry
    }
  }

  private var simpleEntry: some View {
    VStack(alignment: .leading, spacing: 8) {
      EditorTextField(
        "Amount",
        text: simpleAmountBinding,
        prompt: "Optional — 2, 1/2, to taste…"
      )
      Button("Use precise quantity…", systemImage: "slider.horizontal.3") {
        showsPreciseEntry = true
      }
      .accessibilityIdentifier("show-precise-quantity")
    }
  }

  private var preciseSummary: some View {
    VStack(alignment: .leading, spacing: 8) {
      LabeledContent {
        Text(summary)
          .foregroundStyle(.secondary)
      } label: {
        EditorFieldLabel("Amount")
      }
      Button("Edit precise quantity…", systemImage: "slider.horizontal.3") {
        showsPreciseEntry = true
      }
      .accessibilityIdentifier("show-precise-quantity")
    }
  }

  private var preciseEntry: some View {
    VStack(alignment: .leading, spacing: 12) {
      QuantityExpressionEditor(quantity: $quantity, allowsNone: true)

      if package == nil {
        Button("Add package size", systemImage: "shippingbox") {
          package = PackageDescription(
            quantity: QuantityExpression(
              kind: .exact,
              lowerBound: RationalQuantity(numerator: 1)
            ),
            unitText: ""
          )
        }
      } else {
        GroupBox("Package size (optional)") {
          VStack(alignment: .leading, spacing: 10) {
            QuantityExpressionEditor(
              quantity: packageQuantityBinding,
              allowsNone: false
            )
            EditorTextField(
              "Package unit",
              text: packageUnitBinding,
              prompt: "ounces, grams, milliliters…"
            )
            Button("Remove package size", role: .destructive) {
              package = nil
            }
          }
        }
      }

      Button("Done with quantity details") {
        showsPreciseEntry = false
      }
    }
    .accessibilityIdentifier("precise-quantity-editor")
  }

  private var hasPreciseQuantity: Bool {
    quantity.map { $0.kind != .text } ?? false
  }

  private var summary: String {
    var parts: [String] = []
    if let quantityText = quantity?.renderedText {
      parts.append(quantityText)
    }
    if let package {
      let packageText = [package.quantity.renderedText, package.unitText]
        .compactMap { value in
          guard let value, !value.isEmpty else { return nil }
          return value
        }
        .joined(separator: " ")
      if !packageText.isEmpty {
        parts.append("package: \(packageText)")
      }
    }
    return parts.isEmpty ? "Not specified" : parts.joined(separator: ", ")
  }

  private var simpleAmountBinding: Binding<String> {
    Binding(
      get: {
        guard quantity?.kind == .text else { return "" }
        return quantity?.text ?? ""
      },
      set: { newValue in
        quantity = newValue.isEmpty
          ? nil
          : QuantityExpression(kind: .text, text: newValue)
      }
    )
  }

  private var packageQuantityBinding: Binding<QuantityExpression?> {
    Binding(
      get: { package?.quantity },
      set: { newValue in
        guard let newValue else { return }
        package?.quantity = newValue
      }
    )
  }

  private var packageUnitBinding: Binding<String> {
    Binding(
      get: { package?.unitText ?? "" },
      set: { package?.unitText = $0 }
    )
  }
}

private struct QuantityExpressionEditor: View {
  @Binding var quantity: QuantityExpression?
  let allowsNone: Bool

  var body: some View {
    Picker(selection: kindBinding) {
      ForEach(availableKinds, id: \.self) { kind in
        Text(kind.label).tag(kind)
      }
    } label: {
      EditorFieldLabel("Quantity type")
    }

    switch quantity?.kind ?? .none {
    case .none:
      Text("No quantity specified")
        .foregroundStyle(.secondary)
    case .exact:
      RationalQuantityEditor("Quantity", quantity: lowerBoundBinding)
    case .range:
      RationalQuantityEditor("From", quantity: lowerBoundBinding)
      RationalQuantityEditor("Through", quantity: upperBoundBinding)
    case .approximate:
      RationalQuantityEditor("About", quantity: lowerBoundBinding)
    case .text:
      EditorTextField(
        "Amount",
        text: textBinding,
        prompt: "to taste, as needed, a handful…"
      )
    }
  }

  private var availableKinds: [QuantityExpression.Kind] {
    allowsNone
      ? [.none, .exact, .range, .approximate, .text]
      : [.exact, .range, .approximate, .text]
  }

  private var kindBinding: Binding<QuantityExpression.Kind> {
    Binding(
      get: { quantity?.kind ?? .none },
      set: { newKind in
        let previousText = quantity?.text
        switch newKind {
        case .none:
          if allowsNone { quantity = nil }
        case .exact:
          quantity = QuantityExpression(
            kind: .exact,
            lowerBound: quantity?.lowerBound ?? RationalQuantity(numerator: 1),
            text: previousText
          )
        case .range:
          quantity = QuantityExpression(
            kind: .range,
            lowerBound: quantity?.lowerBound ?? RationalQuantity(numerator: 1),
            upperBound: quantity?.upperBound ?? RationalQuantity(numerator: 2),
            text: previousText
          )
        case .approximate:
          quantity = QuantityExpression(
            kind: .approximate,
            lowerBound: quantity?.lowerBound ?? RationalQuantity(numerator: 1),
            text: previousText
          )
        case .text:
          quantity = QuantityExpression(kind: .text, text: previousText ?? "")
        }
      }
    )
  }

  private var lowerBoundBinding: Binding<RationalQuantity> {
    rationalBinding(\.lowerBound)
  }

  private var upperBoundBinding: Binding<RationalQuantity> {
    rationalBinding(\.upperBound)
  }

  private var textBinding: Binding<String> {
    Binding(
      get: { quantity?.text ?? "" },
      set: { quantity?.text = $0 }
    )
  }

  private func rationalBinding(
    _ keyPath: WritableKeyPath<QuantityExpression, RationalQuantity?>
  ) -> Binding<RationalQuantity> {
    Binding(
      get: { quantity?[keyPath: keyPath] ?? RationalQuantity(numerator: 1) },
      set: { quantity?[keyPath: keyPath] = $0 }
    )
  }
}

private struct RationalQuantityEditor: View {
  let label: String
  @Binding var quantity: RationalQuantity

  init(_ label: String, quantity: Binding<RationalQuantity>) {
    self.label = label
    _quantity = quantity
  }

  var body: some View {
    LabeledContent {
      HStack(spacing: 6) {
        TextField("Numerator", value: numeratorBinding, format: .number)
          .labelsHidden()
          .frame(maxWidth: 90)
        Text("/")
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
        TextField("Denominator", value: denominatorBinding, format: .number)
          .labelsHidden()
          .frame(maxWidth: 90)
      }
      .accessibilityElement(children: .contain)
      .accessibilityLabel(label)
    } label: {
      EditorFieldLabel(label)
    }
  }

  private var numeratorBinding: Binding<Int> {
    Binding(
      get: { quantity.numerator },
      set: { quantity.numerator = max(0, $0) }
    )
  }

  private var denominatorBinding: Binding<Int> {
    Binding(
      get: { quantity.denominator },
      set: { quantity.denominator = max(1, $0) }
    )
  }
}

private struct InstructionSectionEditor: View {
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

private struct EditorDisclosureGroup<Content: View>: View {
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
private struct EditorTextField: View {
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
    LabeledContent {
      if multiline {
        TextField(label, text: $text, prompt: promptText, axis: .vertical)
          .labelsHidden()
          .lineLimit(2...5)
      } else {
        TextField(label, text: $text, prompt: promptText)
          .labelsHidden()
      }
    } label: {
      EditorFieldLabel(label)
    }
  }

  private var promptText: Text? {
    prompt.map { Text($0) }
  }
}

private struct EditorFieldLabel: View {
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

private extension RecipeSource.Kind {
  static var allCases: [Self] { [.original, .webpage, .book, .person, .imported] }
  var label: String { rawValue.capitalized }
}
private extension RecipeIngredient.ScalingBehavior {
  static var allCases: [Self] { [.linear, .fixed, .manualReview] }
  var label: String { self == .manualReview ? "Manual review" : rawValue.capitalized }
}
private extension RecipeIngredient.PresentationMode {
  var label: String { rawValue.capitalized }
}
private extension QuantityExpression.Kind {
  var label: String {
    switch self {
    case .none: "None"
    case .exact: "Exact"
    case .range: "Range"
    case .approximate: "Approximate"
    case .text: "Words"
    }
  }
}
