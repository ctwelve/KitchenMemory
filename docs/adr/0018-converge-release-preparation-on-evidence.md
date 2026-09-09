# ADR 0018: Converge release preparation on evidence

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: Accepted; scope amended by [ADR 0020](0020-scale-release-assurance-to-scope.md)
- Date: 2026-09-07

Release preparation uses a repeatable architecture-improvement and dead-code
audit loop at High reasoning, followed by exact coverage validation and independent
adversarial specification and engineering reviews. A passing suite missed an
unused localization bundle helper with a hard-coded locale: tests alone do not
establish that every abstraction still earns its place.

Implement only the strongest actionable recommendation supported by concrete
code evidence, then reassess. Stop when a complete pass and both independent
reviews find no unresolved actionable work within the accepted release scope;
never manufacture refactors to keep the loop running. Retain rejected and
deferred findings with reasons so subsequent passes do not endlessly rediscover
them. Lack of progress or missing evidence means blocked, not complete.

The [release preparation runbook](../release-preparation.md) is the durable
contract. A future skill may orchestrate it, but must preserve its evidence,
resumption, scope, and completion rules. This decision refines the execution of
[#124](https://github.com/ctwelve/KitchenMemory/issues/124), without bypassing its
prerequisites, changing accepted product behavior, or replacing the coverage and
native accessibility constraints of [ADR 0007](0007-business-logic-coverage-and-ui-smoke-tests.md).
