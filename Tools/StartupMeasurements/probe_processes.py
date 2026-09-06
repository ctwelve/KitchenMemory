"""Failure-safe cleanup for temporary measurement controllers."""
import subprocess


def cleanup(processes, device=None, pid=None):
    problems = []
    if device and pid is not None:
        try:
            result = subprocess.run(
                ['xcrun', 'devicectl', 'device', 'process', 'terminate', '--device', device,
                 '--pid', str(pid), '--kill'], capture_output=True, timeout=10)
            if result.returncode != 0:
                problems.append('deviceTerminationUnconfirmed')
        except subprocess.TimeoutExpired:
            problems.append('deviceTerminationTimedOut')
        except OSError:
            problems.append('deviceTerminationUnavailable')
    for process in processes:
        try:
            if process.poll() is None:
                process.terminate()
            try:
                process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=2)
        except (OSError, subprocess.TimeoutExpired):
            problems.append('controllerReapUnconfirmed')
    return problems


def develop_executable(snapshot):
    apps = [app for app in snapshot.get('result', {}).get('apps', [])
            if app.get('bundleIdentifier') == 'net.ctwelve.dev.KitchenMemory']
    if len(apps) != 1 or not isinstance(apps[0].get('url'), str):
        raise ValueError('Expected one installed Develop app')
    return apps[0]['url'].rstrip('/') + '/KitchenMemory'
