# Kitchen Memory 0.3.1 alpha

<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: MIT
-->

This bug-fix release corrects Kitchen reset when the bundled recipe pack is disabled.
Reset now leaves the Kitchen empty instead of reinstalling the default recipes,
and preserves the first-run sample choice. The reset confirmation explains when
samples will be restored in all six supported locales.

This remains alpha software. Existing alpha data and interface limitations apply;
keep independent copies of anything that matters. No schema change or new feature
is included. macOS distribution remains a notarized download; this release does
not introduce iOS tester distribution or an App Store submission.
