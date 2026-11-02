"""Portable structural/data checks; does not compile Swift or render the UI."""
import json
import re
from collections import Counter
from pathlib import Path
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[1]


def parse_project(path):
    text = path.read_text().split('\n', 1)[1]
    tokens = re.findall(r'"(?:\\.|[^"\\])*"|[{}()=;,]', text)
    cursor = 0

    def take(expected=None):
        nonlocal cursor
        token = tokens[cursor]
        cursor += 1
        if expected is not None:
            assert token == expected, (token, expected)
        return token

    def value():
        if tokens[cursor] == '{':
            take('{')
            result = {}
            while tokens[cursor] != '}':
                key = json.loads(take())
                take('=')
                assert key not in result
                result[key] = value()
                take(';')
            take('}')
            return result
        if tokens[cursor] == '(':
            take('(')
            result = []
            while tokens[cursor] != ')':
                result.append(value())
                take(',')
            take(')')
            return result
        return json.loads(take())

    result = value()
    assert cursor == len(tokens)
    return result


def main():
    catalogue_path = ROOT / 'HexaTFT/Resources/catalogue.json'
    assert catalogue_path.stat().st_size <= 2_000_000
    data = json.loads(catalogue_path.read_text())
    assert data['schemaVersion'] == 1 and data['isDemo'] is True
    assert len(set(g['id'] for g in data['guides'])) == len(data['guides'])
    for guide in data['guides']:
        assert {x['stage'] for x in guide['phases']} == {'2-1', '2-5', '3-2', '4-1', '5-1', '6-1'}
        assert len(guide['phases']) == 6
        assert all(x['objective'] and x['level'] and x['economy'] and len(x['options']) > 1 for x in guide['phases'])
    reference = json.loads((ROOT/'HexaTFT/Resources/reference.json').read_text())
    ids = [entry['id'] for entry in reference['entries']]
    assert len(ids) == len(set(ids)), 'duplicate reference identifiers'
    assert all(e['name'] and e['imageURL'].startswith('https://ddragon.leagueoflegends.com/') for e in reference['entries'])
    assert set(e['kind'] for e in reference['entries']) == {'champion','item','trait','augment'}

    project = parse_project(ROOT/'HexaTFT.xcodeproj/project.pbxproj')
    objects = project['objects']
    assert objects[project['rootObject']]['isa'] == 'PBXProject'
    reference_fields = {'fileRef','buildConfigurationList','mainGroup','productRefGroup','productReference','containerPortal','remoteGlobalIDString','target','targetProxy'}
    reference_arrays = {'children','buildConfigurations','files','buildPhases','dependencies','targets'}
    for value in objects.values():
        for key, item in value.items():
            if key in reference_fields:
                assert item in objects, (key,item)
            if key in reference_arrays:
                assert all(x in objects for x in item), (key,item)
    for target in [x for x in objects.values() if x['isa'] == 'PBXNativeTarget']:
        assert len(target['buildPhases']) == 3
    def check_group(key, base):
        group = objects[key]
        base = base / group.get('path','')
        for child in group['children']:
            entry = objects[child]
            if entry['isa'] == 'PBXGroup': check_group(child,base)
            elif entry.get('sourceTree') == '<group>':
                assert (base/entry['path']).is_file(), base/entry['path']
    check_group(objects[project['rootObject']]['mainGroup'], ROOT)
    scheme = ElementTree.parse(ROOT/'HexaTFT.xcodeproj/xcshareddata/xcschemes/HexaTFT.xcscheme')
    for element in scheme.findall('.//BuildableReference'):
        assert element.attrib['BlueprintIdentifier'] in objects
    preview = (ROOT/'apercu.html').read_text()
    embedded = json.loads(re.search(r'<script id="pack" type="application/json">(.*?)</script>',preview,re.S).group(1))
    assert embedded == data
    assert 'PACK_JSON' not in preview
    print('PASS: guide phases, reference IDs, project graph, source/resource paths, shared scheme, preview data')
    print('Reference entries:',dict(Counter(e['kind'] for e in reference['entries'])))
    print('NOT RUN: Swift compilation, XCTest, simulator/device UI, browser rendering')


if __name__ == '__main__':
    main()
