# macOS UI-test activation in Xcode Cloud

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

- Status: Public-source research; cause and workaround remain unconfirmed
- Researched: 2026-09-06
- Scope: macOS XCTest foreground activation, Cloud runner limitations, and
  related Tahoe reports

## Conclusion

Other developers report the same activation symptom, and Apple acknowledges
related platform constraints and a likely Tahoe activation bug. The strongest
matching XCTest report concerns a **known locked, self-hosted Mac session**;
the strongest Tahoe report concerns **command-line application activation**.
Neither establishes that an Xcode Cloud failure has the same cause. Preserve
that distinction when deciding whether to change application code or report an
infrastructure bug. [Locked-session report and Apple DTS answer](https://developer.apple.com/forums/thread/840965)
· [Tahoe activation report and Apple DTS answer](https://developer.apple.com/forums/thread/807805)

## Evidence and limits

| Finding | Evidence strength | Applicability |
| --- | --- | --- |
| A developer's locked Mac mini CI session produces `Failed to activate application (current state: Running Background)`. Apple DTS says macOS XCUITest cannot run in a locked session because it requires Accessibility and foreground activation. | Direct report plus Apple explanation, August 2026. | Exact error, but self-hosted CI. The report does not show that Cloud sessions are locked. [Source](https://developer.apple.com/forums/thread/840965) |
| Tahoe intermittently launches apps through `open` or AppleScript without activating them, including system apps. DTS suspects focus-stealing prevention and recommends a bug report; it does not endorse a workaround. | Direct reproducible report plus Apple assessment, November 2025. | Strong adjacent symptom, different launcher. [Source](https://developer.apple.com/forums/thread/807805) |
| FB21087054 documents first-attempt failures and second-attempt successes; a later reporter comment says it still reproduces on macOS 27 beta 3. | Public firsthand feedback mirror, not Apple's internal bug status. | Supports an intermittent platform hypothesis, not a verified XCTest fix. [Report](https://github.com/1024jp/AppleFeedback/issues/87) · [July 2026 follow-up](https://github.com/1024jp/AppleFeedback/issues/87#issuecomment-5015245946) |
| Cloud has a documented macOS test-runner launch issue, FB11302291, with a test-configuration Hardened Runtime workaround. | Official Cloud release notes, November 2024. | Failure to install or launch the runner precedes an already-running application's foreground handoff. Do not apply this workaround merely because both involve launch. [Source](https://developer.apple.com/xcode-cloud/release-notes/) |
| Restricted entitlements can prevent a macOS test host launching in Cloud; DTS identifies provisioning-profile-authorized entitlements as the factor. | Apple DTS, February 2025. | The reported signature is LaunchServices / RunningBoard / launchd spawn failure, distinct from Running Background. [Source](https://developer.apple.com/forums/thread/724812) |

The Cloud-only Accessibility-initialization timeout reported in March 2026 is
another different failure: it concerns iPhone simulators, has no Apple answer,
and does not establish a macOS activation remedy.
[Firsthand report](https://developer.apple.com/forums/thread/818427)

The reviewed Xcode 26.6 and macOS 26.6 release notes do not list a fix for this
foreground-handoff symptom. Absence from release notes is not proof that Apple
has neither fixed nor investigated it.
[Xcode 26.6](https://developer.apple.com/documentation/xcode-release-notes/xcode-26_6-release-notes)
· [macOS 26.6](https://developer.apple.com/documentation/macos-release-notes/macos-26_6-release-notes)

## What the API contract explains

`XCUIApplication.launch()` is synchronous and reports launch-sequence failures
as test failures that halt execution at that point. Consequently, recovery placed
after `launch()` cannot repair a failure that prevents it from returning. This
explains where a diagnostic must observe the failure; it does not identify which
process failed to hand off activation.
[Apple launch contract](https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/launch())

Do not treat `com.apple.loginwindow` being frontmost as a documented lock-state
API. `CGSessionCopyCurrentDictionary()` reports the caller's WindowServer
session; a null result means no Quartz GUI session or a disabled WindowServer.
A non-null result alone does not establish an unlocked desktop. Record only
specific, understood session facts, and distinguish missing data from false.
[Apple session API](https://developer.apple.com/documentation/coregraphics/cgsessioncopycurrentdictionary())

## Recommended next diagnostic

Before another application workaround, inspect one failing Cloud result bundle
alongside a passing bundle from the same source revision if available. Compare
the runner and target process timeline, session availability, activation events,
and any screenshot attached at the failure. The question is whether the target
was unable to activate in an unavailable desktop session, or whether an available
session refused the handoff. This comparison is a proposed diagnostic, not a
known fix. Apple documents downloading action artifacts and rebuilding the same
commit. [Cloud troubleshooting](https://developer.apple.com/documentation/xcode/resolving-common-configuration-and-build-issues)

If the artifacts do not distinguish those cases, prepare build-specific feedback
from Xcode's Report navigator. Apple says this path includes useful build context,
logs, and artifacts; review its attachments before submission. Reference
FB21087054 as a possible relation, not a confirmed duplicate. The current source
research does not support declaring required AppKit linkage, additional activation
calls, or double-launch retries a reliable Cloud workaround.
[Reporting feedback for Xcode Cloud](https://developer.apple.com/documentation/xcode/reporting-feedback-for-xcode-cloud)
