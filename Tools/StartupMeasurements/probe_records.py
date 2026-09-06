"""Bounded, privacy-safe records and acceptance checks for signed probes."""
import json
import math

MILESTONES = frozenset('''appEntry processCreated debuggerAttached debuggerDetached
    debuggerUnknown startupSurfacePresented preparationStarted preparationRetired
    preparationReady preparationUnavailable preferencesStarted ownerStarted ownerReady
    containerStarted containerReady kitchenReady libraryProjectionCreated libraryReadStarted
    libraryLocallyReadable fixtureSeeded fixtureEmitted fixtureLocallyReadable
    fixtureNotYetReadable fixtureImportedReadable receivingEvidenceAlreadyLocal
    receivingStoreEvidenceReadable receivingEvidenceNotObserved measurementEnded
    fixtureUnavailable'''.split())


def decode(line):
    """Discard everything except the fixed milestone vocabulary and finite timings."""
    prefix = 'KM_STARTUP '
    if not line.strip().startswith(prefix):
        return None
    try:
        record = json.loads(line.strip()[len(prefix):])
    except (ValueError, TypeError):
        return None
    if not isinstance(record, dict) or set(record) != {'milestone', 'secondsFromAppEntry'}:
        return None
    name, elapsed = record['milestone'], record['secondsFromAppEntry']
    if not isinstance(name, str) or name not in MILESTONES:
        return None
    if type(elapsed) not in (int, float) or not math.isfinite(elapsed):
        return None
    if elapsed < 0 and name != 'processCreated':
        return None
    return record


def complete(records, debugger, action):
    names = [record['milestone'] for record in records]
    if len(names) > 32 or len(set(names)) != len(names):
        return False
    required = {'appEntry', 'processCreated', 'startupSurfacePresented', 'preparationStarted',
                'libraryReadStarted', 'libraryLocallyReadable', 'preparationReady', 'measurementEnded',
                'debuggerAttached' if debugger else 'debuggerDetached'}
    if action in ('measure', 'seed'):
        required.add('fixtureLocallyReadable')
    forbidden = {'fixtureUnavailable', 'preparationUnavailable', 'debuggerUnknown',
                 'debuggerDetached' if debugger else 'debuggerAttached'}
    if not required.issubset(names) or forbidden.intersection(names):
        return False
    times = {record['milestone']: record['secondsFromAppEntry'] for record in records}
    return (times['processCreated'] <= 0
            and times['startupSurfacePresented'] <= times['preparationStarted']
            and times['libraryReadStarted'] <= times['libraryLocallyReadable'] <= times['measurementEnded'])
