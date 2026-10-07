// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct CookingSessionScaleSummary: View {
  let session: CookingSessionProjection
  let adjust: () -> Void
  @Environment(\.locale) private var locale

  private var selection: CookingSessionScaleSelection { .init(session: session) }

  var body: some View {
    Button(action: adjust) {
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
          summary.fixedSize(horizontal: true, vertical: false)
          Spacer(minLength: 8)
          adjustmentLabel.fixedSize()
        }
        VStack(alignment: .leading, spacing: 8) {
          summary
          adjustmentLabel
        }
      }
      .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
    .buttonStyle(.borderless)
    .accessibilityIdentifier("session-scale-summary")
  }

  private var summary: some View {
    VStack(alignment: .leading, spacing: 4) {
      if !selection.bases.isEmpty {
        Text(selection.displayedYield(locale: locale)).foregroundStyle(.primary)
      }
      Text(.sessionScaleFactor(factor: selection.factorLabel(locale: locale)))
        .font(.callout)
        .foregroundStyle(.secondary)
    }
    .fixedSize(horizontal: false, vertical: true)
  }

  private var adjustmentLabel: some View {
    Label(.sessionScaleActionAdjust, systemImage: "slider.horizontal.3")
      .fixedSize(horizontal: false, vertical: true)
  }

}

/// The local selection only proposes commands. The retained projection owns the
/// displayed scale, including any ordered optimistic pending change.
struct CookingSessionScalingView: View {
  let model: CookingSessionPresentationModel
  let session: CookingSessionProjection
  let close: () -> Void
  @State private var selection: CookingSessionScaleSelection
  @State private var customFactor: RationalQuantity
  @State private var showsCalculationFailure = false
  @Environment(\.locale) private var locale

  init(model: CookingSessionPresentationModel, session: CookingSessionProjection,
    close: @escaping () -> Void) {
    self.model = model
    self.session = session
    self.close = close
    let selection = CookingSessionScaleSelection(session: session)
    _selection = State(initialValue: selection)
    _customFactor = State(initialValue: selection.factor)
  }

  private var projectedSession: CookingSessionProjection {
    guard let current = model.currentSession, current.id == session.id else { return session }
    return current
  }

  private var isEnabled: Bool {
    projectedSession.lifecycle == .active && !model.currentSessionHasPendingFinish
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          Text(.sessionScaleFactor(factor: selection.factorLabel(locale: locale)))
            .font(.title2.bold())
            .accessibilityIdentifier("session-scaling-factor")
          if !selection.bases.isEmpty {
            Text(selection.displayedYield(locale: locale))
              .accessibilityIdentifier("session-working-yield")
          }
          if selection.bases.count > 1 {
            Picker(.recipeScalingBaseYield, selection: basis) {
              ForEach(selection.bases.indices, id: \.self) { index in
                Text(selection.basisLabel(selection.bases[index], locale: locale)).tag(index)
              }
            }
            .disabled(!isEnabled)
            .accessibilityIdentifier("session-scaling-basis")
          }
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 12) {
            preset(.sessionScalePresetHalf, accessibility: .sessionScalePresetAccessibilityHalf,
              factor: RationalQuantity(numerator: 1, denominator: 2), identifier: "half")
            preset(.sessionScalePresetOriginal, accessibility: .sessionScalePresetAccessibilityOriginal,
              factor: RationalQuantity(numerator: 1), identifier: "original")
            preset(.sessionScalePresetOneAndHalf, accessibility: .sessionScalePresetAccessibilityOneAndHalf,
              factor: RationalQuantity(numerator: 3, denominator: 2), identifier: "one-and-half")
            preset(.sessionScalePresetDouble, accessibility: .sessionScalePresetAccessibilityDouble,
              factor: RationalQuantity(numerator: 2), identifier: "double")
          }
          .disabled(!isEnabled)
          RationalQuantityEditor(.sessionScaleCustomFactor, quantity: $customFactor,
            accessibilityIdentifier: "session-custom-factor")
            .labeledContentStyle(CookingSessionStackedFieldStyle())
            .disabled(!isEnabled)
          Button(.sessionScaleActionApply) {
            guard let factor = customFactor.normalized, factor.numerator > 0 else { return }
            var proposed = selection
            proposed.selectFactor(factor)
            apply(proposed)
          }
          .buttonStyle(.borderedProminent)
          .disabled(!isEnabled || customFactor.normalized == nil || customFactor.numerator <= 0)
          .accessibilityIdentifier("session-apply-custom-factor")
          if showsCalculationFailure {
            Text(.sessionScaleFailure)
              .foregroundStyle(.secondary)
              .accessibilityIdentifier("session-scale-calculation-failure")
          }
          if model.currentSessionHasPendingWork, model.isShowingIssue, let issue = model.issue {
            Text(issue.message).font(.callout).foregroundStyle(.secondary)
            Button(.sessionSaveRetry) { model.retryPendingCommands() }
              .accessibilityIdentifier("retry-session-scaling-save")
          }
          Text(.sessionScaleNote).font(.footnote).foregroundStyle(.secondary)
          CookingSessionScalingExplanation(model: model, session: projectedSession)
          if CookingSessionScalingGuidance(session: projectedSession).isNonOriginal {
            CookingSessionMethodGuidance(session: projectedSession)
          }
        }
        .padding(24)
      }
      .navigationTitle(.sessionScaleAdjustmentTitle)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button(.actionDone, action: close) }
      }
    }
    .frame(minWidth: 300, minHeight: 400)
    .onChange(of: projectedSession.workingScale) { _, _ in restoreSelection() }
  }

  private func preset(_ title: LocalizedStringResource, accessibility: LocalizedStringResource,
    factor: RationalQuantity, identifier: String) -> some View {
    Button(title) {
      var proposed = selection
      proposed.selectFactor(factor)
      apply(proposed)
    }
    .buttonStyle(.bordered)
    .frame(minHeight: 44)
    .accessibilityLabel(Text(accessibility))
    .accessibilityIdentifier("session-scale-preset-\(identifier)")
  }

  private var basis: Binding<Int> {
    Binding(get: { selection.selectedBasisIndex }, set: { index in
      var proposed = selection
      proposed.selectBasis(index)
      apply(proposed)
    })
  }

  private func apply(_ proposed: CookingSessionScaleSelection) {
    guard isEnabled else { return }
    guard let scale = proposed.scale else {
      showsCalculationFailure = true
      restoreSelection()
      return
    }
    let accepted = model.replaceWorkingScale(with: scale)
    // A delayed save can retain a valid optimistic scale. Arithmetic rejection
    // cannot: always redisplay the actual model projection rather than proposed UI.
    restoreSelection()
    showsCalculationFailure = !accepted && selection != proposed
  }

  private func restoreSelection() {
    selection = CookingSessionScaleSelection(session: projectedSession)
    customFactor = selection.factor
  }
}

