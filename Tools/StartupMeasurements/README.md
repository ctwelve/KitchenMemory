# Signed startup measurements

This bounded investigation tool for #72 instruments a disposable source archive.
It is absent from the Xcode project and ordinary products. It adds no application
analytics or retained timing history. Only the `Develop` configuration and
`iCloud.net.ctwelve.dev.KitchenMemory` container are permitted by the probe.

## Prepare and build

Run `python3 Tools/StartupMeasurements/prepare.py --ref <commit> --output
/private/tmp/KitchenMemoryStartup-<name>` from the checkout. The output must be
new. Anchor checks reject source changes that would invalidate instrumentation.
`startup-source.json` records the source commit and overlay hashes.

Build the copied project's `KitchenMemory` scheme, `Develop` configuration,
with Xcode signing for My Mac and generic iOS hardware. Install the signed iOS
app with Xcode or `devicectl`. This temporarily replaces the Develop app, retaining
its ordinary data. Production is unaffected. Restore an ordinary signed Develop
build from the real checkout after the exercise. Without measurement environment
variables, tapping the probe app follows ordinary startup and does not auto-exit.

The copied store factory permits a separate URL for a private-cloud store. This
location-only exception is never applied to the working source. It retains the
same versioned schema, migration plan, private database, and repository paths.
Stores live in the app sandbox's temporary `KitchenMemoryStartup/<replica>`
directory. Installation or OS cleanup can remove them: seed again after install,
and reject any warm-library sample missing `fixtureLocallyReadable`.

## Run

`measure.py --help` describes one bounded launch. Supply an exact signed `--app`,
`--platform mac|device`, `--store local|cloud`, one generated `--run` UUID, a
`--replica` name, and a new `--output` path outside the repository. For Mac, supply
`--products` pointing to the framework products directory. For physical devices,
supply the discovered CoreDevice UUID with `--device`. Keep devices unlocked.
Use `--debugger` for LLDB-attached launches; omitted means detached. Device runs
wait for an actual debugger stop before continuing. The probe independently
reports `debuggerAttached` or `debuggerDetached`; mismatches invalidate the run.

Actions:

- `seed`: write twenty synthetic Recipes, reload the ordinary library projection,
  and hold cloud exporters for sixty seconds (three seconds for local stores).
- `measure`: load the existing twenty-Recipe fixture and hold for three seconds.
  Missing fixtures invalidate the sample.
- `receive`: observe ordinary library refresh for up to 180 one-second intervals.
- `emit`: write one additional deterministic synthetic Recipe, then hold a cloud
  exporter for sixty seconds.

Use the same run UUID across replicas for one cross-device experiment. Start a
fresh receiver, then emit from another device. A delta present at initial read is
`receivingEvidenceAlreadyLocal`, never a later-import measurement. A delta absent
initially and subsequently visible through the app's ordinary refresh is
`receivingStoreEvidenceReadable`. `receivingEvidenceNotObserved` is a bounded
non-observation, not a synchronization failure or claim of global completion.
The receiver loop never directly reloads the repository or waits in app startup.

Cloud fixtures use only deterministic synthetic IDs and titles. The private
Development container may contain other development records; neither their
contents nor account identifiers are recorded. Do not delete or reset that
container as part of this exercise. Synthetic fixtures can remain for subsequent
bounded trials; this tool does not authorize deleting unrelated records.

## Interpret

Only bounded `KM_STARTUP` milestone records are retained, at most 32 per launch.
Times use monotonic uptime relative to app entry. `processCreated` is a negative
elapsed offset derived once from the kernel's process start timestamp. For a
suspended device launch, process age includes the intentional debugger attach
wait: do not label that interval application work. Host wall time also includes
launch services, debugger setup, observation holds, and console transport.

`startupSurfacePresented` uses the existing draw/display-link startup observer;
it is a display-boundary approximation, not a hardware scanout timestamp.
`libraryReadStarted` and `libraryLocallyReadable` bracket the first successful
ordinary library read. `libraryProjectionCreated` only marks model construction.
`preparationReady` follows the remaining application graph preparation. The
fixture milestone verifies the twenty expected synthetic Recipe identities.
Imported evidence is timed independently through the ordinary receiving-store
refresh path. These narrow probes do not identify every framework subphase or
prove performance for large libraries, offline accounts, or cold OS caches.

Record toolchain, OS/device classes, exact source and overlay hashes, signing
configuration, sample counts/ranges, and ownership limits in a conclusions
document. Keep raw logs and timing JSON outside the repository. A successful
launch alone does not prove a complete matrix or an observed cloud import.
