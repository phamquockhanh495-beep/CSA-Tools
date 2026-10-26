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

    def test_autolisp_length_shadow_is_detected_and_anchor_helpers_are_safe(self):
        pure = PureLisp(self.forms)
        pure.defs['shadow-child'] = ['defun','shadow-child',[],['length',['quote',[1,2]]]]
        pure.defs['shadow-parent'] = ['defun','shadow-parent',['length'],['shadow-child']]
        with self.assertRaisesRegex(ValueError, 'bad function: 120.0'):
            pure.call('shadow-parent',120.0)
        for name in ('csar:beam-leg','csar:beam-flight-end','csar:flight-fit-error','csad:detail-specs'):
            self.assertNotIn('length',pure.defs[name][2])
        data=self.data.copy()
        data[10]=10
        # A 120 mm anchor may fail geometric fit, but must return a diagnostic
        # rather than trying to call the number as LENGTH in a child helper.
        issue=pure.call('csar:error',self.raw,self.concrete,data,self.options)
        self.assertIsInstance(issue,str)
        self.assertIn('does not fit',issue)

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

    def test_excel_anchor_lengths_and_cover_on_fitting_supports(self):
        for raw in (self.raw, self.zero_neck()):
            polygon = self.pure.call('csad:cleanpoints', raw)
            for cover in (15, 20, 25):
                data = self.data.copy()
                data[0], data[10] = cover, 20
                self.assertIsNone(self.pure.call('csar:error', raw, self.concrete, data, self.options))
                for top in (None, True):
                    path = self.pure.call('csar:mainpath', raw, cover, 12, 240, top)
                    self.assert_return_hook(path[2], path[1], path[0], 12)
                    self.assert_return_hook(path[-3], path[-2], path[-1], 12)
                    self.assertGreaterEqual(self.pure.call('csar:path-clearance', path, polygon), cover-0.01)

    def test_bj38_is_used_per_diameter_and_invalid_values_are_rejected(self):
        raw = self.support_case(False, False)
        for multiplier in (20, 30):
            data = self.data.copy()
            data[10] = multiplier
            for diameter in (8, 12, 16):
                self.assertEqual(self.pure.call('csar:anchor-length', data, diameter), multiplier*diameter)
                path = self.pure.call('csar:mainpath', raw, 25, diameter, multiplier*diameter, True)
                self.assertAlmostEqual(math.dist(path[1],path[2]), multiplier*diameter)
                self.assertAlmostEqual(math.dist(path[-3],path[-2]), multiplier*diameter)
        for value in (None, '', 0, -1):
            data = self.data.copy()
            data[10] = value
            self.assertIn('BJ38', self.pure.call('csar:error', raw, self.concrete, data, self.options))
        data = self.data.copy()
        data[0] = 80
        self.assertIsNotNone(self.pure.call('csar:error', raw, self.concrete, data, self.options))
        # The unchanged workbook's 200-wide upper beam cannot contain upward
        # 30d anchorage for d12 at this cover. Reject instead of trimming it.
        issue = self.pure.call('csar:error',self.raw,self.concrete,self.data,self.options)
        self.assertIn('Upper beam',issue)
        self.assertIn('360.0 mm',issue)
        self.assertIn('not shortened',issue)

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

    def neck_case(self):
        raw = [p[:] for p in self.raw]
        for i in (17,18,19): raw[i] = raw[15].copy()
        for i in (10,11,12): raw[i] = [raw[9][0],raw[13][1]]
        return raw

    def test_neck_reinforcement_threshold_supports_radius_and_four_corners(self):
        raw = self.neck_case()
        self.assertIsNone(self.pure.call('csar:error',raw,self.concrete,self.data,self.options))
        for upper in (None, True):
            self.assertTrue(self.pure.call('csar:neck-enabled',raw,upper))
            self.assertFalse(self.pure.call('csar:neck-enabled',self.raw,upper))
            box = self.pure.call('csar:neck-box',raw,25,upper)
            vertices = self.pure.call('csar:rounded-box',box,4)
            dots = self.pure.call('csar:neck-dots',box)
            self.assertEqual(len(vertices),8)
            self.assertEqual(len(dots),4)
            self.assertAlmostEqual(vertices[0][0]-box[0],4)
            self.assertAlmostEqual(vertices[2][1]-box[1],4)
            polygon = self.pure.call('csad:cleanpoints',raw)
            for point in dots:
                self.assertGreaterEqual(self.pure.call('csar:point-clearance',point,polygon),25+6)
            altered = [p[:] for p in raw]
            for height, expected in ((0,False),(100,False),(100.1,True)):
                if upper: altered[3][1] = altered[4][1]-height
                else: altered[2][1] = altered[1][1]+height
                self.assertEqual(bool(self.pure.call('csar:neck-enabled',altered,upper)),expected)
        narrow = [p[:] for p in raw]
        narrow[14][0] = narrow[1][0]+70
        self.assertIn('Lower neck',self.pure.call('csar:neck-error',narrow,25))

    def test_neck_renderer_uses_quarter_arcs_four_dots_and_native_callouts(self):
        pure = PureLisp(self.forms)
        paths, dots, notes, bulges, closed = [], [], [], [], []
        pure.host.update({
            'csar:polyline': lambda *args: paths.append(args) or len(paths),
            'csar:dot': lambda *args: dots.append(args),
            'csar:note': lambda *args: notes.append(args),
            'vla-put-Closed': lambda *args: closed.append(args),
            'vla-SetBulge': lambda *args: bulges.append(args),
        })
        pure.defs['test-necks'] = ['defun','test-necks',[],['setq',':vlax-true',True],
            ['csar:render-necks',None,['quote',[0,0,0]],['quote',self.neck_case()],25,13,True,50]]
        self.assertEqual(pure.call('test-necks'),17)
        self.assertEqual(len(paths),2)
        self.assertEqual(len(dots),8)
        self.assertTrue(all(d[3]==8 and d[4]=='CSA-PREVIEW' for d in dots))
        self.assertTrue(all(v is True for obj,v in closed))
        self.assertEqual([b[1] for b in bulges],[1,3,5,7]*2)
        for obj,index,bulge in bulges:
            self.assertAlmostEqual(bulge,math.tan(math.pi/8))
        self.assertEqual([n[5] for n in notes],[13,14,15,16])
        self.assertEqual([bool(n[6]) for n in notes],[False,True,False,True])
        self.assertEqual(pure.call('csar:notation',notes[0][4],'0'),'%%C8a200')
        self.assertEqual(pure.call('csar:notation',notes[1][4],'0'),'4%%C8')
        self.assertEqual(pure.call('csar:notation',notes[1][4],'1'),'4T8')

    @staticmethod
    def clipped_length(path, box):
        # Independent rectangular line clipping, excluding the return hook.
        left,bottom,right,top = box
        total = 0
        for a,b in zip(path,path[1:]):
            lo,hi = 0.0,1.0
            for index,low,high in ((0,left,right),(1,bottom,top)):
                delta=b[index]-a[index]
                if abs(delta)<1e-9:
                    if not low-1e-9<=a[index]<=high+1e-9: hi=-1
                else:
                    cuts=sorted(((low-a[index])/delta,(high-a[index])/delta))
                    lo=max(lo,cuts[0]);hi=min(hi,cuts[1])
            total+=max(0,hi-lo)*math.dist(a,b)
        return total

    def test_beam_anchor_excludes_traversal_through_tall_neck(self):
        for raw in (self.raw,self.zero_neck()):
            for top in (None,True):
                end=self.pure.call('csar:main-end',raw,25,12,360,None,top)
                axis=self.pure.call('csar:flight-axis',raw,25,top)
                mid=self.pure.call('csad:mid',*axis)
                beam=self.pure.call('csar:support-beam',raw,None)
                rect=[beam[0],beam[2],beam[1],raw[0][1]]
                self.assertAlmostEqual(self.clipped_length([mid,end[2],end[1]],rect),360)
                if raw is self.raw:
                    self.assertGreater(end[2][1],0)
                    self.assertAlmostEqual(end[1][1],-360) # full embedment below top of beam

    def test_support_detection_and_total_anchorage_for_zero_one_two_beams(self):
        for lower, upper in ((False,False),(True,False),(False,True),(True,True)):
            raw = self.support_case(lower, upper)
            data = self.data.copy()
            data[0], data[10] = 20, 20
            self.assertIsNone(self.pure.call('csar:error', raw, self.concrete, data, self.options))
            for top in (None, True):
                flight = self.pure.call('csar:mainpath', raw, 20, 12, 240, top)
                axis = self.pure.call('csar:flight-axis',raw,20,top)
                for side, enabled in ((None,lower),(True,upper)):
                    beam = self.pure.call('csar:support-beam', raw, side)
                    self.assertEqual(bool(beam), enabled)
                    bend,tip,hook = (flight[-3],flight[-2],flight[-1]) if side else (flight[2],flight[1],flight[0])
                    self.assert_return_hook(bend,tip,hook,12)
                    if enabled:
                        mid = self.pure.call('csad:mid',*axis)
                        rect = [beam[0],beam[2],beam[1],raw[4 if side else 0][1]]
                        self.assertAlmostEqual(self.clipped_length([mid,bend,tip],rect),240)
                        self.assertEqual(bend[0],tip[0])
                        self.assertEqual(tip[1]>bend[1],bool(side)) # upper up, lower down
                        self.assertAlmostEqual(min(abs(bend[0]-beam[0]),abs(bend[0]-beam[1])),20)
                    else:
                        self.assertAlmostEqual(math.dist(bend,tip),240)
            for side, enabled in ((None,lower),(True,upper)):
                landing = self.pure.call('csar:landingpath',raw,20,12,240,side,None)
                bend,tip,hook = landing[-3:]
                if enabled:
                    beam = self.pure.call('csar:support-beam',raw,side)
                    entry = [beam[1 if side else 0],bend[1]]
                    self.assertAlmostEqual(math.dist(entry,bend)+math.dist(bend,tip),240)
                    self.assertLess(tip[1],bend[1])
                else:
                    self.assertAlmostEqual(math.dist(bend,tip),240)
                self.assert_return_hook(bend,tip,hook,12)
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
                    data[0], data[10] = cover, 20
                    self.assertIsNone(self.pure.call('csar:error', raw, concrete, data, self.options))
                    for side, free in ((None, lower_free), (True, upper_free)):
                        self.assertEqual(bool(self.pure.call('csar:outer-support', raw, side)), not free)
                        lower = self.pure.call('csar:landingpath', raw, cover, 12, 240, side, None)
                        upper = self.pure.call('csar:landingpath', raw, cover, 12, 240, side, True)
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

    def test_plate_flight_tails_reference_top_landing_at_zero_and_minus_ten(self):
        for raw in (self.support_case(False,False), self.neck_case()):
            for cover in (15,25):
                for top in (None,True):
                    path = self.pure.call('csar:mainpath',raw,cover,12,360,top)
                    for side in (None, True):
                        a,b = (path[-3],path[-2]) if side else (path[2],path[1])
                        landing_top = self.pure.call('csar:landingline', raw, cover, 12, side, True)
                        expected_y = landing_top[0][1]-(0 if top else 10)
                        self.assertAlmostEqual(a[1],expected_y)
                        self.assertAlmostEqual(b[1],expected_y)
                        self.assertAlmostEqual(math.dist(a,b),360)
                    polygon = self.pure.call('csad:cleanpoints',raw)
                    self.assertGreaterEqual(self.pure.call('csar:path-clearance',path,polygon),cover-.01)
                # Landing top still enters the lower flight with the previously
                # confirmed 10 mm normal separation; this rule was not replaced.
                for side in (None, True):
                    landing = self.pure.call('csar:landingpath',raw,cover,12,360,side,True)
                    axis = self.pure.call('csar:flight-axis',raw,cover,None)
                    for point in landing[-3:-1]:
                        projection = self.pure.call('csad:project',point,*axis)
                        self.assertAlmostEqual(math.dist(point,projection),10)

    def test_shallow_support_does_not_shorten_total_anchor(self):
        raw = self.support_case(True,True)
        raw[17][1] = raw[18][1] = -140
        data = self.data.copy()
        data[10] = 20
        issue = self.pure.call('csar:error',raw,self.concrete,data,self.options)
        self.assertIsNotNone(issue)
        self.assertIn('does not fit',issue)
        path = self.pure.call('csar:landingpath',raw,25,12,240,None,None)
        beam = self.pure.call('csar:support-beam',raw,None)
        entry = [beam[0],path[-3][1]]
        self.assertAlmostEqual(math.dist(entry,path[-3])+math.dist(path[-3],path[-2]),240)
        # A requested length shorter than the entry run cannot create a
        # reversed vertical leg or accidentally omit one end of the flight.
        self.assertIsNone(self.pure.call('csar:landingpath',raw,25,12,100,None,None))
        self.assertIsNone(self.pure.call('csar:mainpath',raw,25,12,10,True))

    def test_flat_flight_is_rejected_before_joint_intersection_division(self):
        raw = [p[:] for p in self.raw]
        raw[2][1] = raw[3][1] = 0
        raw[13][1] = raw[14][1] = -120
        self.assertIn('positive inclined rise',
                      self.pure.call('csar:error', raw, self.concrete, self.data, self.options))

    def test_landing_diameters_are_validated_independently(self):
        for slot in (4, 5):
            data = self.data.copy()
            data[slot], data[10] = '100a150', 20
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
            data[9], data[11], data[10] = mode, 7, 20
            data[4], data[5] = '14a120', '12a100'
            self.assertIsNone(pure.call('csar:error',self.raw,self.concrete,data,self.options))
            pure.call('csar:render', None, [100, 200, 0], self.raw, data, self.options, None, 400, 50)
            self.assertEqual(len(paths), count)
            self.assertTrue(all(path and len(path)>3 for path,layer in paths))
            self.assertTrue(all(layer == '18-GB-Reinf' for _, layer in paths))
            self.assertEqual([note[5] for note in notes], list(range(7, 7+2*count)))
            repeat = 1 if count == 3 else 2
            self.assertEqual([note[4][2] for note in notes[:count]],
                             ['12a150']*repeat + ['14a120']*repeat + ['12a100']*repeat)
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
        bad_landing[10] = 20
        self.assertIsNone(self.pure.call('csar:error', self.raw, self.concrete, bad_landing, options))
        bad = self.data.copy()
        bad[8], bad[10] = '12a0.001', 20
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
                        path = self.pure.call('csar:mainpath', raw, self.data[0], 12, 360, top)
                    else:
                        path = self.pure.call('csar:landingpath', raw, self.data[0], 12, 360, region=='UPPER', top)
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