struct CookingSessionScalingExplanation: View {
  let model: CookingSessionPresentationModel
  let session: CookingSessionProjection

  var body: some View {
    let guidance = CookingSessionScalingGuidance(session: session)
    if model.scalingExplanationIsVisible(in: session) {
      VStack(alignment: .leading, spacing: 8) {
        if guidance.missingYield { Text(.sessionScaleGuidanceMissingYield) }
        if hasScaledAmount(guidance) { Text(.sessionScaleGuidanceScaled) }
        if hasUnchangedAmount(guidance) { Text(.sessionScaleGuidanceMarked) }
        Text(.sessionScaleGuidanceJudgement)
        Button(.sessionScaleGuidanceDismiss) { model.dismissScalingExplanation(in: session) }
          .accessibilityIdentifier("dismiss-session-scaling-explanation")
      }
      .font(.callout)
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.accentColor.opacity(0.08), in: .rect(cornerRadius: 12))
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("session-scaling-explanation")
    }
  }

  private func hasScaledAmount(_ guidance: CookingSessionScalingGuidance) -> Bool {
    session.snapshot.ingredientSections.flatMap(\.ingredients).contains {
      guidance.ingredientStatus(for: $0) == .scaled
    }
  }

  private func hasUnchangedAmount(_ guidance: CookingSessionScalingGuidance) -> Bool {
    session.snapshot.ingredientSections.flatMap(\.ingredients).contains {
      guidance.ingredientStatus(for: $0) != .scaled
    }
  }
}

struct CookingSessionIngredientScaleGuidance: View {
  let session: CookingSessionProjection
  let ingredient: SessionIngredient

  var body: some View {
    let guidance = CookingSessionScalingGuidance(session: session)
    if guidance.isNonOriginal, let message = message(guidance) {
      Label(message, systemImage: "info.circle")
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("session-ingredient-scaling-\(ingredient.id.rawValue.uuidString)")
    }
  }

  private func message(_ guidance: CookingSessionScalingGuidance) -> LocalizedStringResource? {
    switch guidance.ingredientStatus(for: ingredient) {
    case .scaled: nil
    case .unchangedWithoutQuantity: .sessionScaleGuidanceMissingAmount
    case .unchangedFixed: .recipeScalingStatusFixed
    case .unchangedManualReview: .recipeScalingStatusManualReview
    case .unchangedText:
      ingredient.value.quantity?.kind == QuantityExpression.Kind.none
        ? .sessionScaleGuidanceMissingAmount : .recipeScalingStatusWritten
    case .unchangedPresentationOverride: .recipeScalingStatusPresentationOverride
    case .unchangedArithmeticFailure: .sessionScaleFailure
    }
  }
}

struct CookingSessionMethodGuidance: View {
  let session: CookingSessionProjection

  var body: some View {
    let guidance = CookingSessionScalingGuidance(session: session)
    if guidance.isNonOriginal {
      VStack(alignment: .leading, spacing: 6) {
        if guidance.hasTime { Label(.sessionScaleGuidanceTime, systemImage: "timer") }
        if guidance.hasTemperature { Label(.sessionScaleGuidanceTemperature, systemImage: "thermometer") }
        if guidance.hasMethod { Text(.sessionScaleGuidanceMethod) }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("session-method-scaling-guidance")
    }
  }
}

private struct CookingSessionStackedFieldStyle: LabeledContentStyle {
  func makeBody(configuration: Configuration) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      configuration.label
      configuration.content
    }
  }
}
