import unittest
from math import sin, cos
from xml.etree import ElementTree as ET
from zipfile import ZipFile

from test_standards import ROOT, TOOL, lisp_forms
from lisp_subset import PureLisp


class ConcreteDetailsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pure = PureLisp(lisp_forms((TOOL / 'tools/CSA_StairDrawing.lsp').read_text()))
        with ZipFile(ROOT / 'CSA_Stair Drawing Tools.xlsm') as z:
            xml = ET.fromstring(z.read('xl/worksheets/sheet2.xml'))
        ns = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
        cls.cells = {c.attrib['r']: c.find('s:v', ns).text for c in xml.findall('.//s:c', ns)
                     if c.find('s:v', ns) is not None}
        cls.raw = [[float(cls.cells[f'BZ{i}']), float(cls.cells[f'CA{i}'])] for i in range(2, 26)]
        cls.metadata = [float(cls.cells[key]) for key in
                        ['H19', 'Z19', 'BA19', 'D31', 'D33', 'BU21', 'BU22', 'AO27']]

    def specs(self, raw=None, gap=400):
        return self.pure.call('csad:detail-specs', raw or self.raw, gap)

    def test_workbook_parameter_contract_matches_geometry(self):
        self.assertIsNone(self.pure.call('csad:detail-error', self.raw, self.metadata))
        wrong = self.metadata.copy()
        wrong[7] = 150
        self.assertIn('do not match', self.pure.call('csad:detail-error', self.raw, wrong))
        self.assertIn('Reload Excel', self.pure.call('csad:detail-error', self.raw[:21], self.metadata))

    def test_native_dimension_lengths_match_excel_detail_image(self):
        expected = {
            'lower_landing': 2000, 'flight_run': 3000, 'upper_landing': 1500,
            'floor_rise': 2200, 'lower_slab': 120, 'lower_downstand': 280,
            'lower_first_beam_width': 200, 'lower_last_beam_width': 250,
            'upper_slab': 120, 'upper_downstand': 280,
            'upper_first_beam_width': 200,
            'upper_last_beam_width': 200, 'lower_step_rise': 314.2857142857143,
            'upper_step_rise': 157.14285714285714, 'inclined_slab_normal': 120,
        }
        specs = self.specs()
        self.assertEqual({s[0] for s in specs}, set(expected))
        for spec in specs:
            self.assertAlmostEqual(self.pure.call('csad:dim-measure', spec), expected[spec[0]], places=6)

    def test_inclined_thickness_is_perpendicular_not_vertical(self):
        spec = next(s for s in self.specs() if s[0] == 'inclined_slab_normal')
        a, b = spec[2:4]
        slope = [self.raw[3][i] - self.raw[2][i] for i in (0, 1)]
        self.assertAlmostEqual(sum((b[i] - a[i]) * slope[i] for i in (0, 1)), 0, places=6)
        self.assertNotAlmostEqual(abs(b[1] - a[1]), 120, places=2)

    def test_nonparallel_soffit_is_rejected_even_if_midpoint_thickness_is_close(self):
        raw = [p.copy() for p in self.raw]
        center = self.pure.call('csad:project', self.pure.call('csad:mid', raw[2], raw[3]), raw[13], raw[14])
        for i in (13, 14):
            x, y = raw[i][0]-center[0], raw[i][1]-center[1]
            raw[i] = [center[0]+x*cos(.01)-y*sin(.01), center[1]+x*sin(.01)+y*cos(.01)]
        self.assertIn('invalid', self.pure.call('csad:detail-error', raw, self.metadata))

    def test_moving_outline_or_dimension_gap_does_not_change_measurements(self):
        translated = [[x+12000, y-5000] for x, y in self.raw]
        before = self.specs()
        after = self.specs(translated, gap=600)
        for a, b in zip(before, after):
            self.assertEqual(a[0], b[0])
            self.assertAlmostEqual(self.pure.call('csad:dim-measure', a),
                                   self.pure.call('csad:dim-measure', b))
            self.assertNotEqual(a[4], b[4])

    def test_fixed_extensions_are_150_model_mm_and_keep_other_dstyle_data(self):
        for scale in (1, 25, 50):
            app = ['ACAD', (1000,'before'), (1000,'DSTYLE'), (1002,'{'),
                   (1070,140), (1040,2.5), (1070,49), (1040,999.0),
                   (1070,290), (1070,0), (1002,'}'), (1000,'after')]
            result = self.pure.call('csad:fixed-dstyle', app, 150, scale)
            i = result.index((1070,49))
            self.assertEqual(result[i+1][1]*scale, 150)
            i = result.index((1070,290))
            self.assertEqual(result[i+1], (1070,1))
            self.assertEqual(result.count((1070,49)), 1)
            self.assertEqual(result.count((1070,290)), 1)
            self.assertIn((1070,140), result)
            self.assertIn((1040,2.5), result)
            self.assertEqual(result[1], (1000,'before'))
            self.assertEqual(result[-1], (1000,'after'))
            self.assertEqual(self.pure.call('csad:fixed-dstyle', result, 150, scale), result)
        fresh = self.pure.call('csad:fixed-dstyle', ['ACAD'], 150, 25)
        self.assertIn((1040,6), fresh)

    def test_fixed_extension_preserves_preview_tags_and_all_apps(self):
        # Execute the native-data merge with API boundaries stubbed.
        pure = PureLisp(lisp_forms((TOOL/'tools/CSA_StairDrawing.lsp').read_text()))
        before = [(0,'DIMENSION'), [-3, ['CSA_STAIR_PREVIEW',(1000,'v1')],
                   ['ACAD',(1000,'other-data')]], [-3,['OTHER',(1000,'keep')]]]
        output = {}
        pure.host.update({
            'vlax-vla-object->ename': lambda obj: 'dimension',
            'entget': lambda *args: before,
            'vla-get-ScaleFactor': lambda obj: 25,
            'entmod': lambda data: output.update(data=data) or data,
            'entupd': lambda entity: None,
        })
        pure.call('csad:fixed-extension', 'object', 150)
        after = output['data']
        self.assertEqual(after[0], before[0])
        self.assertEqual(after[1][1], before[1][1])
        self.assertEqual(after[2], before[2])
        self.assertIn((1000,'other-data'), after[1][2])
        self.assertIn((1040,6), after[1][2])

    def test_fixed_extensions_do_not_confuse_integer_values_with_variable_codes(self):
        app = ['ACAD',(1000,'DSTYLE'),(1002,'{'),
               (1070,176),(1070,49), # DIMCLRD color value is 49
               (1070,177),(1070,290),
               (1070,49),(1040,10),(1070,290),(1070,0),(1002,'}')]
        result = self.pure.call('csad:fixed-dstyle', app, 150, 25)
        self.assertEqual(result[3:7], app[3:7])
        self.assertEqual(result[7:], [(1070,49),(1040,6),(1070,290),(1070,1),(1002,'}')])

    def test_block_scale_recovery_with_inch_compensation(self):
        def scale_entity(obj, point, factor):
            for axis in ('x', 'y', 'z'):
                obj[axis] *= factor
            obj['transforms'].append(factor)

        self.pure.host.update({
            'vla-get-XScaleFactor': lambda o: o['x'],
            'vla-get-YScaleFactor': lambda o: o['y'],
            'vla-get-ZScaleFactor': lambda o: o['z'],
            'vla-ScaleEntity': scale_entity, 'vlax-3d-point': lambda p: p,
            'vla-Update': lambda o: None,
        })
        for factor in (1, 25.4):
            requested = 0.01
            obj = {axis: requested/factor for axis in ('x', 'y', 'z')}
            obj['transforms'] = []
            self.pure.call('csast:normalize-scale', obj, [0, 0, 0], requested)
            for axis in ('x', 'y', 'z'):
                self.assertAlmostEqual(obj[axis], requested)
            self.assertEqual(len(obj['transforms']), 0 if factor == 1 else 1)


if __name__ == '__main__':
    unittest.main()
