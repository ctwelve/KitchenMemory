# Release preparation loop

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

This runbook implements [ADR 0018](adr/0018-converge-release-preparation-on-evidence.md).
[ADR 0020](adr/0020-scale-release-assurance-to-scope.md) limits its mandatory
scope to major-release assurance or explicitly requested broader audits; ordinary
bug-fix publication uses the short path in [release engineering](release-engineering.md).
When this loop is selected, use it once prerequisite work is complete. For 0.3, the execution
belongs to [#124](https://github.com/ctwelve/KitchenMemory/issues/124); its live
issue dependencies remain the gate. Recording this workflow does not start the
refactor or authorize distribution. The accessibility gates are the alpha or beta
obligations in [accessibility engineering](accessibility-engineering.md); the 0.3
alpha pass does not require the deferred beta matrix.

## Start and retain evidence

Pin the base commit, release scope, accepted specifications, relevant ADRs, and
required validation gates before changing code. Record the actual model and
reasoning setting. Architecture exploration, implementation, and dead-code
analysis run at **High** reasoning; a future wrapper must select that setting
explicitly rather than claiming that prompt wording changes it.

Keep a resumable record with the work branch: base and current commit, iteration,
paths examined, ranked findings, evidence, disposition, tests and artifact paths,
review results, and the next action. Summarize final evidence in the draft PR.
Each finding is fixed, rejected with a reason, deferred to a named ticket, or
blocked. Required release work cannot be deferred merely to obtain a green verdict.
Treat execution limits or unavailable tools as a resumable interruption, never
as evidence of completion.

## Inner loop: improve only what earns its cost

1. Use [improve-codebase-architecture](../.agents/skills/improve-codebase-architecture/SKILL.md)
   and its [design vocabulary](../.agents/skills/codebase-design/SKILL.md).
   Start with recent hotspots, then cover the remaining codebase over the pass.
   Rank candidates by demonstrated friction and likely benefit relative to risk.
   Require concrete files and callers, a real ownership or testability problem,
   and an explanation of how greater module depth improves locality or leverage.
   Aesthetic preference, speculative future adapters, and an arbitrary file-size
   target do not make a recommendation actionable. Apply the deletion test;
   removing a useful abstraction only to scatter complexity is not improvement.
2. Select the strongest actionable recommendation, if any, and use
   [implement](../.agents/skills/implement/SKILL.md) in a small reviewable step.
   For this release workflow, the maintainer has preselected the top justified
   recommendation: the architecture skill's ordinary candidate-choice pause does
   not require another selection each iteration. Resolve design questions from
   accepted contracts; ask only when a material product or policy decision remains.
   Preserve the skill's exploration and report evidence. A proposed ADR reversal,
   data-format change, or new product behavior leaves this refactor's scope.
3. Audit dead code across production sources, tests, resources, project membership,
   build scripts, and configuration. Compiler and reference-search findings are
   candidates, not proof. Check generated symbols, platform/configuration branches,
   protocol witnesses, Objective-C selectors and reflection, SwiftUI entry points,
   resource loading, and external consumers of public interfaces before deletion.
   Preserve frozen schemas, migration and synchronization contracts, and intentionally
   retained historical material. Record why apparently unused material stays.
4. Remove proved dead code and obsolete indirection, including tests that only
   sustain removed implementation details. Preserve behavioral tests and add a
   regression at the real interface when fixing a bug. Typecheck and run focused
   tests during changes; validate deletions on affected platforms/configurations.
5. Repeat architecture selection and dead-code analysis against the changed commit.
   Do not repeat rejected recommendations without new evidence. If there is no
   justified architecture change, proceed with the audit; a pass need not produce
   a refactor. Repeated reversals or an unchanged unresolved finding require a
   documented blocker or maintainer decision, not more speculative edits.

## Outer loop: validation and independent challenge

When a complete inner pass produces no further actionable findings:

1. Run the current [CI and coverage contract](continuous-integration.md): a fresh
   exact durable-logic coverage gate, required hosted/native tests, strict lint,
   project/resource/localization and inventory checks, and the release-style
   builds and accessibility gates required by the release tickets. Native tests
   use [Xcode's application workflow](agents/xcode.md). Never shrink a coverage
   denominator or add an exclusion to hide reachable untested logic. Evidence
   must correspond to the candidate being reviewed; coverage is not proof of
   meaningful assertions or of dead-code absence.
2. Run independent adversarial **Spec** and **Engineering** reviews, using
   [code-review](../.agents/skills/code-review/SKILL.md). Reviewers inspect the same
   pinned candidate without relying on the implementer's conclusions. Spec checks
   accepted behavior, invariants, preservation, omissions, and scope. Engineering
   checks ownership, actual call paths, platform/resource wiring, failure handling,
   test strength, remaining dead code, and unsupported claims. Require evidence
   for findings, including a trigger or concrete counterexample where applicable;
   a reviewer may legitimately find nothing.
3. Adjudicate findings against code and accepted contracts. Fix actionable findings
   and return to the inner loop. Revalidate affected gates and obtain independent
   review of the resulting candidate. Evidence from unchanged inputs may be reused
   with its commit and scope recorded; relevant changes invalidate prior evidence.

Finish only when the last complete architecture/dead-code pass has no unresolved
in-scope actionable findings, all required gates pass for the final candidate,
and both reviews are clear. Report residual limitations and explicitly accepted
deferrals. Submit the draft PR and its evidence; merging and releasing remain
separate maintainer actions. This is a finite evidence-based acceptance rule,
not a claim that every possible defect or future refactor has been discovered.

## Future skill

Implement a thin wrapper around this runbook when automating release preparation.
It should persist the iteration record, select High reasoning for the specified
stages, resume from the last verified checkpoint, and dispatch the independent
reviews. It must not silently restart from scratch, run overlapping native test
actions, invent findings to meet a quota, or treat a time/iteration limit as success.
