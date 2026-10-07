// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Converts small fragments of publisher-provided markup to native plain text.
///
/// The normalizer advances monotonically through UTF-8 bytes. A malformed tag
/// or raw-text element consumes its remaining suffix once; processing never
/// restarts at each later `<` byte. This bounded-work property matters because
/// callers use the result only after downloading untrusted webpage metadata.
///
/// This is a presentation normalizer, not an HTML sanitizer suitable for an
/// HTML or JavaScript sink. Kitchen Memory renders the result through native
/// plain-text views. Raw source evidence remains untrusted and must be escaped
/// for its eventual destination if a future feature ever renders it elsewhere.
enum ImportedPlainTextNormalizer {
    private struct Entity {
        let spelling: [UInt8]
        let replacement: [UInt8]
    }

    private static let entities = [
        Entity(spelling: Array("&nbsp;".utf8), replacement: [ascii(" ")]),
        Entity(spelling: Array("&amp;".utf8), replacement: [ascii("&")]),
        Entity(spelling: Array("&lt;".utf8), replacement: [ascii("<")]),
        Entity(spelling: Array("&gt;".utf8), replacement: [ascii(">")]),
        Entity(spelling: Array("&quot;".utf8), replacement: [ascii("\"")]),
        Entity(spelling: Array("&#39;".utf8), replacement: [ascii("'")]),
    ]
    private static let commentOpening = Array("<!--".utf8)
    private static let commentClosing = Array("-->".utf8)
    private static let script = Array("script".utf8)
    private static let style = Array("style".utf8)

    static func normalize(_ source: String) -> String {
        let decoded = decodeSupportedEntities(in: Array(source.utf8))
        let textBytes = removingMarkup(from: decoded)
        guard let text = String(bytes: textBytes, encoding: .utf8) else { return "" }
        return collapsingWhitespace(in: text)
    }

    /// Decodes one entity layer. In particular, `&amp;lt;` becomes `&lt;`, not
    /// `<`. Repeated decoding can unexpectedly promote publisher text into
    /// markup, so any additional decoding must be a deliberate caller decision.
    private static func decodeSupportedEntities(in bytes: [UInt8]) -> [UInt8] {
        var output: [UInt8] = []
        output.reserveCapacity(bytes.count)
        var cursor = 0
        while cursor < bytes.count {
            if bytes[cursor] == ascii("&"),
               let entity = entities.first(where: {
                   matches($0.spelling, in: bytes, at: cursor, caseInsensitive: false)
               }) {
                output.append(contentsOf: entity.replacement)
                cursor += entity.spelling.count
            } else {
                output.append(bytes[cursor])
                cursor += 1
            }
        }
        return output
    }

    private static func removingMarkup(from bytes: [UInt8]) -> [UInt8] {
        var output: [UInt8] = []
        output.reserveCapacity(bytes.count)
        var cursor = 0

        while cursor < bytes.count {
            guard bytes[cursor] == ascii("<") else {
                output.append(bytes[cursor])
                cursor += 1
                continue
            }

            if matches(commentOpening, in: bytes, at: cursor, caseInsensitive: false) {
                appendSeparator(to: &output)
                guard let commentEnd = firstOccurrence(
                    of: commentClosing,
                    in: bytes,
                    startingAt: cursor + commentOpening.count
                ) else { break }
                cursor = commentEnd + commentClosing.count
                continue
            }

            guard let openingEnd = tagEnd(in: bytes, startingAt: cursor + 1) else {
                // An unmatched `<` is treated as the start of malformed markup.
                // Dropping the suffix is conservative and, importantly, scans it
                // only once instead of retrying from every later `<` byte.
                appendSeparator(to: &output)
                break
            }

            let name = tagName(in: bytes, tagStart: cursor, tagEnd: openingEnd)
            appendSeparator(to: &output)
            if let name, !name.isClosing, isSuppressedRawTextElement(name.bytes) {
                guard let closingEnd = closingRawTextTag(
                    named: name.bytes,
                    in: bytes,
                    startingAt: openingEnd + 1
                ) else { break }
                cursor = closingEnd + 1
            } else {
                cursor = openingEnd + 1
            }
        }
        return output
    }

    private static func closingRawTextTag(
        named name: [UInt8],
        in bytes: [UInt8],
        startingAt start: Int
    ) -> Int? {
        var cursor = start
        while cursor < bytes.count {
            guard bytes[cursor] == ascii("<"),
                  cursor + 2 < bytes.count,
                  bytes[cursor + 1] == ascii("/"),
                  matches(name, in: bytes, at: cursor + 2, caseInsensitive: true)
            else {
                cursor += 1
                continue
            }
            let afterName = cursor + 2 + name.count
            guard afterName < bytes.count,
                  isTagBoundary(bytes[afterName]),
                  let end = tagEnd(in: bytes, startingAt: afterName)
            else {
                cursor += 1
                continue
            }
            return end
        }
        return nil
    }

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

    private static func tagName(
        in bytes: [UInt8],
        tagStart: Int,
        tagEnd: Int
    ) -> (bytes: [UInt8], isClosing: Bool)? {
        var cursor = tagStart + 1
        let isClosing = cursor < tagEnd && bytes[cursor] == ascii("/")
        if isClosing { cursor += 1 }
        let nameStart = cursor
        while cursor < tagEnd, isTagNameByte(bytes[cursor]) { cursor += 1 }
        guard nameStart < cursor else { return nil }
        return (Array(bytes[nameStart..<cursor]), isClosing)
    }

    private static func isSuppressedRawTextElement(_ name: [UInt8]) -> Bool {
        equalsIgnoringASCIICase(script, name) || equalsIgnoringASCIICase(style, name)
    }

    private static func collapsingWhitespace(in source: String) -> String {
        var output = ""
        output.reserveCapacity(source.utf8.count)
        var separatorPending = false
        for scalar in source.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                separatorPending = !output.isEmpty
            } else {
                if separatorPending { output.append(" ") }
                output.unicodeScalars.append(scalar)
                separatorPending = false
            }
        }
        return output
    }

    private static func appendSeparator(to bytes: inout [UInt8]) {
        if bytes.last != ascii(" ") { bytes.append(ascii(" ")) }
    }

    private static func firstOccurrence(
        of needle: [UInt8],
        in bytes: [UInt8],
        startingAt start: Int
    ) -> Int? {
        var cursor = start
        while cursor + needle.count <= bytes.count {
            if matches(needle, in: bytes, at: cursor, caseInsensitive: false) {
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

    private static func equalsIgnoringASCIICase(_ left: [UInt8], _ right: [UInt8]) -> Bool {
        guard left.count == right.count else { return false }
        for index in left.indices {
            guard lowercaseASCII(left[index]) == lowercaseASCII(right[index]) else { return false }
        }
        return true
    }

    private static func isTagBoundary(_ byte: UInt8) -> Bool {
        isASCIIWhitespace(byte) || byte == ascii(">") || byte == ascii("/")
    }

    private static func isTagNameByte(_ byte: UInt8) -> Bool {
        (0x41...0x5A).contains(byte)
            || (0x61...0x7A).contains(byte)
            || (0x30...0x39).contains(byte)
            || byte == ascii("-")
            || byte == ascii(":")
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
