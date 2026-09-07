#!/usr/bin/env python3
# Kitchen Memory
# Copyright © 2026 the Kitchen Memory contributors.
# SPDX-License-Identifier: MIT
"""NONSHIPPING interchange admission experiment. Synthetic inputs only.

This deliberately small profile tests resource/unknown-field hypotheses, not
KitchenKit decoding, domain reconciliation, cryptographic trust or persistence.
"""
import copy
import base64
import hashlib
import io
import json
import pathlib
import stat
import tracemalloc
import uuid
import zipfile

HERE = pathlib.Path(__file__).resolve().parent
LIMIT = dict(json_bytes=65536, json_depth=24, identities=128, edges=256,
             name_bytes=128, folder_depth=16, zip_bytes=131072,
             entries=16, entry_bytes=65536, expanded_bytes=131072, ratio=50)

def require(ok, reason):
    if not ok:
        raise ValueError(reason)

def pairs(items):
    result = {}
    for key, value in items:
        require(key not in result, 'duplicate JSON key')
        result[key] = value
    return result

def parse(raw):
    require(len(raw) <= LIMIT['json_bytes'], 'JSON byte budget')
    # Preflight before recursive parser allocation; braces inside strings ignored.
    depth = 0
    quoted = escaped = False
    for byte in raw:
        if quoted:
            if escaped:
                escaped = False
            elif byte == 92:
                escaped = True
            elif byte == 34:
                quoted = False
        elif byte == 34:
            quoted = True
        elif byte in (123, 91):
            depth += 1
            require(depth <= LIMIT['json_depth'], 'JSON nesting budget')
        elif byte in (125, 93):
            depth -= 1
    return json.loads(raw.decode('utf-8'), object_pairs_hook=pairs,
                      parse_constant=lambda _: require(False, 'nonfinite number'))

def validate(raw):
    doc = parse(raw)
    require(isinstance(doc, dict), 'document object')
    require(doc.get('format') == 'km-interchange-experiment', 'format')
    require(doc.get('major') == 1, 'unsupported major')
    require(doc.get('requiredFeatures') == [], 'unknown required feature')
    require(doc.get('scope') in ('recipe', 'kitchen'), 'scope')
    ids, edges = doc.get('identities'), doc.get('relationships')
    require(isinstance(ids, list) and len(ids) <= LIMIT['identities'], 'identity budget')
    require(isinstance(edges, list) and len(edges) <= LIMIT['edges'], 'edge budget')
    known = set()
    folders = {}
    for item in ids:
        require(isinstance(item, dict), 'identity object')
        identifier = item.get('id')
        require(isinstance(identifier, str) and str(uuid.UUID(identifier)) == identifier, 'UUID')
        require(identifier not in known, 'duplicate identity')
        known.add(identifier)
        name = item.get('name', '')
        require(isinstance(name, str) and len(name.encode()) <= LIMIT['name_bytes'], 'name budget')
        if item.get('kind') == 'folder':
            folders[identifier] = item.get('parent')
    for edge in edges:
        require(isinstance(edge, list) and len(edge) == 2 and all(x in known for x in edge), 'dangling edge')
    # Iterative, explicitly bounded: O(identities * folder_depth), no recursion.
    for start in folders:
        seen = set()
        node = start
        while node is not None:
            require(node not in seen, 'folder cycle')
            require(node in folders, 'missing folder parent')
            seen.add(node)
            require(len(seen) <= LIMIT['folder_depth'], 'folder depth budget')
            node = folders[node]
    return doc  # Generic object retains every unknown member, including nested ones.

