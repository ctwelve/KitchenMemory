// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Device-local text and identity bookkeeping for simple ingredient editing.
///
/// This read-only snapshot is maintained by `RecipeEditingDraft` operations and native edits
/// through `RecipeIngredientTextEditing`. Interpretation never rewrites the source.
/// The resulting sections and unresolved proposals survive draft recovery; this
/// document is editing state only and is never included in a published Revision.
public struct RecipeIngredientTextDraft: Codable, Equatable, Sendable {
  public struct Line: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public internal(set) var source: String
    public internal(set) var ingredient: RecipeIngredient?
    public internal(set) var sectionID: IngredientSection.ID?
    public internal(set) var sectionTitle: String?
    public var isInterpreted: Bool { source == interpretedSource }
    var retainsEmptyIngredient: Bool?
    var interpretedSource: String
    var conflict: IngredientTextReconciliation.Conflict?

    init(source: String, ingredient: RecipeIngredient? = nil,
         sectionID: IngredientSection.ID? = nil, sectionTitle: String? = nil) {
      id = UUID()
      self.source = source
      self.ingredient = ingredient
      retainsEmptyIngredient = ingredient != nil
      self.sectionID = sectionID
      self.sectionTitle = sectionTitle
      interpretedSource = source
    }
  }

  public private(set) var lines: [Line]
  private let rootSectionID: IngredientSection.ID
  private let retainsRootSection: Bool
  public var text: String { lines.map(\.source).joined(separator: "\n") }
  public var conflicts: [IngredientTextReconciliation.Conflict] { lines.compactMap(\.conflict) }

  /// Optional display wording is used only for existing structured rows without original text.
  /// It does not change maintained content until the user edits that line.
  public init(sections: [IngredientSection], displayWording: [RecipeIngredient.ID: String] = [:]) {
    rootSectionID = sections.first?.title == nil ? (sections.first?.id ?? .init()) : .init()
    retainsRootSection = sections.first?.title == nil && !sections.isEmpty
    lines = []
    for (index, section) in sections.enumerated() {
      if index != 0 || section.title != nil {
        lines.append(Line(source: "# " + (section.title ?? ""), sectionID: section.id, sectionTitle: section.title))
      }
      for ingredient in section.ingredients {
        let wording = ingredient.originalText.isEmpty
          ? (displayWording[ingredient.id] ?? ingredient.ingredientText ?? "") : ingredient.originalText
        lines.append(Line(source: wording, ingredient: ingredient))
      }
    }
    if lines.isEmpty { lines = [Line(source: "")] }
  }

  public var sections: [IngredientSection] {
    var result: [IngredientSection] = []
    var current = IngredientSection(id: rootSectionID, title: nil, ingredients: [])
    for line in lines {
      if let sectionID = line.sectionID {
        if !current.ingredients.isEmpty || current.id != rootSectionID || retainsRootSection {
          result.append(current)
        }
        current = IngredientSection(id: sectionID, title: line.sectionTitle, ingredients: [])
      } else if var ingredient = line.ingredient,
                !line.source.isEmpty || line.retainsEmptyIngredient != false {
        if line.source != line.interpretedSource { ingredient.originalText = line.source }
        current.ingredients.append(ingredient)
      }
    }
    if !current.ingredients.isEmpty || current.id != rootSectionID || retainsRootSection { result.append(current) }
    return result
  }

  /// Applies one native edit, retaining identities only for surviving parts of affected lines.
  /// Inserting complete lines at a row's start keeps that row's identity with its suffix.
  mutating func replaceCharacters(in range: NSRange, with replacement: String) {
    let source = text as NSString
    guard !lines.isEmpty, range.location >= 0, range.length >= 0, NSMaxRange(range) <= source.length else { return }
    var starts: [Int] = []
    var offset = 0
    for line in lines { starts.append(offset); offset += (line.source as NSString).length + 1 }
    var first = 0
    var last = 0
    for (index, start) in starts.enumerated() {
      if start <= range.location { first = index }
      if start <= NSMaxRange(range) { last = index }
    }
    let prefix = (lines[first].source as NSString).substring(to: range.location - starts[first])
    let suffix = (lines[last].source as NSString).substring(from: NSMaxRange(range) - starts[last])
    let fragments = (prefix + replacement + suffix).components(separatedBy: "\n")
    var edited = fragments.map { Line(source: $0) }
    if fragments.count == 1 || !prefix.isEmpty || (first == last && !replacement.contains("\n")) {
      let survivor = prefix.isEmpty && last > first && !suffix.isEmpty ? last : first
      edited[0] = lines[survivor]
      edited[0].source = fragments[0]
    }
    if fragments.count > 1 && !suffix.isEmpty && (last != first || prefix.isEmpty) {
      edited[edited.count - 1] = lines[last]
      edited[edited.count - 1].source = fragments[fragments.count - 1]
    }
    for index in edited.indices where edited[index].ingredient == nil && edited[index].sectionID == nil {
      // Allocate once, so repeated persistence while typing never changes identity.
      edited[index].ingredient = RecipeIngredient(originalText: "", presentationMode: .original)
      edited[index].interpretedSource = ""
    }
    lines.replaceSubrange(first...last, with: edited)
  }

  /// Call on completed lines, paste, blur, and before switching modes or publishing.
  /// An active line may be excluded while its authored text is already retained in `sections`.
  mutating func finishEditing(locale: Locale = .current, excludingLineAtUTF16Offset activeOffset: Int? = nil) {
    var offset = 0
    for index in lines.indices {
      let length = (lines[index].source as NSString).length
      defer { offset += length + 1 }
      if let activeOffset, (offset...offset + length).contains(activeOffset) { continue }
      guard lines[index].source != lines[index].interpretedSource else { continue }
      interpretLine(at: index, locale: locale)
    }
  }

  private mutating func interpretLine(at index: Int, locale: Locale) {
    var line = lines[index]
    if line.source.hasPrefix("# ") {
      let title = String(line.source.dropFirst(2))
      if !title.trimmingCharacters(in: .whitespaces).isEmpty || line.sectionID != nil {
        line.sectionID = line.sectionID ?? .init()
        line.sectionTitle = title.isEmpty ? nil : title
        line.interpretedSource = line.source
        line.conflict = nil
        lines[index] = line
        return
      }
    }
    line.sectionID = nil
    line.sectionTitle = nil
    let existing = line.ingredient.map { [$0] } ?? []
    let result = IngredientTextReconciliation.reconcile(
      lines: [.init(ingredientID: line.ingredient?.id, source: line.source)],
      with: IngredientSection(title: nil, ingredients: existing), locale: locale)
    line.ingredient = result.section.ingredients.first
    line.conflict = result.conflicts.first
    line.interpretedSource = line.source
    lines[index] = line
  }

  /// Rebuild after structured editing while retaining proposals for untouched ingredients.
  func incorporating(_ sections: [IngredientSection],
                     displayWording: [RecipeIngredient.ID: String] = [:]) -> Self {
    let current = self.sections
    let currentIngredients = Dictionary(uniqueKeysWithValues: current.flatMap(\.ingredients).map { ($0.id, $0) })
    let sameStructure = current.count == sections.count && zip(current, sections).allSatisfy {
      $0.id == $1.id && $0.title == $1.title && $0.ingredients.map(\.id) == $1.ingredients.map(\.id)
    }
    if sameStructure {
      var updated = self
      let ingredients = Dictionary(uniqueKeysWithValues: sections.flatMap(\.ingredients).map { ($0.id, $0) })
      for index in updated.lines.indices {
        guard let previous = updated.lines[index].ingredient, let value = ingredients[previous.id],
              currentIngredients[previous.id] != value else { continue }
        updated.lines[index].incorporate(value)
      }
      return updated
    }
    var ingredientLines: [RecipeIngredient.ID: Line] = [:]
    var sectionLines: [IngredientSection.ID: Line] = [:]
    // Reverse insertion retains the first matching line, as the original linear lookup did.
    for line in lines.reversed() {
      if let sectionID = line.sectionID {
        sectionLines[sectionID] = line
      } else if let ingredient = line.ingredient {
        ingredientLines[ingredient.id] = line
      }
    }
    var updated = Self(sections: sections, displayWording: displayWording)
    for index in updated.lines.indices {
      let replacement = updated.lines[index]
      if let ingredient = replacement.ingredient,
         var previous = ingredientLines[ingredient.id] {
        if currentIngredients[ingredient.id] != ingredient { previous.incorporate(ingredient) }
        updated.lines[index] = previous
      } else if let sectionID = replacement.sectionID,
                var previous = sectionLines[sectionID] {
        previous.source = replacement.source
        previous.interpretedSource = replacement.source
        previous.sectionTitle = replacement.sectionTitle
        updated.lines[index] = previous
      }
    }
    return updated
  }

  /// Explicitly accept the parser proposal or retain all precise fields for an edited line.
  mutating func resolve(_ id: RecipeIngredient.ID, acceptingInterpretation: Bool) {
    guard let index = lines.firstIndex(where: { $0.ingredient?.id == id }),
          let proposal = lines[index].conflict else { return }
    if acceptingInterpretation { lines[index].ingredient = proposal.proposed }
    lines[index].conflict = nil
  }
}

private extension RecipeIngredientTextDraft.Line {
  mutating func incorporate(_ value: RecipeIngredient) {
    if value != ingredient { conflict = nil }
    if value.originalText != ingredient?.originalText {
      source = value.originalText
      interpretedSource = value.originalText
    }
    ingredient = value
  }
}
