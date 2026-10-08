// Kitchen Memory
// Copyright © 2026 the Kitchen Memory contributors.
// SPDX-License-Identifier: MIT

/// Reconstructs one complete Session from retained, unordered evidence.
public enum SessionEvidenceProjector {
    /// Reconstructs a complete Session, then applies independent deletion disposition.
    ///
    /// Exact physical duplicates coalesce; conflicts preserve concurrent cooking values.
    /// Missing dependencies and unknown required formats wait, while positive integrity
    /// violations require recovery. Closure validation seals only observed content and
    /// retains late Facts without silently changing the Finished performance.
    public static func project(_ evidence: SessionEvidence) -> SessionProjectionResult {
        let builder = ProjectionBuilder(evidence: evidence)
        return builder.applyDisposition(to: builder.build())
    }
}
