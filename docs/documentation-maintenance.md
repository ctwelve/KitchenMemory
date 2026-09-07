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

The broad consolidation landed in [PR 173](https://github.com/ctwelve/KitchenMemory/pull/173)
after release preparation #124. The final #85 reconciliation uses merged
[PR 174](https://github.com/ctwelve/KitchenMemory/pull/174), commit
`ac9095ba3b0cc20fb85227e50420c808f39175de`, after #125 completed the version,
dependency, license, and signed-product review.

The final pass checked current guidance against the implemented presentation
folders, five targets, two shared schemes, three test plans, four KitchenKit
responsibility roots, V7 schema alias, six supported locales, resource ownership,
and committed package graph. [Implementation architecture](implementation-architecture.md),
[localization](localization-architecture.md), and [the software inventory](../DEPENDENCIES.md)
remain the owners of those details. The working source is 0.3.0; the root README
continues to describe the published alpha rather than imply a new distribution.
The [dependency evidence](release-dependencies-0.3.md) records the actual signed
resources, privacy manifests, linkage, and archive-path correction.

Current Recipe authority, Folder/Tag, and maintenance guidance agrees with the
retained evidence and repository seams. [Device retirement](records-maintenance.md#device-retirement-boundary)
remains beta-wayfinder work; no device roster or cross-device retirement
protocol is claimed. Historical ADRs, research, schema declarations, and release
records retain their paths and dated results through their indexes. Old version
numbers in those records are evidence, not stale instructions to overwrite.

The maintainer restored the strict Cloud PR requirement. The
[current CI boundary](continuous-integration.md#github-enforcement-boundary)
records the two trusted required checks; local UI validation remains applicable
while Cloud UI tests are suspended. This reconciliation changes documentation
only and performs no GitHub-protection or Cloud-workflow mutation.

Fresh verification on September 7, 2026 passed all 92 Ruby contract tests
(334 assertions), including the documentation guard's 13 tests (42 assertions),
and all seven Python tool tests. Documentation, localization, project/resource,
inventory, and ordinary untagged-release checks passed. SwiftLint 0.65.1 reported
zero violations across 347 Swift files. The checked-in post-clone workflow runs
the documentation guard and its tests during ordinary CI.

No application, framework, test, resource, dependency, or build-setting input
changes in this final pass. The native suites, exact coverage, static analysis,
and signed-product checks from [#125](release-dependencies-0.3.md#validation-ledger)
therefore remain applicable to the unchanged source. The comprehensive beta
accessibility matrix is deferred under #168, not reported as passed. The
remaining [#126 acceptance packet](https://github.com/ctwelve/KitchenMemory/issues/126)
owns synthetic scenario assembly and final Mac-only alpha acceptance.

This audit retains only repository metadata and concise validation results;
private debugging material, account identifiers, Recipe content, and raw logs
are excluded.
