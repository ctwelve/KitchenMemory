// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: GPL-3.0-only

import KitchenMemoryDomain
import SwiftUI

struct IngredientQuantityEditor: View {
  @Binding var quantity: QuantityExpression?
  @Binding var package: PackageDescription?
  @State private var showsPreciseEntry: Bool
  @Environment(\.locale) private var locale

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
      QuantityExpressionEditor(
        quantity: $quantity,
        availableKinds: [.none, .exact, .range, .approximate, .text],
        accessibilityIdentifier: nil
      )

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
              availableKinds: [.exact, .range, .approximate, .text],
              accessibilityIdentifier: nil
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
    let formatter = RecipePresentationFormatter(locale: locale)
    var parts: [String] = []
    if let quantityText = formatter.quantity(quantity) {
      parts.append(quantityText)
    }
    if let package {
      let packageText = [formatter.quantity(package.quantity), package.unitText]
        .compactMap { value in
          guard let value, !value.isEmpty else { return nil }
          return value
        }
        .joined(separator: " ")
      if !packageText.isEmpty {
        parts.append(String(localized: "Package: \(packageText)", locale: locale))
      }
    }
    return parts.isEmpty
      ? String(localized: "Not specified", locale: locale)
      : parts.joined(separator: ", ")
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

struct QuantityExpressionEditor: View {
  @Binding var quantity: QuantityExpression?
  let availableKinds: [QuantityExpression.Kind]
  let accessibilityIdentifier: String?

  var body: some View {
    Picker(selection: kindBinding) {
      ForEach(availableKinds, id: \.self) { kind in
        Text(kind.label).tag(kind)
      }
    } label: {
      EditorFieldLabel("Quantity type")
    }
    .identified(accessibilityIdentifier.map { "\($0)-kind" })

    switch quantity?.kind ?? .none {
    case .none:
      Text("No quantity specified")
        .foregroundStyle(.secondary)
    case .exact:
      RationalQuantityEditor(
        "Quantity",
        quantity: lowerBoundBinding,
        accessibilityIdentifier: accessibilityIdentifier.map { "\($0)-lower" }
      )
    case .range:
      RationalQuantityEditor(
        "From",
        quantity: lowerBoundBinding,
        accessibilityIdentifier: accessibilityIdentifier.map { "\($0)-lower" }
      )
      RationalQuantityEditor(
        "Through",
        quantity: upperBoundBinding,
        accessibilityIdentifier: accessibilityIdentifier.map { "\($0)-upper" }
      )
    case .approximate:
      RationalQuantityEditor(
        "About",
        quantity: lowerBoundBinding,
        accessibilityIdentifier: accessibilityIdentifier.map { "\($0)-lower" }
      )
    case .text:
      EditorTextField(
        "Amount",
        text: textBinding,
        prompt: "to taste, as needed, a handful…"
      )
    }
  }

  private var kindBinding: Binding<QuantityExpression.Kind> {
    Binding(
      get: { quantity?.kind ?? .none },
      set: { newKind in
        let previousText = quantity?.text
        switch newKind {
        case .none:
          if availableKinds.contains(.none) { quantity = nil }
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
  let accessibilityIdentifier: String?

  init(
    _ label: String,
    quantity: Binding<RationalQuantity>,
    accessibilityIdentifier: String?
  ) {
    self.label = label
    _quantity = quantity
    self.accessibilityIdentifier = accessibilityIdentifier
  }

  var body: some View {
    LabeledContent {
      HStack(spacing: 6) {
        Button {
          quantity.numerator = max(0, quantity.numerator - 1)
        } label: {
          Image(systemName: "minus")
        }
        .disabled(quantity.numerator == 0)
        .accessibilityLabel("Decrease \(label.lowercased())")
        .identified(accessibilityIdentifier.map { "\($0)-decrement" })

        TextField("Numerator", value: numeratorBinding, format: .number)
          .labelsHidden()
          .frame(maxWidth: 90)
          .identified(accessibilityIdentifier.map { "\($0)-numerator" })
        Text("/")
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
        TextField("Denominator", value: denominatorBinding, format: .number)
          .labelsHidden()
          .frame(maxWidth: 90)
          .identified(accessibilityIdentifier.map { "\($0)-denominator" })

        Button {
          let (numerator, overflow) = quantity.numerator.addingReportingOverflow(1)
          if !overflow { quantity.numerator = numerator }
        } label: {
          Image(systemName: "plus")
        }
        .disabled(quantity.numerator == Int.max)
        .accessibilityLabel("Increase \(label.lowercased())")
        .identified(accessibilityIdentifier.map { "\($0)-increment" })
      }
      // Form promotes automatic-style buttons to a shared row action on iOS.
      // Keep decrement and increment independent instead of firing them together.
      .buttonStyle(.borderless)
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

private extension View {
  @ViewBuilder
  func identified(_ identifier: String?) -> some View {
    if let identifier {
      accessibilityIdentifier(identifier)
    } else {
      self
    }
  }
}

private extension QuantityExpression.Kind {
  var label: String {
    switch self {
    case .none: String(localized: "None")
    case .exact: String(localized: "Exact")
    case .range: String(localized: "Range")
    case .approximate: String(localized: "Approximate")
    case .text: String(localized: "Words")
    }
  }
}
