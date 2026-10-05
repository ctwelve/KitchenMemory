// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// An interpretation of one source line; annotations refer to its unchanged UTF-16 text.
public struct IngredientLineInterpretation: Equatable, Sendable {
    /// The provisional meaning of a span in the unchanged authored source line.
    public enum SegmentKind: Equatable, Sendable {
      /// The recognized leading amount, including supported exact and ranged forms.
      case quantity
      /// The recognized amount unit or container word following the quantity.
      case unit
      /// A recognized parenthesized package-size phrase, separate from the package count.
      case package
      /// The interpreted ingredient-name span after quantity, package, and unit prefixes.
      case ingredient
      /// The preparation wording after the first separating comma.
      case preparation
    }

    /// One native-text annotation measured in UTF-16 offsets into the original source.
    public struct Segment: Equatable, Sendable {
        /// The provisional meaning assigned to this authored source span.
        public let kind: SegmentKind
        /// Half-open UTF-16 offsets into the unchanged source line, suitable for native text annotation.
        public let utf16Range: Range<Int>
    }

    /// The provisional row value retaining the authored source and original presentation mode.
    public internal(set) var ingredient: RecipeIngredient
    /// Recognized source spans in parse order; unsupported wording may have no annotations.
    public internal(set) var segments: [Segment]
}

extension IngredientLineInterpretation {
    mutating func append(_ kind: SegmentKind, range: Range<String.Index>, in source: String) {
        let offsets = NSRange(range, in: source)
        self = Self(ingredient: ingredient,
                    segments: segments + [Segment(kind: kind, utf16Range: offsets.location..<NSMaxRange(offsets))])
    }

    mutating func append(_ kind: SegmentKind, text: String, in source: String, after: String.Index) {
        guard let range = source.range(of: text, range: after..<source.endIndex) else { return }
        append(kind, range: range, in: source)
    }

    mutating func append(_ kind: SegmentKind, text: String, in source: String, afterUTF16 offset: Int) {
        append(kind, text: text, in: source, after: String.Index(utf16Offset: offset, in: source))
    }
}