def inspect_zip(raw):
    require(len(raw) <= LIMIT['zip_bytes'], 'compressed input budget')
    # zipfile loads central directory: capped input bounds this experiment's
    # allocation; a shipping implementation must scan/count entries incrementally.
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        entries = archive.infolist()
        require(len(entries) <= LIMIT['entries'], 'archive entry budget')
        seen = set()
        total = 0
        for entry in entries:
            name = entry.filename
            require(name == 'manifest.json' or
                    (name.startswith('media/') and len(name) == 70 and
                     all(c in '0123456789abcdef' for c in name[6:])), 'unsafe archive path')
            require(name not in seen, 'duplicate archive path')
            seen.add(name)
            require(not stat.S_ISLNK(entry.external_attr >> 16), 'symlink')
            require(entry.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED), 'compression method')
            require(not entry.flag_bits & 1, 'encrypted ZIP unsupported')
            require(entry.file_size <= LIMIT['entry_bytes'], 'expanded entry budget')
            require(entry.file_size <= max(1, entry.compress_size) * LIMIT['ratio'], 'expansion ratio')
            digest = hashlib.sha256()
            count = 0
            with archive.open(entry) as stream:
                while chunk := stream.read(4096):
                    count += len(chunk)
                    total += len(chunk)
                    require(count <= LIMIT['entry_bytes'] and total <= LIMIT['expanded_bytes'], 'stream byte budget')
                    digest.update(chunk)
            require(count == entry.file_size, 'size mismatch')
            if name.startswith('media/'):
                require(digest.hexdigest() == name[6:], 'media digest mismatch')
        require('manifest.json' in seen, 'missing manifest')
    return total

def uid(n):
    return str(uuid.UUID(int=n))

def encode(value):
    return json.dumps(value, ensure_ascii=False, separators=(',', ':')).encode()

