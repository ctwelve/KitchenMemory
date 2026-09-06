# Triage labels

The skills speak in terms of five canonical triage roles. This file maps those roles to the label strings used in this repository's issue tracker.

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |

When a skill mentions a role, use the corresponding label string from this table.

Edit the right-hand column to match the vocabulary used by the issue tracker.

## Upstream parking

`parked:upstream` marks an open issue whose next actionable step depends on an
external maintainer or platform fix. Keep its descriptive labels, such as `bug`,
and remove `ready-for-agent` or `ready-for-human` while it is parked.

Exclude parked issues from active implementation and autonomous ticket-slice
selection. Preserve the upstream report or dependency reference and the condition
for resuming work in the issue. Revisit when upstream provides a relevant update
or the user explicitly requests reassessment; elapsed time alone does not make
the issue actionable. Remove the parking label once the dependency is resolved
or a viable local path is established, then triage readiness again.

For example, #155 remains open while Cloud UI testing is suspended pending the
Apple activation investigation. Restore Cloud UI coverage only after validation
establishes that the blocker is resolved.
