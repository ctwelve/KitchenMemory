<!--
Kitchen Memory
Copyright © 2026 the Kitchen Memory contributors.
SPDX-License-Identifier: GPL-3.0-only
-->

# ADR 0001: Build a native SwiftUI application

- Status: Accepted
- Date: 2026-08-09

## Context

The project is both a real household tool and a vehicle for returning to active
software development. It needs an excellent iPhone cooking experience and may
grow into a powerful Mac recipe-management application with AppleScript,
Shortcuts, drag-and-drop, scanning, and batch automation. A television is also a
useful hands-off recipe display while cooking.

## Decision

Build the application natively in Swift using SwiftUI for iPhone, iPad, and Mac.
Treat macOS as a first-class platform and use AppKit integrations where native
Mac capabilities require them.

Plan a tvOS client as a later, intentionally limited target. It will concentrate
on browsing recipes selected elsewhere and presenting cooking instructions at a
distance. It will share the domain and relevant application services, but it is
not expected to match the editing, import, pantry, or automation capabilities of
the Mac application.

Keep the recipe domain, import pipeline, application use cases, and persistence
interfaces outside the SwiftUI view layer. Automation will call application use
cases rather than drive the UI or access persistence objects.

SwiftData, CloudKit, and the domain boundary were selected subsequently in ADRs
0003 and 0004.

## Consequences

- Apple-platform capabilities can be integrated deeply and idiomatically.
- The Mac app can expose a stable automation API over the same behavior used by
  the graphical app.
- tvOS can reuse the recipe and cooking domain without dictating feature parity
  or compromising the richer Mac interface.
- Domain and importer code can be reused by extensions and a potential command-
  line companion.
- tvOS is planned but is not an initial target; Android, web, and Java clients
  are not initial targets.
- Some SwiftUI abstractions will need intentional AppKit escape hatches.