def package(entries):
    data = io.BytesIO()
    with zipfile.ZipFile(data, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for name, body in entries:
            archive.writestr(name, body)
    return data.getvalue()

def main():
    base = dict(format='km-interchange-experiment', major=1, scope='recipe',
                requiredFeatures=[], identities=[dict(id=uid(1), kind='recipe', name='Synthetic stew')],
                relationships=[], revisions=[dict(id=uid(2), parents=[],
                originalText='About 1/3–1/2 cup; one handful if needed',
                quantity=dict(kind='range', lower='1/3', upper='1/2'),
                equipment=['Synthetic pan'], ingredients=['first', 'second'],
                attribution='Synthetic author', source=dict(url='https://example.invalid/recipe',
                capture='{"futureSourceField":true}'), futureIngredient=dict(unit='moonspoon', precision=None))],
                futureEnvelope=dict(nested=[dict(flag=True, exact='99999999999999999999/3')]))
    (HERE / 'recipe-unknown-fields.json').write_bytes(encode(base))
    # Transport original immutable bytes, including a future field, without
    # interpreting or re-encoding their hashed representation.
    opaque = b'{ "futureAuthority" : { "number" : 1.000000000000000001 } }\n'
    base['opaqueEvidence'] = dict(formatVersion=99,
        encoding='base64', bytes=base64.b64encode(opaque).decode(),
        sha256=hashlib.sha256(opaque).hexdigest(), activation='unsupported')
    (HERE / 'recipe-unknown-fields.json').write_bytes(encode(base))
    (HERE / 'malformed.json').write_bytes(b'{')
    kitchen = copy.deepcopy(base)
    kitchen['scope'] = 'kitchen'
    kitchen['identities'] += [dict(id=uid(3), kind='folder', name='Synthetic folder', parent=None)]
    kitchen['relationships'] = [[uid(1), uid(3)]]
    kitchen['retainedEvidence'] = dict(sessionFacts=['opaque synthetic fact'], tombstones=['synthetic frontier'])
    (HERE / 'kitchen.json').write_bytes(encode(kitchen))
    results = []
    def case(name, operation, expected=None):
        tracemalloc.start()
        try:
            result = operation()
            require(expected is None, 'expected rejection missing')
            outcome = 'accepted'
        except ValueError as error:
            require(expected is not None and expected in str(error), f'unexpected rejection: {error}')
            outcome = str(error)
        _, peak = tracemalloc.get_traced_memory()
        tracemalloc.stop()
        results.append(dict(case=name, result=outcome, peak_python_bytes=peak))
    def changed(key, value):
        item = copy.deepcopy(base)
        item[key] = value
        return encode(item)
    case('recipe unknown-field semantic roundtrip', lambda: require(validate(encode(validate(encode(base)))) == base, 'roundtrip'))
    case('Kitchen semantic roundtrip', lambda: require(validate(encode(validate(encode(kitchen)))) == kitchen, 'roundtrip'))
    case('opaque future evidence byte roundtrip', lambda: require(
        base64.b64decode(validate(encode(validate(encode(base))))['opaqueEvidence']['bytes']) == opaque,
        'opaque bytes changed'))
    case('malformed JSON', lambda: validate(b'{'), 'Expecting property')
    case('duplicate JSON keys', lambda: validate(b'{"major":1,"major":2}'), 'duplicate JSON key')
    case('unknown major', lambda: validate(changed('major', 2)), 'unsupported major')
    case('unknown required feature', lambda: validate(changed('requiredFeatures', ['new-authority'])), 'required feature')
    case('nonfinite JSON', lambda: parse(b'{"x":NaN}'), 'nonfinite number')
    case('JSON nesting', lambda: parse(b'[' * 25 + b'0' + b']' * 25), 'JSON nesting budget')
    case('JSON bytes', lambda: parse(b' ' * (LIMIT['json_bytes'] + 1)), 'JSON byte budget')
    chain = [dict(id=uid(n+10), kind='folder', name='f', parent=uid(n+9) if n else None) for n in range(17)]
    depth_fixture = changed('identities', chain)
    (HERE / 'excessive-folder-depth.json').write_bytes(depth_fixture)
    case('Folder depth', lambda: validate(depth_fixture), 'folder depth budget')
    chain[0]['parent'] = chain[-1]['id']
    case('Folder cycle', lambda: validate(changed('identities', chain[:2] + [dict(chain[-1], parent=chain[0]['id'])])), 'folder cycle')
    case('name bytes', lambda: validate(changed('identities', [dict(id=uid(1), kind='tag', name='é'*65)])), 'name budget')
    case('identity count', lambda: validate(changed('identities', [dict(id=uid(n+1), kind='tag') for n in range(129)])), 'identity budget')
    case('relationship count', lambda: validate(changed('relationships', [[uid(1),uid(1)]]*257)), 'edge budget')
    case('dangling relationship', lambda: validate(changed('relationships', [[uid(1),uid(3)]])), 'dangling edge')
    maximum = changed('identities', [dict(id=uid(n+1), kind='tag', name='f') for n in range(128)])
    case('maximum admitted identities', lambda: validate(maximum))
    media = b'synthetic media bytes, deliberately not an image'
    media_path = 'media/' + hashlib.sha256(media).hexdigest()
    goodzip = package([('manifest.json', encode(base)), (media_path, media)])
    (HERE / 'synthetic-recipe.zip').write_bytes(goodzip)
    case('ZIP streaming and media integrity', lambda: inspect_zip(goodzip))
    case('ZIP path traversal', lambda: inspect_zip(package([('../escape', b'x')])), 'unsafe archive path')
    case('ZIP hash mismatch', lambda: inspect_zip(package([('manifest.json', b'{}'), ('media/'+'0'*64, media)])), 'media digest mismatch')
    case('ZIP expansion ratio', lambda: inspect_zip(package([('manifest.json', b'0'*60000)])), 'expansion ratio')
    case('ZIP entry byte budget', lambda: inspect_zip(package([('manifest.json', b'0'*65537)])), 'expanded entry budget')
    case('ZIP entry count', lambda: inspect_zip(package([('media/'+format(n,'064x'), b'x') for n in range(17)])), 'archive entry budget')
    pattern = b''.join(hashlib.sha256(str(n).encode()).digest() for n in range(128))
    chunks = [((pattern + bytes([n])) * 14) for n in range(3)]
    case('ZIP aggregate expanded byte budget', lambda: inspect_zip(package(
        [('manifest.json', b'{}')] + [('media/'+hashlib.sha256(x).hexdigest(), x) for x in chunks])), 'stream byte budget')
    output = dict(nonshipping=True, profile_limits=LIMIT, cases=results, passed=len(results),
                  limitations=['No real image decode', 'No domain codecs or persistent commit',
                               'Python allocation peaks are not a production RAM guarantee',
                               'ZIP central directory allocation bounded only by compressed input cap'])
    (HERE / 'results.json').write_text(json.dumps(output, indent=2)+'\n')
    print(json.dumps(output, indent=2))

if __name__ == '__main__':
    main()
