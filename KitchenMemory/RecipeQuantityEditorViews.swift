// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import SwiftUI

struct IngredientQuantityEditor: View {
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
