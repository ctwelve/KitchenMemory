# Nonshipping interchange experiment

Synthetic fixtures for the accompanying Recipe/Kitchen interchange research.
This is an admission and preservation experiment, not a product importer.

Run `python3 experiment.py` here. It regenerates the JSON/ZIP fixtures and
`results.json`; successful completion reports 24 checks. Only Python's standard
library is needed. No files outside this directory are read or written.

The intentionally reduced limits are defined in `LIMIT`. The experiment only
validates its explicit identity inventory, not every domain identity nested in
the illustrative Recipe or evidence placeholders. It does not implement actual
KitchenKit codecs, database commits, image decoding or complete domain graph
validation. `results.json` records observed allocation peaks, which vary across
Python versions and are not production memory guarantees. ZIP timestamps also
vary; the generated ZIP is not a canonical-byte reproducibility artifact.

See the accompanying research note for production hypotheses, resource limits,
import semantics and the tests still required before shipping.
