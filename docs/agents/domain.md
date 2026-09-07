# Find the relevant development guidance

Before changing domain concepts, architecture, or product behavior:

1. Use [the documentation map](../README.md) to find the affected contract.
2. Read [CONTEXT.md](../../CONTEXT.md) when naming or changing domain concepts.
3. Follow the relevant [accepted decisions](../adr/README.md), including their
   amendment or supersession notices. Surface conflicts instead of silently
   overriding a decision.

Read only the topical documents needed for the change. Research and milestone
records supply evidence, not current instructions; the live GitHub issue graph
owns implementation scope and prerequisites.

Repository documentation owns architecture, product contracts, policy, and
history. The existing [KitchenKit](../../KitchenKit/KitchenKit.docc/KitchenKit.md)
and [application](../../KitchenMemory/Documentation.docc/Documentation.md) DocC
catalogs explain actual symbols, ownership, and code entry points. Keep those
small newcomer guides complementary to repository docs.

The maintained skill library is `.agents/skills/`; `skills/` is a compatibility
symlink to it. Edit only the maintained copy. For documentation routing or
validation changes, see [the maintenance contract](../documentation-maintenance.md).
