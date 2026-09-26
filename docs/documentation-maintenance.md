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
| Milestone records | [History](history.md), with completed records linked at a Git commit | Candidate results, release notes, completed plans and explicit omissions |
| Code entry points | Existing application and KitchenKit DocC catalogs | Symbols, ownership, and a short newcomer tour |
| Agent workflow | `AGENTS.md` routing to `docs/agents/` | Conditional instructions loaded for the current task |
| Skill library | `.agents/skills/` | Workflow skills and references for agents |

New top-level guidance belongs in the map or history index. New decisions and
research belong in their respective indexes. Every repository-authored Markdown
page must be reachable from the root README through local links. Keep the working
tree focused on current guidance and active investigations. Retire completed
milestone records, superseded research and disposable prototypes when their
conclusions have been incorporated. Preserve access to useful evidence through
commit-pinned Git links in the appropriate index; repair inbound links and remove
obsolete project references in the same change. Git retains the original files.

An old pending gate is not a current task. Do not update old results to make them
look current. Promote durable rules out of a historical runbook into one current
guide before retiring it. Retain accepted decisions and supersession links that
still explain current architecture. Frozen schema declarations are executable
compatibility contracts, not disposable historical documentation.

## Reconcile documentation and tickets

For a reconciliation pass, compare the current checkout and merged PRs with
open GitHub Issues, native dependencies and sub-issues, and published release
evidence. An issue body or readiness label can lag its actual blocker graph.
Update roadmap checkboxes and source pointers after verifying their completion;
keep design acceptance distinct from feature delivery and release acceptance.
Link published implementation children from their gate and add the real native
blockers. Track concrete defects found in completed refactors separately instead
of leaving them only in characterization tests or future design prose.

Verify a published artifact's version, minimum platform and architectures before
changing download claims. A working source version or successful build is not
evidence of distribution. For retired local documents, verify each commit-pinned
replacement against the named Git tree and repair references in active tickets
as well as repository pages. Retain the original candidate's limitations.

Run the repository checks after reconciliation. Report which hosted settings or
external evidence were actually inspected; local configuration checks alone
cannot establish their current state. Changes to product decisions remain with
their design tickets, even when this pass discovers missing or stale planning.

## Validation

```sh
ruby Tools/Tests/check_documentation_test.rb
ruby Tools/check-documentation.rb
```

Xcode Cloud's post-clone verification runs both before dependencies execute.
The checker covers root Markdown, `docs/`, tool READMEs, and the two DocC maps.
It checks local file links and ATX heading fragments, reference definitions,
reachability, and index classification. Fenced
examples, inline code, and DocC symbol references are not Markdown file links.
External URLs are deliberately not fetched. Skill-internal templates are not
repository-authored documentation and have their own workflow semantics.

Current implementation tables are compared with native project targets,
KitchenKit responsibility directories, current schema alias, checked-in test
plans and scheme references, and the localization inventory. Deprecated module
and target names are rejected in current guidance; historical records, ADRs and
research may retain them. Local historical links must still resolve; inspect
commit-pinned links against the named Git tree because external URLs are not
fetched by the checker.

The guard is bounded, not a general Markdown renderer or semantic proof. It
supports the repository's inline/reference links, ATX headings and explicit HTML
anchors; use percent-encoded spaces or angle-bracket link targets for paths with
spaces. Review prose, resource ownership, frozen schema semantics, and real
behavior against source. Existing project/localization/inventory checkers own
the deeper source invariants. A source-only guard cannot inspect hosted Xcode
Cloud settings or prove linguistic quality, accessibility, or global sync.

## Earlier audit evidence

The completed September 2026 consolidation and validation ledger remains in
[Git history](https://github.com/ctwelve/KitchenMemory/blob/4a930de84c1180ad2736598c89dec38f200af2c7/docs/documentation-maintenance.md#audit-boundary-september-2026).
Current topology belongs to [implementation architecture](implementation-architecture.md),
localization to [its contract](localization-architecture.md), and release
requirements to [release engineering](release-engineering.md).
