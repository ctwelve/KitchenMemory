// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// Common scalar interpretation and bounded plain-text construction for Schema.org fields.
enum SchemaOrgValue {
    static func strings(_ value: Any?) -> [String] {
        if let string = value as? String { return [string] }
        if let number = value as? NSNumber { return [number.stringValue] }
        if let array = value as? [Any] { return array.flatMap(strings) }
        return []
    }

    static func text(_ value: Any?) -> String? {
        strings(value).first
    }

    static func scalarText(_ value: Any?) -> String? {
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    // The explicit arguments make every independently bounded collection clear
    // at the call site.
    // swiftlint:disable function_parameter_count
    /// Appends a joined field without first allocating an unbounded temporary.
    /// Both counters are maintained by the caller so repeated appends never
    /// recompute `String.count` over an ever-growing result.
    static func appendBounded(
        _ value: String,
        to output: inout String,
        separator: String,
        charactersUsed: inout Int,
        utf8BytesUsed: inout Int,
        maximumCharacters: Int,
        maximumUTF8Bytes: Int
    ) throws(NormalizedOutputLimitExceeded) {
        guard charactersUsed >= 0,
              charactersUsed <= maximumCharacters,
              utf8BytesUsed >= 0,
              utf8BytesUsed <= maximumUTF8Bytes
        else { throw NormalizedOutputLimitExceeded() }
        let actualSeparator = output.isEmpty ? "" : separator
        let separatorCharacters = actualSeparator.count
        let separatorBytes = actualSeparator.utf8.count
        let valueCharacters = value.count
        let valueBytes = value.utf8.count
        guard separatorCharacters <= maximumCharacters - charactersUsed,
              valueCharacters <= maximumCharacters - charactersUsed - separatorCharacters,
              separatorBytes <= maximumUTF8Bytes - utf8BytesUsed,
              valueBytes <= maximumUTF8Bytes - utf8BytesUsed - separatorBytes
        else { throw NormalizedOutputLimitExceeded() }

        output.append(actualSeparator)
        output.append(value)
        charactersUsed += separatorCharacters + valueCharacters
        utf8BytesUsed += separatorBytes + valueBytes
    }
    // swiftlint:enable function_parameter_count

    static func cleanText(_ value: String) -> String {
        ImportedPlainTextNormalizer.normalize(value)
    }

    static func cleanedNonemptyText(_ value: Any?) -> String? {
        guard let raw = text(value) else { return nil }
        let cleaned = cleanText(raw)
        return cleaned.isEmpty ? nil : cleaned
    }
}
