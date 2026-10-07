// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

enum JSONTextNormalizationError: Error {
    case tooLarge
    case invalidEncoding
}

/// Admits JSON text under independent byte, structural, and object-count ceilings.
///
/// Transcoding precedes byte preflight; object traversal preserves array and
/// `@graph` order after Foundation validates the syntax.
///
/// `JSONSerialization` accepts UTF-8, UTF-16, and UTF-32, but a byte scanner
/// cannot safely infer quotes and brackets until it knows the encoding. In
/// particular, an ordinary UTF-16 code unit can contain `0x22`, the UTF-8 quote
/// byte, in either half. Normalizing first keeps structural accounting and
/// Foundation parsing in agreement. BOM-less input is intentionally required
/// to be UTF-8; guessing legacy encodings at this trust boundary would make the
/// accepted language ambiguous.
enum BoundedJSONLDDocument {
    static func normalizedUTF8(
        from source: Data,
        maximumBytes: Int
    ) throws(JSONTextNormalizationError) -> Data {
        guard source.count <= maximumBytes else { throw .tooLarge }

        let encoding: String.Encoding
        let byteOrderMarkLength: Int
        let codeUnitWidth: Int
        if source.starts(with: [0x00, 0x00, 0xFE, 0xFF]) {
            encoding = .utf32BigEndian
            byteOrderMarkLength = 4
            codeUnitWidth = 4
        } else if source.starts(with: [0xFF, 0xFE, 0x00, 0x00]) {
            encoding = .utf32LittleEndian
            byteOrderMarkLength = 4
            codeUnitWidth = 4
        } else if source.starts(with: [0xEF, 0xBB, 0xBF]) {
            encoding = .utf8
            byteOrderMarkLength = 3
            codeUnitWidth = 1
        } else if source.starts(with: [0xFE, 0xFF]) {
            encoding = .utf16BigEndian
            byteOrderMarkLength = 2
            codeUnitWidth = 2
        } else if source.starts(with: [0xFF, 0xFE]) {
            encoding = .utf16LittleEndian
            byteOrderMarkLength = 2
            codeUnitWidth = 2
        } else {
            encoding = .utf8
            byteOrderMarkLength = 0
            codeUnitWidth = 1
        }

        // Literal NUL is never valid JSON text; a valid null character must be
        // escaped as `\u0000`. At a BOM-less boundary, NUL bytes are also the
        // reliable signature left by UTF-16/32 encodings of JSON's ASCII
        // punctuation. Rejecting them prevents Foundation from later guessing a
        // different encoding than the one used by this preflight.
        if byteOrderMarkLength == 0, source.contains(0x00) {
            throw .invalidEncoding
        }

        // Foundation may decode a valid prefix and silently ignore an
        // incomplete trailing UTF-16/32 code unit. Check alignment ourselves so
        // source bytes are never discarded before evidence is retained.
        let encodedByteCount = source.count - byteOrderMarkLength
        guard encodedByteCount.isMultiple(of: codeUnitWidth) else {
            throw .invalidEncoding
        }

        // After the explicit alignment check, `String(data:encoding:)` rejects
        // malformed sequences; unlike `String(decoding:as:)`, it does not
        // silently insert replacement characters that would change the
        // publisher's JSON text.
        let encodedText = source.dropFirst(byteOrderMarkLength)
        guard let text = String(data: Data(encodedText), encoding: encoding) else {
            throw .invalidEncoding
        }
        let normalized = Data(text.utf8)
        guard normalized.count <= maximumBytes else { throw .tooLarge }
        return normalized
    }

    // swiftlint:disable cyclomatic_complexity
    /// Scans raw JSON before `JSONSerialization` builds Foundation containers.
    ///
    /// A transport byte limit alone does not prevent a compact document from
    /// containing extreme nesting or hundreds of thousands of tiny values. This
    /// scanner recognizes JSON string escaping and counts structural tokens
    /// without allocating a second object graph. Malformed syntax is still left
    /// to `JSONSerialization`; this pass exists only to enforce resource limits.
    static func isWithinStructureLimits(_ data: Data, limits: RecipeImportLimits) -> Bool {
        var depth = 0
        var tokens = 0
        var isInsideString = false
        var isEscaped = false

        for byte in data {
            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if byte == 0x5C {
                    isEscaped = true
                } else if byte == 0x22 {
                    isInsideString = false
                }
                continue
            }

            switch byte {
            case 0x22:
                isInsideString = true
                tokens += 1
            case 0x7B, 0x5B:
                depth += 1
                tokens += 1
                if depth > limits.maximumJSONDepth { return false }
            case 0x7D, 0x5D:
                // A mismatched closer is JSONSerialization's syntax concern,
                // but it must not end this resource scan early. Continue from a
                // zero floor so a deeply nested suffix still meets the limit.
                if depth > 0 { depth -= 1 }
            case 0x2C, 0x3A:
                tokens += 1
            default:
                break
            }
            if tokens > limits.maximumJSONTokens { return false }
        }
        return true
    }
    // swiftlint:enable cyclomatic_complexity

    static func topLevelObjects(in value: Any, maximum: Int) -> [[String: Any]]? {
        var objects: [[String: Any]] = []
        var stack: [Any] = [value]
        while let next = stack.popLast() {
            if let array = next as? [Any] {
                stack.append(contentsOf: array.reversed())
                continue
            }
            guard let object = next as? [String: Any] else { continue }
            guard objects.count < maximum else { return nil }
            objects.append(object)
            if let graph = object["@graph"] as? [Any] {
                stack.append(contentsOf: graph.reversed())
            }
        }
        return objects
    }
}
