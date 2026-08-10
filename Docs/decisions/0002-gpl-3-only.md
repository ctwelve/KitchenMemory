<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

# ADR 0002: License the project under GPLv3 only

- Status: Accepted
- Date: 2026-08-09

## Context

The project is intended to be free software. Its license should protect the
ability of users and contributors to study, modify, and redistribute the app and
modified versions.

## Decision

License the project under the GNU General Public License, version 3 only
(`GPL-3.0-only`). Recipients are not automatically offered the option to use a
later version. Include the canonical GPLv3 text in the repository.

Choosing whether to adopt any future GPL version is reserved for the project's
copyright holders and must be made explicitly rather than delegated in advance.

## Consequences

- Distributed derivative works must comply with the GPL's source and licensing
  requirements.
- Dependencies incorporated into the application must be GPLv3-compatible.
- An About or Legal screen should expose the copyright notice, warranty notice,
  license, source location, and third-party notices before public distribution.
- App Store distribution must receive a specific license review against the
  Apple agreement in force at release time; GPL obligations and store terms have
  historically required care even when development and direct Mac distribution
  are straightforward.
- Contributions are accepted under the project's GPL-3.0-only terms unless
  a separate contribution policy is adopted later.
