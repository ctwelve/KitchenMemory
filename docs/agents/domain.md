# Domain docs

How the engineering skills consume this repository's domain documentation while exploring the codebase.

## Before exploring, read these

- **`CONTEXT.md`** at the repository root when it exists.
- **`Documentation.docc/Articles/Decisions/`**: read ADRs that touch the area about to be changed.
- **`Documentation.docc/Articles/`**: read topical architecture and product articles relevant to the work.

If `CONTEXT.md` does not exist, proceed silently. The `/domain-modeling` skill creates it lazily when terms or decisions are resolved.

## File structure

Kitchen Memory is a single-context repository:

```text
/
├── CONTEXT.md                                  # Created lazily when needed
└── Documentation.docc/
    └── Articles/
        ├── Decisions/                          # Architecture decision records
        └── *.md                                # Product and architecture articles
```

Keep ADRs in the existing DocC decision catalog rather than introducing a parallel `docs/adr/` directory.

## Use the glossary's vocabulary

When output names a domain concept in an issue title, refactor proposal, hypothesis, or test name, use the term as defined in `CONTEXT.md`.

If the needed concept is absent, reconsider whether the term belongs to the project or note the gap for `/domain-modeling`.

## Flag ADR conflicts

If output contradicts an existing ADR, surface the conflict explicitly rather than silently overriding it.
