// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

import Foundation

extension SchemaOrgRecipeImporter {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func importJSONLDBlocks(_ blocks: [Data], documentURL: URL?) -> RecipeImportResult {
        var candidates: [RecipeImportCandidate] = []
        var diagnostics: [RecipeImportDiagnostic] = []
        var normalizedOutputBudget = NormalizedOutputBudget(
            maximumUTF8Bytes: limits.maximumNormalizedUTF8Bytes
        )

        for (blockIndex, sourceData) in blocks.enumerated() {
            let data: Data
            do {
                data = try BoundedJSONLDDocument.normalizedUTF8(
                    from: sourceData,
                    maximumBytes: limits.maximumInputBytes
                )
            } catch {
                switch error {
                case .tooLarge:
                    diagnostics.append(.init(
                        blockIndex: blockIndex,
                        kind: .processingLimitExceeded(.inputBytes)
                    ))
                    return RecipeImportResult(candidates: [], diagnostics: diagnostics)
                case .invalidEncoding:
                    diagnostics.append(.init(blockIndex: blockIndex, kind: .malformedJSONLD))
                    continue
                }
            }
            // Resource failure invalidates discovery as a whole. Returning only
            // an early candidate prefix could falsely make a multi-Recipe source
            // appear unambiguous and would hide material the person should review.
            guard BoundedJSONLDDocument.isWithinStructureLimits(data, limits: limits) else {
                diagnostics.append(.init(
                    blockIndex: blockIndex,
                    kind: .processingLimitExceeded(.jsonStructure)
                ))
                return RecipeImportResult(candidates: [], diagnostics: diagnostics)
            }
            let value: Any
            do {
                value = try JSONSerialization.jsonObject(with: data)
            } catch {
                diagnostics.append(.init(blockIndex: blockIndex, kind: .malformedJSONLD))
                continue
            }

            guard let objects = BoundedJSONLDDocument.topLevelObjects(
                in: value,
                maximum: limits.maximumTopLevelObjects
            ) else {
                diagnostics.append(.init(
                    blockIndex: blockIndex,
                    kind: .processingLimitExceeded(.topLevelObjects)
                ))
                return RecipeImportResult(candidates: [], diagnostics: diagnostics)
            }
            if objects.isEmpty {
                diagnostics.append(.init(blockIndex: blockIndex, kind: .unsupportedTopLevel))
                continue
            }

            for (objectIndex, object) in objects.enumerated() where Self.isRecipe(object) {
                guard candidates.count < limits.maximumCandidates else {
                    diagnostics.append(.init(
                        blockIndex: blockIndex,
                        kind: .processingLimitExceeded(.candidates)
                    ))
                    return RecipeImportResult(candidates: [], diagnostics: diagnostics)
                }
                guard SchemaOrgRecipeDraftNormalizer.consumedFieldsAreWithinLimits(object, limits: limits) else {
                    diagnostics.append(.init(
                        blockIndex: blockIndex,
                        kind: .processingLimitExceeded(.consumedFields)
                    ))
                    return RecipeImportResult(candidates: [], diagnostics: diagnostics)
                }
                let title: String
                if let sourceTitle = SchemaOrgValue.text(object["name"]) {
                    title = sourceTitle
                } else {
                    title = ""
                    diagnostics.append(.init(blockIndex: blockIndex, kind: .missingTitle))
                }
                let draft: RecipeImportDraft
                do {
                    draft = try SchemaOrgRecipeDraftNormalizer.makeDraft(
                        from: object,
                        title: title,
                        documentURL: documentURL,
                        limits: limits
                    )
                    try normalizedOutputBudget.validate(draft)
                } catch {
                    diagnostics.append(.init(
                        blockIndex: blockIndex,
                        kind: .processingLimitExceeded(.normalizedOutput)
                    ))
                    return RecipeImportResult(candidates: [], diagnostics: diagnostics)
                }
                // Capture the containing source block, not serialized normalized
                // fields: normalization intentionally omits unsupported semantics,
                // while this transcription permits later reinterpretation.
                let snapshot = RecipeImportSourceSnapshot(
                    documentURL: documentURL,
                    jsonLD: data
                )
                candidates.append(
                    RecipeImportCandidate(
                        id: .init(blockIndex: blockIndex, objectIndex: objectIndex),
                        draft: draft,
                        snapshot: snapshot
                    )
                )
            }
        }

        return RecipeImportResult(candidates: candidates, diagnostics: diagnostics)
    }

    private static func isRecipe(_ object: [String: Any]) -> Bool {
        SchemaOrgValue.strings(object["@type"]).contains { type in
            type.split(separator: "/").last?.caseInsensitiveCompare("Recipe") == .orderedSame
        }
    }
}
