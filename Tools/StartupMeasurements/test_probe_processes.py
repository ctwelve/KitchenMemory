import subprocess
import sys
import unittest
from unittest.mock import patch
import probe_processes


class ProbeProcessesTests(unittest.TestCase):
    def test_reaps_real_controller_when_device_cleanup_times_out(self):
        process = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(300)'])
        try:
            with patch('probe_processes.subprocess.run', side_effect=subprocess.TimeoutExpired('query', 10)) as run:
                problems = probe_processes.cleanup([process], 'synthetic-device', 123)
            self.assertEqual(problems, ['deviceTerminationTimedOut'])
            self.assertIsNotNone(process.poll())
            self.assertEqual(run.call_args.kwargs['timeout'], 10)
            self.assertIn('--kill', run.call_args.args[0])
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()

    def test_does_not_target_any_device_without_a_known_pid(self):
        with patch('probe_processes.subprocess.run') as run:
            self.assertEqual(probe_processes.cleanup([], 'synthetic-device'), [])
            run.assert_not_called()

    def test_identifies_develop_even_with_same_named_production_app(self):
        snapshot = {'result': {'apps': [
            {'bundleIdentifier': 'net.ctwelve.KitchenMemory', 'url': 'file:///Production/KitchenMemory.app/'},
            {'bundleIdentifier': 'net.ctwelve.dev.KitchenMemory', 'url': 'file:///Develop/KitchenMemory.app/'}]}}
        self.assertEqual(probe_processes.develop_executable(snapshot),
                         'file:///Develop/KitchenMemory.app/KitchenMemory')
        with self.assertRaises(ValueError):
            probe_processes.develop_executable({'result': {'apps': snapshot['result']['apps'][:1]}})


if __name__ == '__main__':
    unittest.main()
