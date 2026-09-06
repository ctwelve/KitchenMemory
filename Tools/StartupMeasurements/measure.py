#!/usr/bin/env python3
"""Run one signed probe; retain only its bounded synthetic milestone records."""
import argparse
import json
import os
from pathlib import Path
import queue
import subprocess
import tempfile
import threading
import time
import uuid
import probe_records
import probe_processes

parser = argparse.ArgumentParser()
parser.add_argument('--platform', choices=['mac', 'device'], required=True)
parser.add_argument('--app', type=Path, required=True)
parser.add_argument('--products', type=Path)
parser.add_argument('--device', type=uuid.UUID)
parser.add_argument('--debugger', action='store_true')
parser.add_argument('--store', choices=['local', 'cloud'], required=True)
parser.add_argument('--action', choices=['seed', 'measure', 'emit', 'receive'], default='measure')
parser.add_argument('--run', type=uuid.UUID, required=True)
parser.add_argument('--replica', required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
args.device = str(args.device) if args.device else None
if args.output.exists():
    parser.error('output already exists')
if args.platform == 'device' and not args.device:
    parser.error('device ID is required')
env = {'KM_STARTUP_RUN': str(args.run), 'KM_STARTUP_REPLICA': args.replica,
       'KM_STARTUP_STORE': args.store, 'KM_STARTUP_ACTION': args.action}
base_environment = dict(os.environ, **env)
if args.products:
    base_environment['DYLD_FRAMEWORK_PATH'] = str(args.products)
lines = queue.Queue()
processes = []

def start(command):
    process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               text=True, env=base_environment)
    processes.append(process)
    def read():
        for line in process.stdout:
            lines.put(line)
    threading.Thread(target=read, daemon=True).start()
    return process

started = time.monotonic()
records = []
pid = None
device_launch_started = False
failure = None
cleanup_problems = []
try:
    if args.platform == 'mac':
        binary = args.app / 'Contents/MacOS/KitchenMemory'
        command = [str(binary)]
        if args.debugger:
            target_env = dict(env)
            if args.products:
                target_env['DYLD_FRAMEWORK_PATH'] = str(args.products)
            setting = 'settings set target.env-vars ' + ' '.join(json.dumps(key+'='+value) for key,value in target_env.items())
            command = ['xcrun', 'lldb', '--batch', '-o', 'settings set target.disable-aslr false',
                       '-o', setting, '-o', 'run', '-o', 'quit', '--', str(binary)]
        launch = start(command)
    else:
        if args.debugger:
            with tempfile.TemporaryDirectory(prefix='KitchenMemoryStartup-app-') as directory:
                snapshot = Path(directory) / 'app.json'
                query = subprocess.run(
                    ['xcrun', 'devicectl', 'device', 'info', 'apps', '--device', args.device,
                     '--filter', "bundleIdentifier == 'net.ctwelve.dev.KitchenMemory'",
                     '--json-output', str(snapshot)], capture_output=True, timeout=10)
                if query.returncode != 0:
                    raise RuntimeError('Installed Develop app could not be identified')
                executable = probe_processes.develop_executable(json.loads(snapshot.read_text()))
        command = ['xcrun', 'devicectl', 'device', 'process', 'launch', '--device', args.device,
                   '--console', '--terminate-existing', '--environment-variables', json.dumps(env)]
        if args.debugger:
            command.append('--start-stopped')
        command.append('net.ctwelve.dev.KitchenMemory')
        launch = start(command)
        device_launch_started = True
        if args.debugger:
            # Match the exact installed Develop bundle, never a process name
            # shared by Production or another installation.
            with tempfile.TemporaryDirectory(prefix='KitchenMemoryStartup-query-') as directory:
                snapshot = Path(directory) / 'processes.json'
                pid = None
                deadline = time.monotonic() + 30
                while time.monotonic() < deadline and pid is None:
                    query = subprocess.run(['xcrun', 'devicectl', 'device', 'info', 'processes', '--device',
                                            args.device, '--json-output', str(snapshot)], capture_output=True,
                                           timeout=max(0.1, min(10, deadline - time.monotonic())))
                    if query.returncode == 0:
                        result = json.loads(snapshot.read_text()).get('result', {})
                        for process in result.get('runningProcesses', []):
                            if process.get('executable') == executable:
                                pid = process['processIdentifier']
                    if pid is None:
                        time.sleep(0.2)
                if pid is None:
                    raise RuntimeError('The suspended measurement process was not discoverable')
                debugger = start(['xcrun', 'lldb', '--no-lldbinit', '-o', 'device select '+args.device,
                                  '-o', 'device process attach -p '+str(pid)])
                attach_deadline = time.monotonic() + 60
                attached = False
                while time.monotonic() < attach_deadline:
                    try:
                        line = lines.get(timeout=0.2)
                    except queue.Empty:
                        continue
                    if 'Process '+str(pid)+' stopped' in line:
                        attached = True
                        break
                if not attached:
                    raise RuntimeError('Debugger did not confirm the suspended process was attached')
                debugger.stdin.write('continue\n')
                debugger.stdin.flush()

    deadline = started + 240
    while time.monotonic() < deadline:
        try:
            line = lines.get(timeout=0.2)
        except queue.Empty:
            if all(process.poll() is not None for process in processes):
                break
            continue
        record = probe_records.decode(line)
        if record is not None and len(records) < 32:
            records.append(record)
            print(json.dumps(record), flush=True)
            if record['milestone'] in ['measurementEnded', 'fixtureUnavailable']:
                break
except (OSError, RuntimeError, ValueError, KeyError, subprocess.TimeoutExpired) as error:
    # Exception messages may include device/account paths; retain only the type.
    failure = type(error).__name__
finally:
    ended = any(record['milestone'] == 'measurementEnded' for record in records)
    cleanup_problems = probe_processes.cleanup(
        processes, args.device if not ended else None, pid if not ended else None)
    if device_launch_started and args.debugger and not ended and pid is None:
        cleanup_problems.append('devicePIDUnknownInspectBeforeRetry')
passed = (failure is None and not cleanup_problems
          and probe_records.complete(records, args.debugger, args.action))
result = {'platform': args.platform, 'debugger': args.debugger, 'store': args.store,
          'action': args.action, 'syntheticRun': str(args.run), 'replica': args.replica,
          'wallSeconds': time.monotonic() - started, 'complete': passed, 'markers': records,
          'failure': failure, 'cleanupProblems': cleanup_problems}
args.output.write_text(json.dumps(result, indent=2)+'\n')
raise SystemExit(0 if passed else 1)
