// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import KitchenKit
import SwiftUI

struct CookingSessionInstructionRow: View {
  let model: CookingSessionPresentationModel
  let session: CookingSessionProjection
  let instruction: SessionInstruction
  let number: Int
  @Environment(\.locale) private var locale
  @Environment(\.cookingReadingOrigin) private var readingOrigin

  var body: some View {
    let state = session.instructionProgress(for: instruction.id)
    let isCurrent = session.lifecycle != .finished
      && model.readingPreference(for: session).emphasizedInstructionID == instruction.id
    return VStack(alignment: .leading, spacing: 12) {
      if isCurrent {
        Label(.sessionReadingCurrent, systemImage: "arrow.right.circle.fill")
          .font(.caption.bold())
          .foregroundStyle(.tint)
      }
      HStack(alignment: .top, spacing: 12) {
        Button {
          model.setInstruction(instruction.id, to: state == .open ? .completed : .open, readingOrigin: readingOrigin)
        } label: {
          Image(systemName: instructionSymbol(state))
            .font(.title)
            .foregroundStyle(instructionColor(state))
            .frame(width: 56, height: 56)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(session.lifecycle != .active)
        .accessibilityLabel(RecipeInstructionAccessibilityFormatter(locale: locale).label(
          number: number, step: instruction.value))
        .accessibilityValue(Text(instructionValue(state)))
        .accessibilityIdentifier("session-instruction-step-\(instruction.id.rawValue.uuidString)")

        VStack(alignment: .leading, spacing: 8) {
          Text(.recipeInstructionStep(number: number))
            .font(.headline)
            .accessibilityHeading(.h3)
          Text(instruction.value.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
          if let duration = instruction.value.duration {
            Label(RecipePresentationFormatter(locale: locale).duration(duration), systemImage: "timer")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        .background {
          NativeCookingCompleteSwipe(isEnabled: session.lifecycle == .active && state == .open) {
            model.setInstruction(instruction.id, to: .completed, readingOrigin: readingOrigin)
          }
        }
      }
      if session.lifecycle != .finished {
        HStack {
          Button(.sessionReadingSelect) { model.chooseReadingInstruction(instruction.id, in: session) }
            .accessibilityIdentifier("session-read-step-\(instruction.id.rawValue.uuidString)")
            .frame(minHeight: 44)
          Spacer()
          if state == .open {
            Button(.sessionProgressInstructionSkip) { model.setInstruction(instruction.id, to: .skipped) }
              .disabled(session.lifecycle != .active)
              .frame(minHeight: 44)
          }
          instructionMenu(instruction, state: state)
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.borderless)
      }
      if CookingSessionScalingGuidance(session: session).isNonOriginal {
        VStack(alignment: .leading, spacing: 6) {
          if instruction.value.duration != nil {
            Label(.sessionScaleGuidanceTime, systemImage: "timer")
          }
          if instruction.value.temperature != nil {
            Label(.sessionScaleGuidanceTemperature, systemImage: "thermometer")
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      CookingSessionTargetNotes(model: model, session: session, target: .instruction(instruction.id))
    }
    .padding(12)
    .background(isCurrent ? Color.accentColor.opacity(0.08) : .clear, in: .rect(cornerRadius: 12))
    .background {
      GeometryReader { geometry in
        Color.clear.preference(key: CookingReadingFrames.self,
          value: [instruction.id: geometry.frame(in: .named("cooking-reading"))])
      }
    }
    .accessibilityElement(children: .contain)
  }

  private func instructionMenu(
    _ instruction: SessionInstruction,
    state: SessionInstructionProgress
  ) -> some View {
    Menu {
      if state == .open {
        Button(.sessionProgressInstructionComplete) {
          model.setInstruction(instruction.id, to: .completed, readingOrigin: readingOrigin)
        }
        Button(.sessionProgressInstructionSkip) {
          model.setInstruction(instruction.id, to: .skipped)
        }
      } else {
        Button(.sessionProgressInstructionReopen) {
          model.setInstruction(instruction.id, to: .open)
        }
      }
    } label: {
      Image(systemName: "ellipsis.circle")
    }
    .disabled(session.lifecycle != .active)
    .accessibilityLabel(Text(.sessionProgressInstructionMoreActions))
    .accessibilityIdentifier("session-instruction-menu-\(instruction.id.rawValue.uuidString)")
  }

  private func instructionSymbol(_ state: SessionInstructionProgress) -> String {
    switch state {
    case .open: "circle"
    case .completed: "checkmark.circle.fill"
    case .skipped: "forward.circle.fill"
    }
  }

  private func instructionColor(_ state: SessionInstructionProgress) -> Color {
    state == .open ? .secondary : .accentColor
  }

  private func instructionValue(_ state: SessionInstructionProgress) -> LocalizedStringResource {
    switch state {
    case .open: .sessionProgressInstructionOpen
    case .completed: .sessionProgressInstructionCompleted
    case .skipped: .sessionProgressInstructionSkipped
    }
  }
}
