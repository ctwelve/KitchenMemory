// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// A bounded-work scanner for JSON-LD script elements in untrusted HTML.
///
/// A regular expression that searches from every plausible opening tag to a
/// later closing tag can revisit the same suffix once per malformed opener.
/// That turns a bounded network response into quadratic CPU work. This scanner
/// instead advances monotonically: every byte is examined only while locating
/// its enclosing tag or script body, and a completed element is never searched
/// again. It is intentionally a small HTML recognizer rather than a general HTML
/// parser; the importer needs only script boundaries and one ASCII attribute.
enum HTMLJSONLDBlockScanner {
    private static let script = Array("script".utf8)
    private static let type = Array("type".utf8)
    private static let jsonLDMediaType = Array("application/ld+json".utf8)
    private static let commentOpening = Array("<!--".utf8)
    private static let commentClosing = Array("-->".utf8)

    static func scan(
        _ html: String,
        maximumBlocks: Int
    ) -> (blocks: [Data], exceededLimit: Bool) {
        // The URL path already bounds the document to 2 MiB. One contiguous
        // UTF-8 copy gives this security boundary integer indices and predictable
        // constant-time access instead of repeatedly traversing String graphemes.
        let bytes = Array(html.utf8)
        var blocks: [Data] = []
        var cursor = 0

        while cursor < bytes.count {
            guard bytes[cursor] == ascii("<") else {
                cursor += 1
                continue
            }

            // Script-looking text inside an HTML comment is inert. Skipping the
            // entire comment also prevents it from manufacturing false candidates.
            if matches(commentOpening, in: bytes, at: cursor, caseInsensitive: false) {
                guard let end = firstOccurrence(
                    of: commentClosing,
                    in: bytes,
                    startingAt: cursor + commentOpening.count,
                    caseInsensitive: false
                ) else { break }
                cursor = end + commentClosing.count
                continue
            }

            let nameStart = cursor + 1
            guard matches(script, in: bytes, at: nameStart, caseInsensitive: true) else {
                cursor += 1
                continue
            }
            let afterName = nameStart + script.count
            guard afterName < bytes.count, isTagBoundary(bytes[afterName]) else {
                cursor += 1
                continue
            }
            guard let openingEnd = tagEnd(in: bytes, startingAt: afterName) else { break }

            let isJSONLD = containsJSONLDType(
                in: bytes,
                attributes: afterName..<openingEnd
            )
            let contentStart = openingEnd + 1
            guard let closing = closingScriptTag(in: bytes, startingAt: contentStart) else {
                // Under HTML parsing rules an unclosed script consumes the rest of
                // the document. Stopping here is both faithful and strictly linear.
                break
            }

            if isJSONLD {
                guard blocks.count < maximumBlocks else {
                    return (blocks, true)
                }
                blocks.append(Data(bytes[contentStart..<closing.start]))
            }
            cursor = closing.end + 1
        }

        return (blocks, false)
    }

    private static func closingScriptTag(
        in bytes: [UInt8],
        startingAt start: Int
    ) -> (start: Int, end: Int)? {
        var cursor = start
        while cursor < bytes.count {
            guard bytes[cursor] == ascii("<"),
                  cursor + 2 < bytes.count,
                  bytes[cursor + 1] == ascii("/"),
                  matches(script, in: bytes, at: cursor + 2, caseInsensitive: true)
            else {
                cursor += 1
                continue
            }
            let afterName = cursor + 2 + script.count
            guard afterName < bytes.count, isTagBoundary(bytes[afterName]),
                  let end = tagEnd(in: bytes, startingAt: afterName)
            else {
                cursor += 1
                continue
            }
            return (cursor, end)
        }
        return nil
    }

