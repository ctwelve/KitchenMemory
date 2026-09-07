# Documentation maintenance

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

[The documentation map](README.md) is the navigation authority. Keep it small:
route by the reader's task instead of repeating every source symbol or copying
whole contracts. [Tools](../Tools/README.md) routes repository verification and
separately scoped development utilities.

## Ownership and routing

| Kind | Home and entry point | Use |
| --- | --- | --- |
| Published product | Root [README](../README.md) and GitHub Releases | Downloads and published capability; working source may be newer |
| Current guidance | Topical `docs/*.md`, linked from [the map](README.md) | Product/engineering contracts and their source-of-truth pointers |
| Vocabulary | [CONTEXT.md](../CONTEXT.md) | Stable domain language |
| Decisions | `docs/adr/`, linked from [the decision index](adr/README.md) | Rationale, status, amendments and supersession |
| Research | `docs/research/`, linked from [the research index](research/README.md) | Dated evidence and adoption conditions; fixture READMEs link from their investigation |
| Milestone records | Existing paths linked from [history](history.md) | Candidate results, release notes, completed plans and explicit omissions |
| Code entry points | Existing application and KitchenKit DocC catalogs | Symbols, ownership, and a short newcomer tour |
| Agent workflow | `AGENTS.md` routing to `docs/agents/` | Conditional instructions loaded for the current task |
| Skill library | `.agents/skills/`; `skills/` is a compatibility link | One maintained copy of workflow skills and references |

New top-level guidance belongs in the map or history index. New decisions and
research belong in their respective indexes. Every repository-authored Markdown
page must be reachable from the root README through local links. Preserve
historical file paths and evidence; an old pending gate is not a current task.
Do not update old results to make them look current. Promote durable rules out
of a historical runbook into one current guide, with a pointer back to its record.

## Validation

```sh
ruby Tools/Tests/check_documentation_test.rb
ruby Tools/check-documentation.rb
```

Xcode Cloud's post-clone verification runs both before dependencies execute.
The checker covers root Markdown, `docs/`, tool READMEs, and the two DocC maps.
It checks local file links and ATX heading fragments, reference definitions,
reachability, index classification, and the single skill-tree alias. Fenced
examples, inline code, and DocC symbol references are not Markdown file links.
External URLs are deliberately not fetched. Skill-internal templates are not
repository-authored documentation and have their own workflow semantics.

Current implementation tables are compared with native project targets,
KitchenKit responsibility directories, current schema alias, checked-in test
plans and scheme references, and the localization inventory. Deprecated module
and target names are rejected in current guidance; historical records, ADRs and
research may retain them. Historical links must still resolve.

The guard is bounded, not a general Markdown renderer or semantic proof. It
supports the repository's inline/reference links, ATX headings and explicit HTML
anchors; use percent-encoded spaces or angle-bracket link targets for paths with
spaces. Review prose, resource ownership, frozen schema semantics, and real
behavior against source. Existing project/localization/inventory checkers own
the deeper source invariants. A source-only guard cannot inspect hosted Xcode
Cloud settings or prove linguistic quality, accessibility, or global sync.

## Audit boundary, September 2026

This consolidation follows merged release preparation #124 and supports #85.
The audit covered documentation navigation/currentness, source ownership,
schemes/plans, localization and dependency contracts, agent routing, skill
mirrors, CI scripts, and retained evidence. Production source, data formats,
resources, dependency pins, and frozen ADR/schema records are unchanged.

#85 remains open for reconciliation after #125 advances version/dependency
inputs. Device retirement remains beta-wayfinder work, not an implemented
retention guarantee. The CI enforcement exception was intentional during Cloud
UI runner trouble; the maintainer subsequently restored the Cloud PR requirement.
The [current CI boundary](continuous-integration.md#github-enforcement-boundary)
records the required statuses. The cleanup itself did not change GitHub
protection or Cloud workflow settings. Keep review evidence and validation
results in the cleanup PR, using synthetic data and no private debugging material.
