import json
import unittest
import probe_records


class ProbeRecordsTests(unittest.TestCase):
    def fixture(self):
        names = ['appEntry', 'processCreated', 'debuggerDetached', 'startupSurfacePresented',
                 'preparationStarted', 'preparationReady', 'libraryReadStarted',
                 'libraryLocallyReadable', 'fixtureLocallyReadable', 'measurementEnded']
        return [{'milestone': name, 'secondsFromAppEntry': -0.1 if name == 'processCreated' else i / 10}
                for i, name in enumerate(names)]

    def test_requires_actual_read_and_expected_fixture(self):
        records = self.fixture()
        self.assertTrue(probe_records.complete(records, False, 'measure'))
        for missing in ('libraryReadStarted', 'libraryLocallyReadable', 'fixtureLocallyReadable'):
            self.assertFalse(probe_records.complete([r for r in records if r['milestone'] != missing], False, 'measure'))

    def test_requested_debugger_is_not_attached_proof(self):
        self.assertFalse(probe_records.complete(self.fixture(), True, 'measure'))

    def test_duplicate_and_out_of_order_read_are_invalid(self):
        records = self.fixture()
        self.assertFalse(probe_records.complete(records + records[:1], False, 'measure'))
        records[6]['secondsFromAppEntry'] = 10
        self.assertFalse(probe_records.complete(records, False, 'measure'))

    def test_discards_private_unknown_and_malformed_output(self):
        for line in ['private framework log', 'KM_STARTUP []', 'KM_STARTUP broken',
                     'KM_STARTUP {"milestone":"account identifier","secondsFromAppEntry":0}',
                     'KM_STARTUP {"milestone":"appEntry","secondsFromAppEntry":NaN}',
                     'KM_STARTUP {"milestone":"appEntry","secondsFromAppEntry":true}',
                     'KM_STARTUP {"milestone":"appEntry","secondsFromAppEntry":0,"private":"content"}']:
            self.assertIsNone(probe_records.decode(line))
        record = self.fixture()[1]
        self.assertEqual(probe_records.decode('KM_STARTUP ' + json.dumps(record)), record)


if __name__ == '__main__':
    unittest.main()
