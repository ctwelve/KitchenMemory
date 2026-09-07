# ADR 0019: Stage comprehensive accessibility acceptance at beta

- Status: Accepted
- Date: 2026-09-07
- Decision: [Issue 132](https://github.com/ctwelve/KitchenMemory/issues/132)

Accessibility remains a product requirement during alpha, but the current UI is
a proof of concept. Preserve sound accessibility programming, bounded semantic
checks, a short ordinary-use release walkthrough, and blocking tickets for known
barriers. Defer the extensive device and assistive-technology matrix until a
comprehensive UI design pass establishes the intended interface, then stabilize
and validate workflows individually before beta distribution.

Audits and human walkthroughs determine acceptance; brittle UI automation is
supporting evidence. Known core-path barriers block alpha; other accessibility
findings block the relevant stabilization/beta gate. This personal project uses
blocking tickets rather than an exception-ownership bureaucracy. The full
protocol, matrix, automation boundary, and evidence freshness rules live in
[accessibility engineering](../accessibility-engineering.md).

This amends ADR 0007's future stabilization gate without widening its present UI
automation scope. It does not weaken privacy or owner isolation, declare the
current interface stable, or decide whether more features or the UI-to-beta push
follows 0.3-alpha. Accessibility debt must remain visible without making exhaustive
validation of disposable alpha UI a prerequisite to delivering the product.
