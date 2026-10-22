import json
import unittest
from xml.etree import ElementTree as ET
from zipfile import ZipFile

from test_standards import ROOT, TOOL, lisp_forms, walk
from lisp_subset import PureLisp


class RebarTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.forms = lisp_forms((TOOL/'tools/CSA_StairDrawing.lsp').read_text())
        cls.pure = PureLisp(cls.forms)
        ns = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
        with ZipFile(ROOT/'CSA_Stair Drawing Tools.xlsm') as z:
            shared = ET.fromstring(z.read('xl/sharedStrings.xml'))
            texts = [''.join(n.itertext()) for n in shared.findall('s:si', ns)]
            xml = ET.fromstring(z.read('xl/worksheets/sheet2.xml'))
        cls.cells = {}
        for c in xml.findall('.//s:c', ns):
            v = c.find('s:v', ns)
            if v is not None:
                if c.attrib.get('t') == 's': value = texts[int(v.text)]
                elif c.attrib.get('t') in ('str', 'e'): value = v.text
                else: value = float(v.text)
                cls.cells[c.attrib['r']] = value
        cls.raw = [[cls.cells[f'BZ{i}'], cls.cells[f'CA{i}']] for i in range(2, 26)]
        cls.concrete = [cls.cells[k] for k in ['H19','Z19','BA19','D31','D33','BU21','BU22','AO27']]
        cls.data = [cls.cells[f'BJ{i}'] for i in range(28, 42)]

    def test_five_crossed_out_dimensions_are_absent(self):
        profile = json.loads((TOOL/'standards/csa-profile.json').read_text())
        names = {spec[0] for spec in self.pure.call('csad:detail-specs', self.raw, 400)}
        self.assertTrue(names.isdisjoint(profile['presentation_defaults']['suppressed_dimensions']))
        self.assertIn('lower_first_beam_width', names)
        self.assertIn('upper_last_beam_width', names)
        literals = {v for v in walk(self.pure.defs['csad:render']) if isinstance(v, str)}
        self.assertIn('overall_width', literals)
        self.assertNotIn('overall_height', literals)

    def test_rebar_notation_parser(self):
        for value in ['12a150', ' D12 @ 150 ', '%%C12a150']:
            self.assertEqual(self.pure.call('csar:bar', value), [12, 150, '12a150'])
        self.assertEqual(self.pure.call('csar:bar', '6.5a100'), [6.5, 100, '6.5a100'])
        for value in ['', '12', '12a0', '-12a150', '12aBAD']:
            self.assertIsNone(self.pure.call('csar:bar', value))

    def test_excel_rebar_defaults_fit_and_cover_is_respected(self):
        for cover in (15, 25):
            data = self.data.copy()
            data[0] = cover
            self.assertIsNone(self.pure.call('csar:error', self.raw, self.concrete, data))
            for top in (None, True):
                path = self.pure.call('csar:mainpath', self.raw, cover, 12, 30, top)
                self.assertAlmostEqual(abs(path[1][0]-path[0][0]), 360)
                self.assertAlmostEqual(abs(path[-1][0]-path[-2][0]), 360)
                self.assertGreaterEqual(self.pure.call('csar:path-clearance', path,
                    self.pure.call('csad:cleanpoints', self.raw)), cover+6-0.01)

    def test_excessive_anchorage_and_cover_are_not_silently_shortened(self):
        for slot, value in [(10, 1000), (0, 80)]:
            data = self.data.copy()
            data[slot] = value
            self.assertIsNotNone(self.pure.call('csar:error', self.raw, self.concrete, data))

    def test_landing_bars_run_in_section_and_respect_cover(self):
        polygon = self.pure.call('csad:cleanpoints', self.raw)
        for cover in (15, 25):
            for upper in (None, True):
                for top in (None, True):
                    path = self.pure.call('csar:landingpath', self.raw, cover, 12, upper, top)
                    self.assertEqual(len(path), 2)
                    self.assertEqual(path[0][1], path[1][1])
                    self.assertGreater(path[1][0], path[0][0])
                    self.assertGreaterEqual(self.pure.call('csar:path-clearance', path, polygon),
                                            cover+6-0.01)

    def test_landing_diameters_are_validated_independently(self):
        for slot in (4, 5):
            data = self.data.copy()
            data[slot] = '100a150'
            self.assertIn('Landing', self.pure.call('csar:error', self.raw, self.concrete, data))

    def test_render_plan_uses_excel_bars_layers_and_sequential_marks(self):
        # Stub entity creation only; execute the actual Lisp drawing orchestration.
        # This verifies the plan, not native AutoCAD COM or block appearance.
        for mode, count in [('1 layer', 3), ('2 layers', 6)]:
            pure = PureLisp(self.forms)
            paths, notes = [], []
            pure.host.update({
                'itoa': lambda value: str(int(value)),
                'cons': lambda head, tail: [head]+tail if isinstance(tail, list) else (head, tail),
                'csast:p': lambda base, x, y: [base[0]+x, base[1]+y, base[2]],
                'csar:polyline': lambda space, base, path, layer: paths.append((path, layer)),
                'csast:line': lambda *args: None,
                'csast:insert': lambda *args: notes.append(args),
                'csad:center': lambda *args: None,
                'csast:text': lambda *args: None,
            })
            data = self.data.copy()
            data[9], data[11] = mode, 7
            data[4], data[5] = '10a120', '8a100'
            pure.call('csar:render', None, [100, 200, 0], self.raw, data, None, 400, 50)
            self.assertEqual(len(paths), count)
            self.assertTrue(all(layer == '18-GB-Reinf' for _, layer in paths))
            self.assertEqual([note[-1][0][1] for note in notes],
                             [str(n) for n in range(7, 7+count)])
            repeat = 1 if count == 3 else 2
            self.assertEqual([note[-1][1][1] for note in notes],
                             ['12a150']*repeat + ['10a120']*repeat + ['8a100']*repeat)

    def test_one_layer_and_input_errors(self):
        data = self.data.copy()
        data[9] = '1 layer'
        self.assertEqual(self.pure.call('csar:layers', data), 1)
        self.assertIsNone(self.pure.call('csar:error', self.raw, self.concrete, data))
        data[6] = 'wrong'
        self.assertIsNotNone(self.pure.call('csar:error', self.raw, self.concrete, data))
        self.assertIsNotNone(self.pure.call('csar:error', self.raw, self.concrete, []))


if __name__ == '__main__':
    unittest.main()
