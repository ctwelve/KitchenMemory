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

parser = argparse.ArgumentParser()
parser.add_argument('--platform', choices=['mac', 'device'], required=True)
parser.add_argument('--app', type=Path, required=True)
parser.add_argument('--products', type=Path)
parser.add_argument('--device')
parser.add_argument('--debugger', action='store_true')
parser.add_argument('--store', choices=['local', 'cloud'], required=True)
parser.add_argument('--action', choices=['seed', 'measure', 'emit', 'receive'], default='measure')
parser.add_argument('--run', type=uuid.UUID, required=True)
parser.add_argument('--replica', required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
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
    command = ['xcrun', 'devicectl', 'device', 'process', 'launch', '--device', args.device,
               '--console', '--terminate-existing', '--environment-variables', json.dumps(env)]
    if args.debugger:
        command.append('--start-stopped')
    command.append('net.ctwelve.dev.KitchenMemory')
    launch = start(command)
    if args.debugger:
        # The suspended probe is the only KitchenMemory process after launch's
        # terminate-existing action. Consume the documented JSON process API.
        with tempfile.TemporaryDirectory(prefix='KitchenMemoryStartup-query-') as directory:
            snapshot = Path(directory) / 'processes.json'
            pid = None
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline and pid is None:
                query = subprocess.run(['xcrun', 'devicectl', 'device', 'info', 'processes', '--device',
                                        args.device, '--json-output', str(snapshot)], capture_output=True)
                if query.returncode == 0:
                    result = json.loads(snapshot.read_text()).get('result', {})
                    for process in result.get('runningProcesses', []):
                        if str(process.get('executable', '')).endswith('/KitchenMemory'):
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
                for process in processes:
                    process.terminate()
                raise RuntimeError('Debugger did not confirm the suspended process was attached')
            debugger.stdin.write('continue\n')
            debugger.stdin.flush()

records = []
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
if args.platform == 'device' and args.debugger:
    debugger.stdin.write('quit\n')
    debugger.stdin.flush()
for process in processes:
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        process.terminate()
        process.wait(timeout=10)
passed = probe_records.complete(records, args.debugger, args.action)
result = {'platform': args.platform, 'debugger': args.debugger, 'store': args.store,
          'action': args.action, 'syntheticRun': str(args.run), 'replica': args.replica,
          'wallSeconds': time.monotonic() - started, 'complete': passed, 'markers': records}
args.output.write_text(json.dumps(result, indent=2)+'\n')
raise SystemExit(0 if passed else 1)
