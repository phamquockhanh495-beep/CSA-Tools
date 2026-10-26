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

    def test_upper_dimension_chain_is_775_above_top_and_step_text_keeps_measurement(self):
        for gap in (200,400,600):
            for spec in self.specs(gap=gap):
                if spec[0] in ('lower_landing','flight_run','upper_landing'):
                    self.assertEqual(spec[4][1]-self.raw[4][1],775)
        spec=self.pure.call('csad:step-spec',self.raw,[2,12],400)
        self.assertEqual(spec[5],'12 x 250.00 = <>')
        self.assertEqual(self.pure.call('csad:dim-measure',spec),3000)

    def test_level_guides_share_right_end_and_preserve_floor_elevations(self):
        guides=self.pure.call('csad:level-guides',self.raw)
        self.assertEqual(len(guides),2)
        for guide,y in zip(guides,[self.raw[0][1],self.raw[4][1]]):
            self.assertEqual(guide[0],[self.raw[0][0]-500,y])
            self.assertEqual(guide[1],[self.raw[5][0]+500,y])

    def test_short_feet_cut_long_extensions_without_changing_measurement(self):
        for spec in self.specs():
            before=self.pure.call('csad:dim-measure',spec)
            feet=self.pure.call('csad:short-feet',spec,200)
            for a,b in feet:
                self.assertLessEqual(self.pure.host['distance'](a,b),200.000001)
            self.assertEqual(self.pure.call('csad:dim-measure',spec),before)
            if spec[0]=='flight_run':
                self.assertEqual(len(feet),2)
                for a,b in feet:self.assertAlmostEqual(self.pure.host['distance'](a,b),200)

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

    def test_fixed_extensions_batch_only_new_dimensions_by_scale(self):
        pure = PureLisp(lisp_forms((TOOL/'tools/CSA_StairDrawing.lsp').read_text()))
        names = [f'new-{i}' for i in range(16)] + ['other-scale']
        overrides = []
        def selection_add(entity=None, selection=None):
            if selection is None: return []
            selection.append(entity)
            return selection
        pure.host.update({
            'vla-get-ScaleFactor': lambda obj: 50 if obj == 'other-scale' else 25,
            'assoc': lambda key, entries: next((v for v in (entries or []) if v[0] == key), None),
            'subst': lambda new, old, entries: [new if v == old else v for v in entries],
            'ssadd': selection_add,
            'vlax-vla-object->ename': lambda obj: obj,
            'csad:dimoverride': lambda selection, value: overrides.append((selection.copy(), value)),
        })
        pure.call('csad:fixed-extensions', names, 150)
        self.assertEqual(len(overrides), 2)
        self.assertEqual({e for selection, _ in overrides for e in selection}, set(names))
        for selection, value in overrides:
            scale = 50 if selection == ['other-scale'] else 25
            self.assertEqual(value*scale, 150)
        # No dimensions selected means no native command is run.
        overrides.clear()
        pure.call('csad:fixed-extensions', [], 150)
        self.assertEqual(overrides, [])

    def test_native_dimoverride_arguments_and_echo_restoration_on_failure(self):
        for fail in (False, True):
            pure = PureLisp(lisp_forms((TOOL/'tools/CSA_StairDrawing.lsp').read_text()))
            state, calls, messages = {'echo':1}, [], []
            def native_command(*args):
                self.assertEqual(state['echo'], 0)
                calls.append(args)
                if fail: raise RuntimeError('native command failure')
                return True
            def catch(fn, args):
                try: return pure.call(fn, *args)
                except RuntimeError as error: return error
            def abort(): raise RuntimeError('abort section')
            pure.host.update({
                'getvar': lambda key: state['echo'],
                'setvar': lambda key, value: state.update(echo=value),
                'vl-catch-all-apply': catch,
                'vl-catch-all-error-p': lambda value: isinstance(value, Exception),
                'vl-catch-all-error-message': str,
                'command-s': native_command, 'princ': messages.append, 'exit': abort,
            })
            if fail:
                with self.assertRaisesRegex(RuntimeError, 'abort section'):
                    pure.call('csad:dimoverride', ['new-dim'], 6)
                self.assertIn('native command failure', messages[0])
            else:
                self.assertTrue(pure.call('csad:dimoverride', ['new-dim'], 6))
            self.assertEqual(calls, [('_.DIMOVERRIDE','DIMFXLON','_ON','DIMFXL',6,'',['new-dim'],'')])
            self.assertEqual(state['echo'], 1)

    def test_dimension_scale_uses_annotation_scale_for_zero_dimscale(self):
        pure = PureLisp(lisp_forms((TOOL/'tools/CSA_StairDrawing.lsp').read_text()))
        pure.host.update({'vla-get-ScaleFactor':lambda obj:0, 'getvar':lambda key:1/25})
        self.assertEqual(pure.call('csad:dimension-scale', 'dimension'), 25)

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
