# Prefer native capabilities and evidence-based dependencies

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: Accepted
- Date: 2026-08-29

## Context

Technology choices affect Kitchen Memory's privacy boundary, supply chain,
licensing, release evidence, maintenance burden, and architecture. A
native-only rule would reject useful focused abstractions, while a
package-first rule would outsource product policy and accumulate dependencies
before their benefit is demonstrated. Building every capability locally would
discard mature implementations and make the project own unnecessary code.

The [Swift tooling ecosystem survey](../research/swift-tooling-ecosystem-survey.md)
provides the initial evidence base. The existing use of Defaults demonstrates a
third-party package that earns its place through a focused preferences
abstraction. The bounded `URLSession` recipe retriever demonstrates the other
outcome: a small project-owned implementation is preferable when the important
work is Kitchen Memory's own privacy and security policy rather than generic
networking convenience.

## Decision

Choose technology in this order:

1. **Native ecosystem first.** Start with Apple platform frameworks and the
   official Apple and Swift project packages, including packages such as Swift
   Collections and Swift Algorithms. “Native first” is a preference for
   platform fit, coherent toolchains, and durable ecosystem stewardship, not a
   requirement to force an inadequate API into the product.
2. **Focused third-party packages when the benefit is compelling.** A package
   may be adopted when it materially improves correctness, comprehension,
   accessibility, performance, or maintenance relative to its dependency and
   lifecycle cost. Its API remains behind the narrowest appropriate KitchenKit
   adapter or in the application UI when it is purely presentational.
3. **A bounded project-owned implementation when available packages do not
   fit.** Prefer local code when candidates cannot meet Kitchen Memory's privacy
   controls, security policy, source-preservation requirements, platform
   behavior, licensing, maintenance expectations, or architectural seams. An
   apparently abandoned package is not a shortcut around owning the code.

Every package, including an official Apple or Swift project package, remains
subject to the repository's dependency inventory and release review. Review its
license and notices, privacy manifest and behavior, products, transitive graph,
plugins and executable or binary artifacts, supported platforms and toolchain,
maintenance evidence, and final application embedding. Preferred provenance
does not waive license and notice review, SBOM, privacy, or signed-product
validation.

Do not let a dependency's types redefine Domain concepts or spread through the
business interface. The outcome should be a smaller Kitchen Memory-owned seam
whose implementation can be replaced without rewriting recipe, Kitchen,
organization, or Cooking Session meaning.

## Research before a new capability category

Before Wayfinder selects implementation technology for a new capability
category—such as media, OCR, assistance, search and organization, interchange,
or a materially broader network surface—it must create or reuse an early
research ticket. Research uses current primary sources to compare:

- Apple platform frameworks and official Apple or Swift project packages;
- focused third-party packages; and
- a bounded project-owned implementation.

The result records fit, privacy and security behavior, maintenance signals,
license and dependency implications, architectural placement, risks, and the
concrete trigger for adoption. Existing research may be reused while its
requirements and ecosystem evidence remain current. Incremental work inside an
already-decided category does not require a fresh survey unless requirements or
available capabilities have materially changed.

## Considered options

- **Native only:** rejected because a focused package can provide a clearer and
  better-maintained abstraction than project code.
- **Third-party first:** rejected because package convenience does not transfer
  responsibility for product policy, privacy, or long-term maintenance.
- **Always build locally:** rejected because undifferentiated infrastructure is
  not a valuable place to spend project complexity.
- **Decide ad hoc without renewed research:** rejected because platform and
  package capabilities evolve, especially across new functionality categories.

## Consequences

- Swift Collections or Algorithms may be adopted as soon as the data model or
  tag system demonstrates a specific structure or operation that they express
  better than bespoke code; this ADR does not adopt them preemptively.
- Third-party adoption remains welcome when its benefit is explicit and its
  behavior fits Kitchen Memory's policies.
- Project-owned implementations carry an affirmative testing, documentation,
  maintenance, and removal obligation; “roll our own” is a fit decision, not an
  exemption from engineering cost.
- A broad survey informs the watchlist, while each actual dependency adoption
  still receives a focused decision and the inventory updates required by
  [`DEPENDENCIES.md`](../../DEPENDENCIES.md).
