import json
import math
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

    def assert_return_hook(self, previous, tip, hook, diameter):
        incoming = [tip[i]-previous[i] for i in (0,1)]
        tail = [hook[i]-tip[i] for i in (0,1)]
        length = math.dist(tip, hook)
        self.assertAlmostEqual(length, 2*diameter)
        cosine = sum(-incoming[i]*tail[i] for i in (0,1))/(math.hypot(*incoming)*length)
        self.assertAlmostEqual(math.degrees(math.acos(cosine)), 30)

    def zero_neck(self):
        raw = [p[:] for p in self.raw]
        raw[2][1] = raw[1][1]
        slope = (raw[3][1]-raw[2][1])/(raw[3][0]-raw[2][0])
        intercept = raw[2][1]-slope*raw[2][0]-120*math.sqrt(1+slope*slope)
        for i in (13,14): raw[i][1] = slope*raw[i][0]+intercept
        return raw

    def test_excel_rebar_defaults_fit_and_cover_is_respected(self):
        for raw in (self.raw, self.zero_neck()):
            polygon = self.pure.call('csad:cleanpoints', raw)
            for cover in (15, 20, 25):
                data = self.data.copy()
                data[0] = cover
                self.assertIsNone(self.pure.call('csar:error', raw, self.concrete, data, self.options))
                for top in (None, True):
                    path = self.pure.call('csar:mainpath', raw, cover, 12, 200, top)
                    self.assertAlmostEqual(math.dist(path[1], path[2]), 200)
                    self.assertAlmostEqual(math.dist(path[-3], path[-2]), 200)
                    self.assert_return_hook(path[2], path[1], path[0], 12)
                    self.assert_return_hook(path[-3], path[-2], path[-1], 12)
                    self.assertGreaterEqual(self.pure.call('csar:path-clearance', path, polygon), cover-0.01)

    def test_bj38_is_superseded_and_excessive_cover_is_rejected(self):
        for legacy_anchor in (0, 20, 30, 1000):
            data = self.data.copy()
            data[10] = legacy_anchor
            self.assertIsNone(self.pure.call('csar:error', self.raw, self.concrete, data, self.options))
        data = self.data.copy()
        data[0] = 80
        self.assertIsNotNone(self.pure.call('csar:error', self.raw, self.concrete, data, self.options))

    def support_case(self, lower, upper):
        raw = self.zero_neck()
        if not lower:
            axis = [raw[13], raw[14]]
            point = self.pure.call('csar:aty', *axis, raw[20][1])
            for i in (14,15,16,17,18,19): raw[i] = point.copy()
        if not upper:
            axis = [raw[13], raw[14]]
            point = self.pure.call('csar:aty', *axis, raw[8][1])
            for i in (9,10,11,12,13): raw[i] = point.copy()
        return raw

    def test_support_detection_and_bottom_bar_legs_for_zero_one_two_beams(self):
        for lower, upper in ((False,False),(True,False),(False,True),(True,True)):
            raw = self.support_case(lower, upper)
            data = self.data.copy()
            data[0] = 20
            self.assertIsNone(self.pure.call('csar:error', raw, self.concrete, data, self.options))
            flight = self.pure.call('csar:mainpath', raw, 20, 12, 200, None)
            for side, enabled in ((None,lower),(True,upper)):
                beam = self.pure.call('csar:support-beam', raw, side)
                self.assertEqual(bool(beam), enabled)
                landing = self.pure.call('csar:landingpath', raw, 20, 12, 200, side, None)
                self.assertAlmostEqual(math.dist(landing[-3],landing[-2]), 200)
                self.assert_return_hook(landing[-3],landing[-2],landing[-1],12)
                if enabled:
                    self.assertAlmostEqual(landing[-3][0], beam[0]+20)
                    self.assertEqual(landing[-3][0], landing[-2][0])
                    self.assertEqual(landing[-3][1]-landing[-2][1], 200)
                    bend, tip = (flight[-3],flight[-2]) if side else (flight[2],flight[1])
                    self.assertAlmostEqual(bend[0], beam[1]-20)
                    self.assertEqual(bend[0], tip[0])
                    self.assertEqual(bend[1]-tip[1], 200)
                else:
                    self.assertNotEqual(landing[-3][0], landing[-2][0])
            text = self.pure.call('csar:support-label', raw)
            expected = 'Lower + Upper' if lower and upper else 'Lower only' if lower else 'Upper only' if upper else 'None'
            self.assertTrue(text.endswith(expected))

    def test_free_outer_ends_return_top_and_set_back_bottom_twenty_mm(self):
        for inner in (False, True):
            for lower_free, upper_free in ((True, False), (False, True), (True, True)):
                raw = self.support_case(inner, inner)
                concrete = self.concrete.copy()
                if lower_free:
                    for i in (21, 22, 23): raw[i][1] = raw[20][1]
                    concrete[4] = 0
                if upper_free:
                    for i in (6, 7): raw[i][1] = raw[8][1]
                    concrete[6] = 0
                for cover in (15, 25):
                    data = self.data.copy()
                    data[0] = cover
                    self.assertIsNone(self.pure.call('csar:error', raw, concrete, data, self.options))
                    for side, free in ((None, lower_free), (True, upper_free)):
                        self.assertEqual(bool(self.pure.call('csar:outer-support', raw, side)), not free)
                        lower = self.pure.call('csar:landingpath', raw, cover, 12, 200, side, None)
                        upper = self.pure.call('csar:landingpath', raw, cover, 12, 200, side, True)
                        face = raw[5][0] if side else raw[0][0]
                        self.assertAlmostEqual(abs(lower[0][0]-face), cover + (20 if free else 0))
                        if free:
                            self.assertEqual(upper[0][0], upper[1][0])
                            self.assertAlmostEqual(abs(upper[0][0]-face), cover)
                            self.assertAlmostEqual(upper[0][1], lower[0][1])
                            self.assertGreater(upper[1][1], upper[0][1])
                        for path in (lower, upper):
                            polygon = self.pure.call('csad:cleanpoints', raw)
                            self.assertGreaterEqual(self.pure.call('csar:path-clearance', path, polygon), cover-.01)

    def test_top_tails_keep_ten_mm_normal_gap_from_lower_body_axes(self):
        for raw in (self.raw, self.zero_neck(), self.support_case(False,False)):
            for cover in (15,25):
                polygon = self.pure.call('csad:cleanpoints', raw)
                main = self.pure.call('csar:mainpath', raw, cover, 12, 200, True)
                for side in (None, True):
                    a,b = (main[-3],main[-2]) if side else (main[2],main[1])
                    lower_landing = self.pure.call('csar:landingline', raw, cover, 12, side, None)
                    self.assertAlmostEqual(a[1]-lower_landing[0][1],10)
                    self.assertAlmostEqual(b[1]-lower_landing[0][1],10)
                    path = self.pure.call('csar:landingpath', raw, cover, 12, 200, side, True)
                    self.assertAlmostEqual(math.dist(path[-3],path[-2]),200)
                    self.assert_return_hook(path[-3],path[-2],path[-1],12)
                    lower_flight = self.pure.call('csar:flight-axis', raw, cover, None)
                    for point in path[-3:-1]:
                        projection = self.pure.call('csad:project', point, *lower_flight)
                        self.assertAlmostEqual(math.dist(point,projection),10)
                    self.assertGreaterEqual(self.pure.call('csar:path-clearance',path,polygon),cover-.01)

    def test_shallow_support_does_not_silently_shorten_two_hundred_mm_anchor(self):
        raw = self.support_case(True,True)
        raw[17][1] = raw[18][1] = -140
        issue = self.pure.call('csar:error',raw,self.concrete,self.data,self.options)
        self.assertIsNotNone(issue)
        self.assertIn('does not fit',issue)
        path = self.pure.call('csar:landingpath',raw,self.data[0],12,200,None,None)
        self.assertEqual(path[-3][1]-path[-2][1],200)

    def test_flat_flight_is_rejected_before_joint_intersection_division(self):
        raw = [p[:] for p in self.raw]
        raw[2][1] = raw[3][1] = 0
        raw[13][1] = raw[14][1] = -120
        self.assertIn('positive inclined rise',
                      self.pure.call('csar:error', raw, self.concrete, self.data, self.options))

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
            expected_right = [True,False,False,True,False,False] if count == 3 else [True,False,False,False,False,False,True,False,False,False,False,False]
            self.assertEqual([bool(note[9]) for note in notes], expected_right)
            pairs = [(0,3),(1,4),(2,5)] if count == 3 else [(0,6),(1,9),(2,7),(3,10),(4,8),(5,11)]
            for main_index, dot_index in pairs:
                main, dot = notes[main_index], notes[dot_index]
                self.assertEqual(main[3][0], dot[3][0]) # same text column
                self.assertNotAlmostEqual(main[2][0], dot[2][0]) # distinct vertical stems

    def test_step_counts_are_validated_as_labels_independent_of_neck(self):
        self.assertEqual(self.options[:2], [2, 12])
        self.assertIsNone(self.pure.call('csad:steps-error', self.raw, self.options))
        labels = self.pure.call('csad:step-labels', self.raw, self.options, 400)
        self.assertEqual([v[0] for v in labels], ['12 BAC', '2 BAC'])
        bad = self.options.copy()
        bad[1] = 13
        self.assertIsNone(self.pure.call('csad:steps-error', self.raw, bad)) # annotation input, not neck geometry
        self.assertIsNone(self.pure.call('csad:steps-error', self.zero_neck(), self.options))
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
                    self.assertGreaterEqual(self.pure.call('csar:point-clearance', dot, polygon), cover+9-0.01)
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
                'vla-put-Type': lambda obj, value: props.update(type=value),
                'vla-put-Coordinates': lambda obj, value: props.update(final_coords=value),
                'vla-put-ArrowheadType': lambda obj, value: props.update(arrow=value),
                'vla-put-ArrowheadSize': lambda obj, value: props.update(size=value),
                'vla-Update': lambda *args: None,
            })
            # Visual LISP constant is provided by vl-load-com in AutoCAD.
            pure.defs['leader-test'] = ['defun', 'leader-test', [],
                ['setq', 'vlax-vbDouble', 5],
                ['csar:leader', None, ['quote', [10,20,30]],
                 ['quote', [[1,2],[3,4],[5,4]]], '20-GB-GC', dotted, (60 if dotted else 100), 'GB 25', 'CSA note BlockReference']]
            pure.call('leader-test')
            self.assertEqual(props['annotation'], 'CSA note BlockReference')
            self.assertEqual(props['arrow'], expected)
            self.assertEqual(props['scale'], 1)
            self.assertEqual(props['kind'], 0) # acLineWithArrow, NOT acSplineWithArrow
            self.assertEqual(props['type'], 0)
            self.assertEqual(props['size'], 60 if dotted else 100)
            self.assertEqual(props['final_coords'], props['coords'])
            self.assertEqual(props['coords'], [11,22,30,13,24,30,15,24,30])

    def test_axes_use_cover_and_dot_half_diameter_from_main_line(self):
        for cover in (15, 25):
            for top in (None, True):
                for main_d in (8, 14):
                    main = self.pure.call('csar:flight-axis', self.raw, cover, top)
                    axis = self.pure.call('csar:distribution-line', self.raw, cover, main_d, 12, top)
                    center = self.pure.call('csad:mid', *axis)
                    self.assertAlmostEqual(self.pure.call('csar:point-segment-distance', center, *main), 9)
                    concrete = [self.raw[2], self.raw[3]] if top else [self.raw[14], self.raw[13]]
                    mid = self.pure.call('csad:mid', *main)
                    self.assertAlmostEqual(self.pure.call('csar:point-segment-distance', mid, *concrete), cover)
                    for upper in (None, True):
                        landing = self.pure.call('csar:landingline', self.raw, cover, main_d, upper, top)
                        dots = self.pure.call('csar:landing-distribution-line', self.raw, cover, main_d, 12, upper, top)
                        self.assertAlmostEqual(abs(landing[0][1]-dots[0][1]), 9)

    def test_leader_route_is_vertical_then_perpendicular_shelf(self):
        low, high, textlow, texthigh = [0,0], [300,100], [100,35], [300,90]
        for target in ([-300,-400], [700,400]):
            route = self.pure.call('csar:note-route', target, low, high, textlow, texthigh, 62.5)
            self.assertEqual(len(route), 3)
            self.assertEqual(route[0], target)
            self.assertEqual(route[0][0], route[1][0])
            self.assertNotEqual(route[0][1], route[1][1])
            self.assertEqual(route[1][1], route[2][1])
            self.assertLess(route[1][1], textlow[1])
            self.assertLessEqual(min(route[1][0],route[2][0]), textlow[0])
            self.assertGreaterEqual(max(route[1][0],route[2][0]), texthigh[0])

    def test_callout_grid_is_200_200_50_and_targets_real_entities(self):
        for raw in (self.raw, self.zero_neck()):
            for region in ('FLIGHT','LOWER','UPPER'):
                for top in (None, True):
                    pair = self.pure.call('csar:callout-targets', raw, self.data, region, top)
                    main = self.pure.call('csar:note-position', pair, top, None, region=='FLIGHT' and not top)
                    note = self.pure.call('csar:note-position', pair, top, True, region=='FLIGHT' and not top)
                    self.assertEqual(main[0], note[0])
                    self.assertAlmostEqual(abs(main[1]-pair[0][1]), 200)
                    self.assertAlmostEqual(abs(main[1]-note[1]), 200)
                    self.assertAlmostEqual(abs(pair[0][0]-pair[1][0]), 50)
                    self.assertEqual(main[1] < note[1], bool(top))
                    specs = self.pure.call('csar:distribution-specs', raw, self.data, self.options)
                    line = next(v[2] for v in specs if v[:2] == [region, top])
                    self.assertIn(pair[1], self.pure.call('csar:stations', *line, 100))
                    if region == 'FLIGHT':
                        path = self.pure.call('csar:mainpath', raw, self.data[0], 12, 200, top)
                    else:
                        path = self.pure.call('csar:landingpath', raw, self.data[0], 12, 200, region=='UPPER', top)
                    self.assertLess(self.pure.call('csar:point-path-distance', pair[0], path), .01)

    def test_font_override_applies_only_to_new_diameter_attribute(self):
        pure = PureLisp(self.forms)
        sh = {'tag':'SH','style':'02-GB-VNI-Helve','text':'11'}
        text = {'tag':'DK-KC','style':'02-GB-VNI-Helve','text':'%%C10a100'}
        note = {'attributes':[sh,text],'definition_style':'02-GB-VNI-Helve'}
        pure.host.update({
            'vlax-invoke': lambda obj, method: obj['attributes'],
            'vla-get-TagString': lambda att: att['tag'],
            'vla-put-StyleName': lambda att, value: att.update(style=value),
            'vla-put-TextString': lambda att, value: att.update(text=value),
            'vla-Update': lambda obj: None,
        })
        for value in ('%%C10a100','T12a150'):
            result = pure.call('csar:format-note', note, value)
            self.assertIs(result, text)
            self.assertEqual(text['text'], value)
            self.assertEqual(text['style'], '01-GB-Arial')
            self.assertEqual(sh, {'tag':'SH','style':'02-GB-VNI-Helve','text':'11'})
            self.assertEqual(note['definition_style'], '02-GB-VNI-Helve')

    def test_note_shelf_placement_is_exact_after_font_metrics_change(self):
        target = [1500, 0]
        destination = [1350, 200]
        for height in (50, 62.5, 100):
            low, high, textlow, texthigh = [20,-120], [650,90], [110,-98], [460,-30]
            delta = self.pure.call('csar:note-shift', texthigh, textlow, destination, height)
            shifted = [[v[0]+delta[0], v[1]+delta[1]] for v in (low, high, textlow, texthigh)]
            route = self.pure.call('csar:note-route', target, *shifted, height)
            self.assertEqual(shifted[3][0], destination[0])
            self.assertEqual(route[1][1], 200)
            self.assertEqual(route[2][1], 200)
            self.assertEqual(route[0][0], route[1][0])

    def test_right_side_note_has_upright_text_left_of_unchanged_circle(self):
        # Circle and SH keep their native position; only DK-KC is translated.
        circle_left = [20,-100]
        text_low, text_high = [140,-70], [460,0]
        delta = self.pure.call('csar:reverse-note-shift',circle_left,text_high,62.5)
        self.assertLess(text_high[0]+delta[0],circle_left[0])
        self.assertEqual(delta[1:], [0,0])
        text_low = [text_low[i]+delta[i] for i in (0,1)]
        text_high = [text_high[i]+delta[i] for i in (0,1)]
        target, dest = [0,0], [100,-200]
        low, high = [text_low[0],-100], [120,0]
        shift = self.pure.call('csar:note-shift',low,text_low,dest,62.5)
        shifted = [[v[0]+shift[0],v[1]+shift[1]] for v in (low,high,text_low,text_high)]
        route = self.pure.call('csar:note-route',target,*shifted,62.5)
        self.assertEqual(route[1][1],-200)
        self.assertGreater(route[2][0], route[1][0])
        self.assertLess(shifted[3][0],circle_left[0]+shift[0])

    def test_rebar_symbol_can_be_diameter_or_t_without_duplicate_prefixes(self):
        for text in ('12a150','T12a150','%%C12a150'):
            bar = self.pure.call('csar:bar', text)
            self.assertEqual(self.pure.call('csar:notation', bar, '0'), '%%C12a150')
            self.assertEqual(self.pure.call('csar:notation', bar, '1'), 'T12a150')

    def test_note_passes_its_created_block_to_leader(self):
        calls = [f for f in walk(self.pure.defs['csar:note'])
                 if isinstance(f, list) and f and f[0] == 'csar:leader']
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][-1], 'note')
        calls = [f for f in walk(self.pure.defs['csar:leader'])
                 if isinstance(f, list) and f and f[0] == 'vla-AddLeader']
        self.assertEqual(calls[0][3], 'annotation')

    def test_filled_dot_visual_diameter_is_scaled_1_5_at_same_center(self):
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
        self.assertEqual(centerline_radius+props['width']/2, 9) # d12 drawn as d18
        self.assertEqual([(a+b)/2 for a,b in zip(*props['points'])], [20,30])
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
