"""Offline checks against the user's native AutoCAD export, not a CAD runtime test."""
import csv
import io
import json
from pathlib import Path
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[2]
TOOL = ROOT / 'stair-tool'


class Symbol(str):
    pass


def lisp_forms(source):
    """Read lists/quotes/strings so checks inspect forms, not comments or substrings."""
    tokens = re.findall(r';[^\n]*|"(?:\\.|[^"\\])*"|[()\']|[^\s()\';"]+', source)
    tokens = iter(t for t in tokens if not t.startswith(';'))

    def read(t):
        if t == '(':
            result = []
            for child in tokens:
                if child == ')':
                    return result
                result.append(read(child))
            raise ValueError('Unclosed list')
        if t == ')':
            raise ValueError('Unexpected closing parenthesis')
        if t == "'":
            return [Symbol('quote'), read(next(tokens))]
        if t.startswith('"'):
            return t[1:-1]
        return Symbol(t)

    return [read(t) for t in tokens]


def walk(form):
    yield form
    if isinstance(form, list):
        for child in form:
            yield from walk(child)


class StandardsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.profile = json.loads((TOOL / 'standards/csa-profile.json').read_text())
        cls.forms = lisp_forms((TOOL / 'tools/CSA_StairStandardsTest.lsp').read_text())
        cls.defs = {f[1]: f for f in cls.forms if isinstance(f, list) and f and f[0] == 'defun'}

    def exported(self, name):
        data = subprocess.check_output(
            ['git', 'show', f"{self.profile['source_commit']}:CSA_Standards_{name}.csv"], cwd=ROOT)
        return list(csv.DictReader(io.StringIO(data.decode('utf-8-sig'))))

    def test_profile_matches_native_export(self):
        layers = {r['Name']: r for r in self.exported('layers')}
        blocks = {r['Name']: r for r in self.exported('blocks')}
        attrs = self.exported('attributes')
        for row in self.profile['layers'].values():
            self.assertEqual(row, layers[row['Name']])
        for role in self.profile['blocks'].values():
            name = role['definition']['Name']
            self.assertEqual(role['definition'], blocks[name])
            self.assertEqual(role['attributes'], [r for r in attrs if r['Block'] == name])

    def test_lisp_uses_exact_layer_names_and_attribute_tags(self):
        required_layers = self.defs['csast:layers'][3][1]
        self.assertTrue(set(required_layers) <= {r['Name'] for r in self.profile['layers'].values()})
        required_blocks = self.defs['csast:blocks'][3][1]
        available = {v['definition']['Name']: {r['Tag'] for r in v['attributes']}
                     for v in self.profile['blocks'].values()}
        for name, *tags in required_blocks:
            self.assertTrue(set(tags) <= available[name])

    def test_lisp_helpers_resolve_and_commands_exist(self):
        for name in ['c:CSA_STAIR_CHECK', 'c:CSA_STAIR_TEST', 'c:CSA_STAIR_TEST_CLEAR']:
            self.assertIn(name, self.defs)
        calls = [f[0] for top in self.forms for f in walk(top)
                 if isinstance(f, list) and f and isinstance(f[0], Symbol)]
        for name in calls:
            if name.startswith('csast:'):
                self.assertIn(name, self.defs)
        # Existing definitions and global settings must not be rewritten by the test.
        for name in ['setvar', 'command', 'command-s', 'vla-put-ActiveDimStyle',
                     'vla-put-ActiveLayer', 'vla-AddLayer', 'vla-AddTextStyle']:
            self.assertNotIn(name, calls)

    def test_cleanup_selection_is_owned_geometry_only(self):
        cleanup = str(self.defs['c:CSA_STAIR_TEST_CLEAR'])
        self.assertIn('CSA_STAIR_STANDARDS_TEST', cleanup)
        self.assertIn('410', cleanup)
        self.assertIn('Model', cleanup)
        self.assertNotIn('CSA-PREVIEW', cleanup)

    def test_vba_layer_constants_match_export(self):
        source = (TOOL / 'vba/modCSAStairTypes.bas').read_text()
        names = re.findall(r'Public Const CSA_LAYER_\w+ As String = "([^"]+)"', source)
        available = {r['Name'] for r in self.exported('layers')}
        for name in names:
            if name != 'CSA-PREVIEW':
                self.assertIn(name, available)

    def test_vba_declarations_precede_procedures(self):
        source = (TOOL / 'vba/modCSAStairTypes.bas').read_text()
        self.assertLess(source.rindex('End Type'), source.index('Public Sub'))
        source = (TOOL / 'vba/modCSAStairGeometry.bas').read_text()
        self.assertNotIn('ByVal f As CSAFlight', source)

    def test_elevation_scale_is_independent_of_other_blocks(self):
        defaults = self.profile['presentation_defaults']
        self.assertEqual(defaults['elevation_block_scale'], 0.35)
        self.assertEqual(defaults['other_block_scale'], 1.0)
        insertions = {f[2]: f[5] for f in walk(self.defs['c:CSA_STAIR_TEST'])
                      if isinstance(f, list) and f and f[0] == 'csast:insert'}
        self.assertEqual(insertions['Cao do'], Symbol('levelscale'))
        for name in ['Daucat', 'So hieu thep', 'CSA_Sohieu-KCthep']:
            self.assertEqual(insertions[name], Symbol('scale'))
        level_defaults = [f for f in walk(self.defs['c:CSA_STAIR_TEST'])
                          if isinstance(f, list) and len(f) == 3
                          and f[:2] == [Symbol('setq'), Symbol('levelscale')]
                          and not isinstance(f[2], list)]
        self.assertEqual(float(level_defaults[0][2]), defaults['elevation_block_scale'])
        source = (TOOL / 'vba/modCSAStairAdapter.bas').read_text()
        match = re.search(r'Function CSA_InsertElevation\b.*?Optional ByVal scale As Double = ([\d.]+)',
                          source, re.S)
        self.assertEqual(float(match[1]), defaults['elevation_block_scale'])


if __name__ == '__main__':
    unittest.main()