    /// Finds `>` without mistaking a greater-than sign inside a quoted
    /// attribute for the end of the tag. Unterminated quotes make the tag
    /// malformed, so the caller stops instead of searching the same bytes again.
    private static func tagEnd(in bytes: [UInt8], startingAt start: Int) -> Int? {
        var quote: UInt8?
        var cursor = start
        while cursor < bytes.count {
            let byte = bytes[cursor]
            if let activeQuote = quote {
                if byte == activeQuote { quote = nil }
            } else if byte == ascii("\"") || byte == ascii("'") {
                quote = byte
            } else if byte == ascii(">") {
                return cursor
            }
            cursor += 1
        }
        return nil
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private static func containsJSONLDType(
        in bytes: [UInt8],
        attributes: Range<Int>
    ) -> Bool {
        var cursor = attributes.lowerBound
        while cursor < attributes.upperBound {
            while cursor < attributes.upperBound,
                  isASCIIWhitespace(bytes[cursor]) || bytes[cursor] == ascii("/") {
                cursor += 1
            }
            let nameStart = cursor
            while cursor < attributes.upperBound,
                  !isASCIIWhitespace(bytes[cursor]),
                  bytes[cursor] != ascii("="),
                  bytes[cursor] != ascii("/") {
                cursor += 1
            }
            guard nameStart < cursor else {
                cursor += 1
                continue
            }
            let nameRange = nameStart..<cursor
            let isTypeAttribute = equals(
                type,
                bytes: bytes,
                range: nameRange,
                caseInsensitive: true
            )
            while cursor < attributes.upperBound, isASCIIWhitespace(bytes[cursor]) {
                cursor += 1
            }
            guard cursor < attributes.upperBound, bytes[cursor] == ascii("=") else {
                // HTML resolves duplicate attributes to the first occurrence.
                // Treating a later type as authoritative would make extraction
                // disagree with the document model a browser exposes.
                if isTypeAttribute { return false }
                continue
            }
            cursor += 1
            while cursor < attributes.upperBound, isASCIIWhitespace(bytes[cursor]) {
                cursor += 1
            }

            let valueRange: Range<Int>
            if cursor < attributes.upperBound,
               bytes[cursor] == ascii("\"") || bytes[cursor] == ascii("'") {
                let quote = bytes[cursor]
                cursor += 1
                let valueStart = cursor
                while cursor < attributes.upperBound, bytes[cursor] != quote {
                    cursor += 1
                }
                valueRange = valueStart..<cursor
                if cursor < attributes.upperBound { cursor += 1 }
            } else {
                let valueStart = cursor
                while cursor < attributes.upperBound,
                      !isASCIIWhitespace(bytes[cursor]) {
                    cursor += 1
                }
                valueRange = valueStart..<cursor
            }

            if isTypeAttribute {
                return equals(
                    jsonLDMediaType,
                    bytes: bytes,
                    range: valueRange,
                    caseInsensitive: true
                )
            }
        }
        return false
    }

    private static func firstOccurrence(
        of needle: [UInt8],
        in bytes: [UInt8],
        startingAt start: Int,
        caseInsensitive: Bool
    ) -> Int? {
        var cursor = start
        while cursor + needle.count <= bytes.count {
            if matches(needle, in: bytes, at: cursor, caseInsensitive: caseInsensitive) {
                return cursor
            }
            cursor += 1
        }
        return nil
    }

    private static func matches(
        _ needle: [UInt8],
        in bytes: [UInt8],
        at start: Int,
        caseInsensitive: Bool
    ) -> Bool {
        guard start >= 0, start + needle.count <= bytes.count else { return false }
        for offset in needle.indices {
            let candidate = bytes[start + offset]
            let expected = needle[offset]
            if caseInsensitive {
                guard lowercaseASCII(candidate) == lowercaseASCII(expected) else { return false }
            } else if candidate != expected {
                return false
            }
        }
        return true
    }

    private static func equals(
        _ expected: [UInt8],
        bytes: [UInt8],
        range: Range<Int>,
        caseInsensitive: Bool
    ) -> Bool {
        guard range.count == expected.count else { return false }
        return matches(expected, in: bytes, at: range.lowerBound, caseInsensitive: caseInsensitive)
    }

    private static func isTagBoundary(_ byte: UInt8) -> Bool {
        isASCIIWhitespace(byte) || byte == ascii(">") || byte == ascii("/")
    }

    private static func isASCIIWhitespace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D || byte == 0x0C
    }

    private static func lowercaseASCII(_ byte: UInt8) -> UInt8 {
        (0x41...0x5A).contains(byte) ? byte + 0x20 : byte
    }

    private static func ascii(_ character: Character) -> UInt8 {
        character.asciiValue!
    }
}
