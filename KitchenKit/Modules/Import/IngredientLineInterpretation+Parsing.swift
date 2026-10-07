// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

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
