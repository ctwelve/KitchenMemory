<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

# Contributing to Kitchen Memory

Thanks for helping improve Kitchen Memory. Contributions are welcome through
GitHub Issues and pull requests. Please read the [Code of Conduct](CODE_OF_CONDUCT.md)
before taking part. Report security vulnerabilities using [the private process](SECURITY.md),
not a public issue.

## Issues and proposals

Use the repository's bug report template for reproducible problems and the
feature request template for proposed behavior. Search existing issues first;
add relevant context to an existing issue when one already covers the same
problem. For a substantial behavior or architecture change, open or discuss an
issue before investing in implementation so the project can agree on scope.

Do not include private recipes, account details, or other personal information
in issues, screenshots, sample files, or logs. Use fictional examples and redact
private data before sharing diagnostic material.

## Changes and pull requests

- Keep a change focused and explain the user need it addresses.
- Follow the current product contracts and accepted decisions in the
  [development documentation](docs/README.md).
- Describe behavior changes, link related issues, and include the checks you
  ran. Add screenshots or recordings when they help explain a UI change; ensure
  they contain no private recipe or account data.
- Run relevant checks using the workflows in
  [Continuous Integration](docs/continuous-integration.md). Run native
  application and UI tests through Xcode's Test action, as described in
  [the Xcode agent workflow](docs/agents/xcode.md).
- Read [AI-assisted development](AI.md) when using AI tools. Contributors remain
  responsible for reviewing, validating, and licensing submitted work.
- Follow the repository's [copyright and licensing notice](COPYRIGHT). New
  contributions are distributed under the repository's MIT license.

The maintainer may ask for revisions, defer a proposal, or close work that does
not fit the project's current scope. Review and response times are not
guaranteed.
