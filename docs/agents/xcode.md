# Xcode agent workflow

## Run native tests in Xcode

Use Xcode's Test action for native application and UI tests. Xcode manages the
test runner's signing and launch context. A stalled terminal-launched runner,
including a signed `xcodebuild` attempt, is not sufficient evidence that native
testing is blocked. Retry through the Xcode application before drawing that
conclusion.

The standalone framework coverage workflow remains documented in
[continuous integration](../continuous-integration.md). Its clean-build evidence
and exact line gate serve a different purpose from native runner validation.

## Connect through the MCP server

1. Open the repository's project in Xcode and wait for it to load.
2. Discover the installed bridge with `xcrun --find mcpbridge`; consult
   `xcrun mcpbridge --help` for the current interface. The server command is
   `xcrun mcpbridge`, using standard MCP JSON-RPC over stdin/stdout.
3. In Xcode Settings > Intelligence, enable external-agent access to Xcode tools
   if it is not already enabled. Xcode may also display an access prompt for a
   new connection. Ask the user to allow that prompt when needed; an unanswered
   connection is not a test failure.
4. Keep one bridge process alive for discovery and execution. A custom MCP client
   initializes the connection, sends `notifications/initialized`, then requests
   `tools/list`. Closing the process immediately after discovery can require
   another authorization when reconnecting.
5. Use `XcodeListWindows` to obtain the current workspace tab identifier. Select
   the tab matching this checkout; identifiers are session state, not constants.
6. Verify the intended active scheme and run destination in Xcode. Use
   `GetTestList` to discover actual test targets and identifiers. `RunSomeTests`
   accepts the returned target name and identifier for focused checks;
   `RunAllTests` runs the active scheme's active test plan.
7. Record the completed result, counts, and returned summary/log paths. Use
   `GetBuildLog` for build failures. Starting an action or receiving an empty
   issue list is not a passing test result.

`mcpbridge` discovers the running Xcode instance automatically. If more than one
instance is open, its documented `MCP_XCODE_PID` environment variable selects
the intended process. Discover tool schemas from the live server rather than
assuming that a tool's arguments or the active scheme stayed unchanged.

Apple documents external-agent setup in
[Giving external agents access to Xcode](https://developer.apple.com/documentation/xcode/giving-external-agents-access-to-xcode).

## Xcode scripting fallback

If the MCP connection is unavailable, Xcode's documented AppleScript `test`
command also invokes the application's own Test action. This is an application
API, not a replacement `xcodebuild` invocation. Discover the live workspace,
schemes, and destinations before selecting them. The installed
`Xcode.app/Contents/Resources/Xcode.sdef` describes the scripting interface.

For this workspace, after verifying those names:

```applescript
tell application "Xcode"
  tell workspace document "KitchenMemory.xcodeproj"
    set active scheme to first scheme whose name is "KitchenMemory"
    set active run destination to first run destination whose name is "My Mac"
    set testResult to test
    return {id of testResult, status of testResult}
  end tell
end tell
```

This command returns before testing finishes. Retain the action ID, then inspect
`last scheme action result` for the same ID until `completed` is true. Report its
`status`, `build errors`, and `test failures`; preserve the build log when needed
for diagnosis. Avoid overlapping native Mac test actions, which share an
application lifecycle.
