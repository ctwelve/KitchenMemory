# Consolidate business code in KitchenKit

- Status: Accepted

Kitchen Memory builds Domain, Import, Logic, and Persistence into one native
framework and Swift module named `KitchenKit`. Those names remain responsibility
folders and architectural seams inside the module; clients import `KitchenKit`
and use naturally named types rather than `KM` prefixes or artificial
`KitchenKit.Logic` nesting. Every current client needs the full cluster, so one
framework gives callers a smaller interface and removes link products that do
not represent independently consumable capabilities.

This supersedes the separate-business-framework portions of ADRs 0003, 0007,
and 0009, but not their domain/persistence separation or testing-investment
policy. ADR 0013 later supersedes ADR 0009's native application split. One
`KitchenKitTests` target preserves responsibility-based
test folders and exact business-logic coverage through a minimal shared scheme
and checked-in `KitchenKit.xctestplan`. Like the native application scheme,
the framework scheme builds only its primary product and leaves test-target
membership solely to its referenced plan. The multiplatform application plan
contains its hosted correctness target and the shared UI smoke target; its
default Test action uses the disposable `Testing` host on either destination.

Keeping four compiler-enforced modules was rejected because their public
interfaces and dependency order leaked one business implementation as four
products. Prefixing them as `KMLogic` and peers would preserve that cost;
`KitchenKit.Logic` would require nesting declarations rather than create Swift
submodules. A future capability should become a peer framework only when it has
an independent consumer, dependency footprint, or evolution reason. Revisit
this decision if the unified target produces a measured incremental-build
regression or a responsibility gains a real independent client.
