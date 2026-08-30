# Adopt the MIT License

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: Accepted
- Date: 2026-08-29
- Supersedes: [ADR 0002](0002-gpl-3-only.md)

## Context

Kitchen Memory was initially licensed under GPL-3.0-only to preserve recipients'
freedom to study, modify, and redistribute the application. Research into paid
App Store distribution found that GPLv3 permits charging, but Apple's mandatory
non-transferable license scope, Usage Rules, and security controls create an
unresolved conflict with GPLv3's prohibition on further restrictions. The MIT
License better expresses the sole copyright holder's preference for broad reuse
without requiring downstream source publication and fits the distribution
channels and package ecosystem the project expects to use.

## Decision

License the current Kitchen Memory repository and future releases under the MIT
License (`MIT`). Retain the repository-wide copyright notice and require the MIT
copyright and permission notice in copies or substantial portions of the
software.

Public release 0.1.0 was conveyed under GPL-3.0-only. Those grants remain valid
and are not withdrawn. The sole copyright holder has confirmed authority to
offer the current code under MIT; no contributor relicensing process is needed.

## Consequences

- Kitchen Memory may be used, modified, redistributed, sublicensed, or sold,
  including through the App Store, subject to the MIT notice and applicable
  distribution terms.
- Downstream modifications may remain proprietary and need not publish source.
- Existing GPL-3.0-only copies and their recipients retain every GPLv3 right
  they already received.
- Third-party components retain their own licenses, notices, source obligations,
  and privacy requirements; MIT does not waive dependency or release review.
- Contributions are accepted under MIT unless a separate contribution policy
  is adopted later.
