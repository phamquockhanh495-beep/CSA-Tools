from pathlib import Path
import runpy
import unittest
from xml.etree import ElementTree as ET
from zipfile import ZipFile

from test_standards import TOOL, ROOT, Symbol, lisp_forms, walk
from lisp_subset import PureLisp


class SectionUITests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.forms = lisp_forms((TOOL / 'tools/CSA_StairDrawing.lsp').read_text())
        cls.pure = PureLisp(cls.forms)

    def test_bundle_is_current_and_all_helpers_resolve(self):
        build = runpy.run_path(str(TOOL / 'tools/build_stair_bundle.py'))
        self.assertEqual((TOOL / 'tools/CSA_StairDrawing.lsp').read_text(), build['bundle']())
        for top in self.forms:
            for form in walk(top):
                if isinstance(form, list) and form and isinstance(form[0], Symbol):
                    if form[0].startswith(('csad:', 'csast:', 'csar:')):
                        self.assertIn(form[0], self.pure.defs)

    def test_actual_lisp_cleanup_and_area_with_workbook_coordinates(self):
        with ZipFile(ROOT / 'CSA_Stair Drawing Tools.xlsm') as z:
            xml = ET.fromstring(z.read('xl/worksheets/sheet2.xml'))
        ns = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
        cells = {c.attrib['r']: c.find('s:v', ns).text for c in xml.findall('.//s:c', ns)
                 if c.find('s:v', ns) is not None}
        points = []
        for i in range(2, 501):
            if f'BY{i}' not in cells: break
            points.append([float(cells[f'BZ{i}']), float(cells[f'CA{i}'])])
        self.assertEqual(len(points), 24)
        clean = self.pure.call('csad:cleanpoints', points)
        self.assertNotEqual(clean[0], clean[-1])
        self.assertTrue(all(a != b for a, b in zip(clean, clean[1:])))
        self.assertGreater(self.pure.call('csad:area', clean), 0)
        self.assertAlmostEqual(self.pure.call('csad:area', points), self.pure.call('csad:area', clean))
        self.assertEqual(max(p[0] for p in clean) - min(p[0] for p in clean), 6500)
        self.assertEqual(max(p[1] for p in clean) - min(p[1] for p in clean), 2600)
        rise = float(cells['D22'])
        self.assertAlmostEqual(max(p[1] for p in clean) - clean[0][1], rise)

    def test_degenerate_outline_has_zero_area(self):
        self.assertEqual(self.pure.call('csad:area', [[0, 0], [1, 0], [2, 0]]), 0)
        self.assertEqual(self.pure.call('csad:cleanpoints', [[0, 0], [0, 0], [0, 0]]), [[0, 0]])

    def test_fixed_elevations_with_dimzin_zero_suppression(self):
        for raw, expected in [('3.6', '+3.600'), ('.05', '+0.050'), ('0', '+0.000'),
                              ('-.05', '-0.050'), ('-3.6', '-3.600')]:
            self.pure.host['rtos'] = lambda *args, r=raw: r
            number = float(raw)
            self.assertEqual(self.pure.call('csad:leveltext', number), expected)

    def test_excel_is_attach_read_only(self):
        calls = {f[0] for f in walk(self.pure.defs['csad:loadexcel'])
                 if isinstance(f, list) and f and isinstance(f[0], Symbol)}
        self.assertIn('vlax-get-object', calls)
        self.assertNotIn('vlax-create-object', calls)
        self.assertNotIn('vlax-put-property', calls)
        self.assertNotIn('vla-Quit', calls)


if __name__ == '__main__':
    unittest.main()
