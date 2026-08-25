# ADR 0009: Use separate native iOS and macOS application targets

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

## Status

Accepted.

## Context

Kitchen Memory began with one multiplatform application target so the
foundation slices could exercise one shared SwiftUI interface. That source
strategy remains useful for 0.1 under
<doc:0006-shared-ui-for-foundation-slices>, but one product target also made
unrelated platform contracts share launch resources, entitlements, build
settings, and destination behavior.

iOS and macOS already require different launch mechanisms, capabilities, and
release artifacts, and the expected 0.2 presentation work may make their source
trees diverge further. Continuing to express those differences through
filename conventions and conditional build settings inside one product target
would make target ownership increasingly difficult to inspect.

Xcode schemes may build several targets, but that does not make two native
application products one runnable or archive. Likewise, a test plan
configuration repeats one plan's target set with different arguments and
diagnostics; it does not select an operating system, destination, or alternate
application host.

## Decision

Use two native application targets:

- `KitchenMemory iOS` supports native iPhone and iPad destinations.
- `KitchenMemory macOS` supports native Mac destinations.

Keep the provisional 0.1 presentation, composition, localization, and starter
content in `KitchenMemory/`, with explicit membership in both app targets.
Place platform-owned resources and entitlements in `KitchenMemoryIOS/` and
`KitchenMemoryMac/`. Keep the four reusable framework targets in their
root-level folders.

Give each app target three shared schemes: Development, Testing, and
Production. Each scheme builds one top-level application product plus its
ordinary framework dependencies. Development and Testing are not archive
surfaces. Development may profile the `Production` configuration locally;
Testing neither profiles nor archives. The platform Production schemes profile
and archive distributable products.

Use four platform-specific test plans. Each platform's Development and Testing
schemes reuse its non-UI Testing plan, while its Production scheme uses a
Production plan containing the platform application-test target and the shared
UI-smoke target. The shared UI target chooses its native app host through
SDK-conditional target settings. Platform and destination remain scheme or CI
action choices rather than test-plan configurations.

Support only the products Kitchen Memory intentionally ships. The iOS target
does not advertise Mac Catalyst, Mac Designed for iPhone or iPad, or visionOS
Designed for iPhone or iPad compatibility. A future Catalyst, visionOS, or tvOS
product requires its own product decision and validation rather than appearing
implicitly in Xcode's destination list.

This decision changes product and resource ownership, not the current UI
reuse decision. ADR 0006 remains accepted, and the testing-investment boundary
in <doc:0007-business-logic-coverage-and-ui-smoke-tests> continues to apply.

## Consequences

- Launch resources, entitlements, signing, destinations, and archives have
  inspectable platform owners.
- The shared 0.1 application layer can continue unchanged while either 0.2
  presentation evolves independently.
- Scheme and test-plan duplication is deliberate because the two native
  products have different hosts and destinations.
- The app configuration matrix, scheme-to-plan references, supported
  destinations, and resource membership become project contracts that should
  be checked automatically.
- Both platform application-test lanes remain correctness gates. One platform
  may produce the canonical coverage artifact without making the other lane
  optional.
- A combined cross-platform scheme would add an alternate orchestration surface
  without replacing either native runnable or archive, so none is introduced.
