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
        cls.options = [cls.cells[k] for k in ['U28', 'AI23', 'AV21', 'Z23', 'Z24', 'Z25', 'Z26']]

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
            self.assertIsNone(self.pure.call('csar:error', self.raw, self.concrete, data, self.options))
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
            self.assertIsNotNone(self.pure.call('csar:error', self.raw, self.concrete, data, self.options))

    def test_landing_bars_run_in_section_and_respect_cover(self):
        polygon = self.pure.call('csad:cleanpoints', self.raw)
        for cover in (15, 25):
            for upper in (None, True):
                for top in (None, True):
                    path = self.pure.call('csar:landingpath', self.raw, cover, 12, 30, upper, top)
                    self.assertEqual(len(path), 4)
                    self.assertEqual(path[0][1], path[1][1])
                    self.assertAlmostEqual(self.pure.host['distance'](path[2], path[3]), 360)
                    self.assertEqual(path[1][0], path[2][0])
                    slope = (path[3][1]-path[2][1])/(path[3][0]-path[2][0])
                    self.assertAlmostEqual(slope, (self.raw[3][1]-self.raw[2][1])/3000)
                    self.assertGreaterEqual(self.pure.call('csar:path-clearance', path, polygon),
                                            cover+6-0.01)

    def test_landing_diameters_are_validated_independently(self):
        for slot in (4, 5):
            data = self.data.copy()
            data[slot] = '100a150'
            self.assertIn('Landing', self.pure.call('csar:error', self.raw, self.concrete, data, self.options))

    def test_render_plan_uses_excel_bars_layers_and_sequential_marks(self):
        # Stub entity creation only; execute the actual Lisp drawing orchestration.
        for mode, count in [('1 layer', 3), ('2 layers', 6)]:
            pure = PureLisp(self.forms)
            paths, notes, dots = [], [], []
            pure.host.update({
                'csast:p': lambda base, x, y: [base[0]+x, base[1]+y, base[2]],
                'csar:polyline': lambda space, base, path, layer: paths.append((path, layer)),
                'csar:dot': lambda *args: dots.append(args),
                'csar:note': lambda *args: notes.append(args),
                'csast:text': lambda *args: None,
            })
            data = self.data.copy()
            data[9], data[11] = mode, 7
            data[4], data[5] = '10a120', '8a100'
            pure.call('csar:render', None, [100, 200, 0], self.raw, data, self.options, None, 400, 50)
            self.assertEqual(len(paths), count)
            self.assertTrue(all(layer == '18-GB-Reinf' for _, layer in paths))
            self.assertEqual([note[5] for note in notes], list(range(7, 7+2*count)))
            repeat = 1 if count == 3 else 2
            self.assertEqual([note[4][2] for note in notes[:count]],
                             ['12a150']*repeat + ['10a120']*repeat + ['8a100']*repeat)
            self.assertTrue(all(note[6] is None for note in notes[:count])) # ticks
            self.assertTrue(all(note[6] is True for note in notes[count:])) # dot blank
            self.assertTrue(dots)
            self.assertTrue(all(dot[3] == 12 and dot[4] == '18-GB-Reinf' for dot in dots))

    def test_step_counts_are_read_and_checked_against_concrete(self):
        self.assertEqual(self.options[:2], [2, 12])
        self.assertIsNone(self.pure.call('csad:steps-error', self.raw, self.options))
        labels = self.pure.call('csad:step-labels', self.raw, self.options, 400)
        self.assertEqual([v[0] for v in labels], ['12 BAC', '2 BAC'])
        bad = self.options.copy()
        bad[1] = 13
        self.assertIsNotNone(self.pure.call('csad:steps-error', self.raw, bad))
        bad[1] = 12.5
        self.assertIsNotNone(self.pure.call('csad:steps-error', self.raw, bad))

    def test_distribution_spacing_cover_and_switches(self):
        polygon = self.pure.call('csad:cleanpoints', self.raw)
        for cover in (15, 25):
            data = self.data.copy()
            data[0] = cover
            specs = self.pure.call('csar:distribution-specs', self.raw, data, self.options)
            self.assertEqual(len(specs), 6)
            for region, top, line in specs:
                dots = self.pure.call('csar:stations', *line, 100)
                for a, b in zip(dots, dots[1:]):
                    self.assertAlmostEqual(self.pure.host['distance'](a, b), 100)
                for dot in dots:
                    self.assertGreaterEqual(self.pure.call('csar:point-clearance', dot, polygon), cover+6-0.01)
        options = self.options.copy()
        options[5:] = ['No', 'No']
        self.assertEqual([s[0] for s in self.pure.call('csar:distribution-specs', self.raw, self.data, options)],
                         ['FLIGHT', 'FLIGHT'])
        # Turning off all landing groups permits a flight-only rebar layout.
        options[3:] = ['No']*4
        bad_landing = self.data.copy()
        bad_landing[4:6] = ['100a150', '100a150']
        self.assertIsNone(self.pure.call('csar:error', self.raw, self.concrete, bad_landing, options))
        bad = self.data.copy()
        bad[8] = '12a0.001'
        self.assertIn('2000', self.pure.call('csar:error', self.raw, self.concrete, bad, self.options))

    def test_native_leader_arrow_types_are_per_entity(self):
        for dotted, expected in [(None, 4), (True, 12)]:
            pure, props = PureLisp(self.forms), {}
            def add_leader(space, arr, note, kind):
                # Model the required dispatch argument that the old nil call
                # failed to supply. This is an API contract test, not COM execution.
                if note is None:
                    raise ValueError('Parameter not optional: Annotation')
                props.update(coords=arr, annotation=note, kind=kind)
                return 'leader'
            pure.host.update({
                'csast:p': lambda base, x, y: [base[0]+x, base[1]+y, base[2]],
                '1-': lambda v: v-1,
                'cons': lambda *v: v,
                'vlax-make-safearray': lambda *args: [],
                'vlax-safearray-fill': lambda arr, coords: arr.extend(coords),
                'vla-AddLeader': add_leader,
                'csast:track': lambda obj: obj,
                'vla-put-Layer': lambda *args: None,
                'vla-put-StyleName': lambda *args: None,
                'vla-put-ScaleFactor': lambda obj, value: props.update(scale=value),
                'vla-put-ArrowheadType': lambda obj, value: props.update(arrow=value),
                'vla-put-ArrowheadSize': lambda obj, value: props.update(size=value),
                'vla-Update': lambda *args: None,
            })
            # Visual LISP constant is provided by vl-load-com in AutoCAD.
            pure.defs['leader-test'] = ['defun', 'leader-test', [],
                ['setq', 'vlax-vbDouble', 5],
                ['csar:leader', None, ['quote', [10,20,30]],
                 ['quote', [[1,2],[3,4],[5,4]]], '20-GB-GC', dotted, 62.5, 12, 'GB 25', 'CSA note BlockReference']]
            pure.call('leader-test')
            self.assertEqual(props['annotation'], 'CSA note BlockReference')
            self.assertEqual(props['arrow'], expected)
            self.assertEqual(props['scale'], 1)
            self.assertEqual(props['kind'], 1)
            self.assertEqual(props['coords'], [11,22,30,13,24,30,15,24,30])

    def test_note_passes_its_created_block_to_leader(self):
        calls = [f for f in walk(self.pure.defs['csar:note'])
                 if isinstance(f, list) and f and f[0] == 'csar:leader']
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][-1], 'note')
        calls = [f for f in walk(self.pure.defs['csar:leader'])
                 if isinstance(f, list) and f and f[0] == 'vla-AddLeader']
        self.assertEqual(calls[0][3], 'annotation')

    def test_filled_dot_geometry_has_actual_bar_diameter(self):
        pure, props = PureLisp(self.forms), {}
        pure.host.update({
            'csar:polyline': lambda space, base, points, layer: props.update(points=points) or 'dot',
            'vla-put-Closed': lambda obj, value: props.update(closed=value),
            'vla-SetBulge': lambda obj, index, value: props.update({index: value}),
            'vla-put-ConstantWidth': lambda obj, value: props.update(width=value),
        })
        pure.defs['dot-test'] = ['defun', 'dot-test', [], ['setq', ':vlax-true', True],
            ['csar:dot', None, ['quote', [100,200,0]], ['quote', [20,30]], 12, '18-GB-Reinf']]
        pure.call('dot-test')
        self.assertTrue(props['closed'])
        self.assertEqual((props[0], props[1]), (1, 1))
        centerline_radius = pure.host['distance'](*props['points'])/2
        self.assertEqual(centerline_radius+props['width']/2, 6) # outside radius
        self.assertEqual(centerline_radius-props['width']/2, 0) # filled to center

    def test_one_layer_and_input_errors(self):
        data = self.data.copy()
        data[9] = '1 layer'
        self.assertEqual(self.pure.call('csar:layers', data), 1)
        self.assertIsNone(self.pure.call('csar:error', self.raw, self.concrete, data, self.options))
        data[6] = 'wrong'
        self.assertIsNotNone(self.pure.call('csar:error', self.raw, self.concrete, data, self.options))
        self.assertIsNotNone(self.pure.call('csar:error', self.raw, self.concrete, [], self.options))


if __name__ == '__main__':
    unittest.main()
