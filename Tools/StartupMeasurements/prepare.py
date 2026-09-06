#!/usr/bin/env python3
"""Prepare an instrumented, disposable source copy; never edit the working app."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import tarfile

parser = argparse.ArgumentParser()
parser.add_argument('--output', required=True, type=Path)
parser.add_argument('--ref', default='HEAD')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
out = args.output.resolve()
if out.exists() or not str(out).startswith('/private/tmp/KitchenMemoryStartup-'):
    parser.error('output must be a new /private/tmp/KitchenMemoryStartup-* directory')
sha = subprocess.check_output(['git', 'rev-parse', args.ref], cwd=root, text=True).strip()
archive = subprocess.check_output(['git', 'archive', sha], cwd=root)
out.mkdir(parents=True)
with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
    for member in bundle.getmembers():
        if Path(member.name).is_absolute() or '..' in Path(member.name).parts or member.issym() or member.islnk():
            raise RuntimeError('Unsafe archive member')
    bundle.extractall(out)

def replace(path, before, after, count=1):
    file = out / path
    text = file.read_text()
    if text.count(before) != count:
        raise RuntimeError(f'Instrumentation anchor changed: {path}')
    file.write_text(text.replace(before, after))

app = 'KitchenMemory/Composition/'
replace(app+'KitchenMemoryApp.swift', '    _startup = StateObject',
        '    StartupMeasurement.start()\n    _startup = StateObject')
replace('KitchenMemory/Features/Startup/AppStartupCoordinator.swift',
        '    live.record(milestone)',
        '    StartupMeasurement.mark(String(describing: milestone))\n    live.record(milestone)')
replace(app+'AppRuntime.swift', '      let durablePreferences = DefaultsKitchenPreferencesStore(',
        '      StartupMeasurement.mark("preferencesStarted")\n      let durablePreferences = DefaultsKitchenPreferencesStore(')
replace(app+'AppRuntime.swift', '          durablePreferences.personalCloudSynchronizationEnabled',
        '          (StartupMeasurement.isActive ? StartupMeasurement.cloudEnabled : durablePreferences.personalCloudSynchronizationEnabled)')
replace(app+'AppRuntime.swift', '      let ownerID = try await KitchenOwnerIdentity.resolve(plan: plan, inputs: inputs)',
        '      StartupMeasurement.mark("ownerStarted")\n      let ownerID = try await KitchenOwnerIdentity.resolve(plan: plan, inputs: inputs)\n      StartupMeasurement.mark("ownerReady")')
replace(app+'AppRuntime.swift', '      return app\n',
        '      StartupMeasurement.prepared(app)\n      return app\n')
replace(app+'AppRuntime.swift', '    modelContainer = try KitchenMemorySchema.makeContainer(',
        '    StartupMeasurement.mark("containerStarted")\n    modelContainer = try KitchenMemorySchema.makeContainer(')
replace(app+'AppRuntime.swift', '      inMemory: plan.store.isInMemory,\n      synchronization:',
        '      inMemory: plan.store.isInMemory,\n      storeURL: StartupMeasurement.storeURL,\n      synchronization:')
replace(app+'AppRuntime.swift', '    recipeRepository = SwiftDataRecipeRepository(modelContainer: modelContainer)',
        '    StartupMeasurement.mark("containerReady")\n    recipeRepository = SwiftDataRecipeRepository(modelContainer: modelContainer)')
replace(app+'AppRuntime.swift', '    let library = RecipeLibrary(',
        '    StartupMeasurement.mark("kitchenReady")\n    let library = RecipeLibrary(')
replace(app+'AppRuntime.swift', '    cookingSessionRepository = SwiftDataCookingSessionRepository(',
        '    StartupMeasurement.mark("libraryProjectionCreated")\n    cookingSessionRepository = SwiftDataCookingSessionRepository(')
replace('KitchenMemory/Features/RecipeLibrary/RecipeLibraryModel.swift',
        '      let contents = try library.load()',
        '      if !hasLoaded { StartupMeasurement.mark("libraryReadStarted") }\n      let contents = try library.load()')
replace('KitchenMemory/Features/RecipeLibrary/RecipeLibraryModel.swift',
        '      hasLoaded = true\n      if !recipes.isEmpty',
        '      StartupMeasurement.libraryDidLoad()\n      hasLoaded = true\n      if !recipes.isEmpty')
# Location-only exception in the disposable instrumented copy, using the exact
# same schema, migration plan, and private Development CloudKit adapter.
replace('KitchenKit/Persistence/KitchenMemorySchema.swift',
        'guard !inMemory, storeURL == nil else {', 'guard !inMemory else {')
shutil.copyfile(root/'Tools/StartupMeasurements/StartupMeasurement.swift.template',
                out/'KitchenMemory/Composition/StartupMeasurement.swift')
provenance = {'sourceCommit': sha, 'kind': 'temporary-instrumented-Develop',
              'overlaySHA256': {name: hashlib.sha256((root/'Tools/StartupMeasurements'/name).read_bytes()).hexdigest()
                                for name in ['prepare.py', 'StartupMeasurement.swift.template']}}
(out/'startup-source.json').write_text(json.dumps(provenance, indent=2)+'\n')
print(out)
