// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

/// A deterministic importer for already-captured HTML and JSON-LD.
///
/// This type deliberately has no network or persistence dependency. Callers
/// retain control of acquisition, candidate choice, review, and saving.
public struct SchemaOrgRecipeImporter: Sendable {
    /// Independent finite budgets governing acquisition-size, JSON expansion, and emitted content.
    public let limits: RecipeImportLimits

    /// Creates a deterministic parser with supplied positive resource limits; it opens no network or store.
    public init(limits: RecipeImportLimits = .init()) {
        self.limits = limits
    }

    /// Discovers JSON-LD script blocks in captured HTML and returns all usable Recipe interpretations.
    ///
    /// It does not execute scripts or use general article heuristics. Malformed sibling
    /// blocks remain diagnostic; any resource ceiling discards candidates. The optional
    /// URL supplies provenance and relative-link resolution, without fetching.
    public func importHTML(_ html: String, documentURL: URL? = nil) -> RecipeImportResult {
        guard html.utf8.count <= limits.maximumInputBytes else {
            return Self.limitExceededResult(.inputBytes)
        }
        let discovery = HTMLJSONLDBlockScanner.scan(html, maximumBlocks: limits.maximumJSONLDBlocks)
        guard !discovery.exceededLimit else {
            return Self.limitExceededResult(.jsonLDBlocks)
        }
        return importJSONLDBlocks(discovery.blocks, documentURL: documentURL)
    }

    /// Interprets one captured JSON-LD block, including arrays and `@graph` Recipe objects.
    ///
    /// BOM-marked UTF-16/32 is transcribed to UTF-8; unmarked input must be UTF-8.
    /// Unsupported shapes and malformed data become diagnostics rather than throws.
    /// Resource failures return no partial candidates and preserve their limit reason.
    public func importJSONLD(_ data: Data, documentURL: URL? = nil) -> RecipeImportResult {
        importJSONLDBlocks([data], documentURL: documentURL)
    }

    private static func limitExceededResult(
        _ limit: RecipeImportDiagnostic.ProcessingLimit
    ) -> RecipeImportResult {
        RecipeImportResult(
            candidates: [],
            diagnostics: [.init(blockIndex: 0, kind: .processingLimitExceeded(limit))]
        )
    }
}
