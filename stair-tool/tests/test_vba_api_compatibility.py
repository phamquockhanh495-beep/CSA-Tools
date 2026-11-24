"""Source-contract guards; real VBA/COM tests are shipped as runnable macros.

These tests do not emulate VBA or certify any AutoCAD release.
"""
import re
import unittest
from pathlib import Path
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parents[1]
VBA = ROOT / 'vba'
UI = ROOT / 'ui'
TOOLS = ROOT / 'tools'


class VbaApiCompatibilityTests(unittest.TestCase):
    def test_release_contract_has_exact_ten_targets_2018_to_2027_and_primary_2022(self):
        source = (VBA / 'modCSAStairHost.bas').read_text()
        pairs = re.findall(r'Case "([0-9.]+)": CSA_AcadReleaseYear = (\d+)', source)
        expected = [('22.0', '2018'), ('23.0', '2019'), ('23.1', '2020'),
                    ('24.0', '2021'), ('24.1', '2022'), ('24.2', '2023'),
                    ('24.3', '2024'), ('25.0', '2025'), ('25.1', '2026'),
                    ('26.0', '2027')]
        self.assertEqual(pairs, expected)
        self.assertIn('CSA_PRIMARY_CAD_YEAR As Long = 2022', source)
        # Split("") produces an empty array in VBA: guard before UBound.
        self.assertLess(source.index('If Len(prefix) = 0'), source.index('parts = Split'))
        self.assertLess(source.index('If UBound(parts) < 1'), source.index('Select Case'))
        self.assertIn('If release = 0 Then', source)
        self.assertIn('#If VBA7 And Win64 Then', source)

    def test_host_does_not_attach_to_a_different_autocad_process(self):
        source = (VBA / 'modCSAStairHost.bas').read_text()
        code = '\n'.join(line for line in source.splitlines() if not line.lstrip().startswith("'"))
        self.assertIn('Set document = ThisDrawing', code)
        self.assertNotRegex(code, r'\b(?:CreateObject|GetObject)\s*\(')
        self.assertIn('Dim point(0 To 2) As Double', code)

    def test_pointer_width_and_gdi_resource_lifetime(self):
        source = (VBA / 'modCSAStairWinApi.bas').read_text()
        vba7 = source.split('#If VBA7 Then', 1)[1].split('#Else', 1)[0]
        declares = re.findall(r'Private Declare PtrSafe Function \w+', vba7)
        self.assertGreaterEqual(len(declares), 19)
        self.assertRegex(vba7, r'GetDC.*ByVal hwnd As LongPtr\) As LongPtr')
        self.assertRegex(vba7, r'ReleaseDC.*hwnd As LongPtr.*hdc As LongPtr\) As Long')
        self.assertRegex(vba7, r'GetDeviceCaps.*hdc As LongPtr.*index As Long\) As Long')
        self.assertRegex(vba7, r'GetOpenFileNameW.*CSA_OpenFileNameW\) As Long')
        self.assertRegex(vba7, r'OleCreatePictureIndirect.*CSA_PictDescBmp.*CSA_Guid.*ByVal fOwn As Long.*lplpvObj As Object\) As Long')
        # Ensure all VBA7 declares use PtrSafe
        self.assertNotRegex(vba7, r'Declare\s+Function')
        body = source.split('Public Function CSA_SystemDpiX', 1)[1].split('Public Function CSA_PixelsToFormPoints', 1)[0]
        success, failure = body.split('Failed:', 1)
        self.assertIn('ReleaseDC 0, hdc', success)
        self.assertIn('If hdc <> 0 Then ReleaseDC 0, hdc', failure)
        # Ensure GDI cleanup releases DCs and deletes bitmaps on discard / failure
        discard = source.split('Public Sub CSA_DiscardCanvas', 1)[1].split('End Sub', 1)[0]
        self.assertIn('DeleteObject canvas.hBitmap', discard)
        self.assertIn('DeleteDC canvas.memDC', discard)
        end_pic = source.split('Public Function CSA_EndCanvasToPicture', 1)[1].split('End Function', 1)[0]
        self.assertIn('If bmp <> 0 Then DeleteObject bmp', end_pic)

    def test_api_smoke_writes_only_to_disposable_document(self):
        source = (VBA / 'modCSAStairApiTests.bas').read_text()
        self.assertIn('"26.0"', source)
        self.assertIn('2027', source)
        self.assertIn('Public Sub CSA_TestFormPreviewApi()', source)
        active_x = source.split('Public Sub CSA_TestActiveXApi()', 1)[1].split('Public Sub CSA_TestFormPreviewApi()', 1)[0]
        self.assertIn('Set original = CSA_CadDocument()', active_x)
        self.assertIn('Set app = original.Application', active_x)
        self.assertIn('Set testDoc = app.Documents.Add', active_x)
        self.assertIn('Set space = testDoc.ModelSpace', active_x)
        self.assertNotRegex(active_x, r'original\.(?:Close|Save|SetVariable|ModelSpace|Layers|Blocks)')
        self.assertNotRegex(active_x, r'\b(?:SaveAs|SendCommand)\b')
        success, failure = active_x.split('Failed:', 1)
        for branch in (success, failure):
            self.assertIn('testDoc.Close False', branch)
            self.assertIn('original.Activate', branch)
        for api in ('AddLightWeightPolyline', 'AddDimAligned', 'GetBoundingBox',
                    'InsertBlock', 'GetAttributes', 'SetXData', 'GetXData'):
            self.assertIn(api, active_x)

    def test_host_guards_run_before_form_and_drawing_mutations(self):
        main = (VBA / 'modCSAStairMain.bas').read_text()
        self.assertLess(main.index('CSA_HostReady()'), main.index('Load frmCSAStair'))
        preview = (VBA / 'modCSAStairPreview.bas').read_text()
        for proc in ('CSA_RenderPreview', 'CSA_DrawSectionFinal', 'CSA_DrawPlanFinal'):
            body = preview.split('Public Sub ' + proc, 1)[1].split('End Sub', 1)[0]
            self.assertLess(body.index('CSA_HostReady()'), body.index('CSA_ClearPreview'))
        adapter = (VBA / 'modCSAStairAdapter.bas').read_text()
        for proc, mutation in [('CSA_InsertTaggedBlock', '.InsertBlock'),
                               ('CSA_AddAlignedDimension', '.AddDimAligned')]:
            body = adapter.split('Public Function ' + proc, 1)[1].split('End Function', 1)[0]
            self.assertLess(body.index('CSA_RequireSupportedHost'), body.index(mutation))

    def test_no_public_macro_collisions_with_compat_module(self):
        compat = (ROOT / 'CSA_StairCase_Compat.bas').read_text()
        compat_pubs = set(re.findall(r'^Public (?:Sub|Function) (\w+)', compat, re.M))
        project_pubs = set()
        for bas in VBA.glob('*.bas'):
            project_pubs.update(re.findall(r'^Public (?:Sub|Function) (\w+)', bas.read_text(), re.M))
        self.assertEqual(compat_pubs & project_pubs, set())

    def test_programmatic_userform_classes_and_ascii_safety(self):
        for path in list(VBA.glob('*.bas')) + list(UI.glob('*.cls')) + [UI / 'frmCSAStair.code.bas']:
            raw = path.read_text(encoding='utf-8')
            raw.encode('ascii')  # Must stay pure ASCII for VBAIDE across Windows locales.
        ctrl = (UI / 'clsCSAStairFormController.cls').read_text()
        watcher = (UI / 'clsCSAStairFieldWatcher.cls').read_text()
        form_code = (UI / 'frmCSAStair.code.bas').read_text()
        self.assertIn('Attribute VB_Name = "clsCSAStairFormController"', ctrl)
        self.assertIn('Attribute VB_Name = "clsCSAStairFieldWatcher"', watcher)
        self.assertIn('clsCSAStairFormController', form_code)
        # Mockup + manual plan/rebar controls present; no manual X/Y boxes (direct pick on draw)
        for name in ('txtStairName', 'cboStairType', 'txtWidth', 'txtBottomElev', 'txtTopElev',
                     'txtRiser', 'txtTread', 'txtSlab', 'cboScale',
                     'txtFlight1', 'txtFlight2', 'txtFlight3', 'txtLanding', 'txtUpperLanding',
                     'txtWellGap', 'txtSupportWidth', 'cboDirection', 'txtSectionMark',
                     'cboDimStyle', 'txtCover', 'txtMainBar', 'txtDistBar', 'txtAnchorFactor',
                     'cboBarSymbol', 'PickInsertionPoint',
                     'imgSectionPreview', 'imgPlanPreview', 'lblSummary',
                     'chkDimensions', 'chkRebar', 'chkCreateLayers', 'chkOpenExcel',
                     'cmdLoadExcel', 'cmdPreview', 'cmdDrawSection', 'cmdDrawPlan',
                     'cmdClear', 'cmdCancel'):
            self.assertIn(name, ctrl)
        self.assertNotIn('cmdPickPoint', ctrl)
        self.assertIn('CSA_PickExcelFile', ctrl)
        self.assertIn('CSA_RenderSectionBitmap', ctrl)
        self.assertIn('CSA_RenderPlanBitmap', ctrl)

    def test_vba_packages_have_crlf_line_endings(self):
        for zip_name in ('CSA_Stair_VBA_API_2018-2027.zip', 'CSA_Stair_VBA_UI_2018-2027.zip'):
            path = TOOLS / zip_name
            self.assertTrue(path.exists(), f'Missing package: {zip_name}')
            with ZipFile(path) as zf:
                for member in zf.namelist():
                    if member.endswith(('.bas', '.cls')):
                        raw = zf.read(member)
                        self.assertIn(b'\r\n', raw, member)
                        self.assertNotIn(b'\n', raw.replace(b'\r\n', b''), member)

    def test_no_vba_reserved_keywords_as_identifiers(self):
        forbidden = ('scale', 'line', 'circle', 'pset', 'input', 'print',
                     'write', 'open', 'close', 'lock', 'stop', 'step')
        files = list(VBA.glob('*.bas')) + list(UI.glob('*.cls')) + [UI / 'frmCSAStair.code.bas']
        for path in files:
            for lineno, raw in enumerate(path.read_text().splitlines(), 1):
                code = raw.split("'", 1)[0]
                for kw in forbidden:
                    self.assertNotRegex(
                        code, rf'\b(?:ByVal|ByRef|Dim|Private|Public|For)\s+(?:WithEvents\s+)?{kw}\b',
                        f'Reserved VBA keyword "{kw}" used at {path.name}:{lineno}'
                    )
                    self.assertNotRegex(
                        code, rf',\s*{kw}\s+As\b',
                        f'Reserved VBA keyword "{kw}" used at {path.name}:{lineno}'
                    )

    def test_vba_layers_migrated_from_gb_to_csa(self):
        for path in (VBA / 'modCSAStairTypes.bas', VBA / 'modCSAStairAdapter.bas',
                     VBA / 'modCSAStairPlanGeom.bas', VBA / 'modCSAStairPlanDraw.bas',
                     VBA / 'modCSAStairSectionGeom.bas', VBA / 'modCSAStairSectionDraw.bas',
                     ROOT / 'CSA_StairCase_Compat.bas'):
            text = path.read_text()
            self.assertNotRegex(text, r'"\d{2}-GB-[^"]+"', f'Legacy GB layer found in {path.name}')
        types_src = (VBA / 'modCSAStairTypes.bas').read_text()
        for expected in ('04-CSA-Dim', '05-CSA-Hatch', '06-CSA-Slab-bor', '10-CSA-Text',
                         '11-CSA-Cao Do', '12-CSA-Ky hieu', '18-CSA-Reinf', '20-CSA-GC',
                         '21-CSA-BD', '22-CSA-NC'):
            self.assertIn(f'"{expected}"', types_src)

    def test_bilingual_language_module_and_form_toggle(self):
        lang_src = (VBA / 'modCSAStairLang.bas').read_text()
        lang_src.encode('ascii')  # Must stay pure ASCII using ChrW$
        en_block = lang_src.split('Private Function TranslateEn', 1)[1].split('End Function', 1)[0]
        vi_block = lang_src.split('Private Function TranslateVi', 1)[1].split('End Function', 1)[0]
        en_keys = set(re.findall(r'Case "([A-Z0-9_]+)":', en_block))
        vi_keys = set(re.findall(r'Case "([A-Z0-9_]+)":', vi_block))
        self.assertEqual(en_keys, vi_keys)
        self.assertGreaterEqual(len(en_keys), 45)
        ctrl_src = (UI / 'clsCSAStairFormController.cls').read_text()
        self.assertIn('cboLanguage', ctrl_src)
        self.assertIn('ApplyLanguage', ctrl_src)

    def test_phase3_plan_engine_separation_and_host_guard(self):
        geom = (VBA / 'modCSAStairPlanGeom.bas').read_text()
        self.assertLess(geom.rindex('End Type'), geom.index('Public Sub CSA_BuildPlanModel'))
        self.assertNotIn('ThisDrawing', geom)
        self.assertNotIn('ModelSpace', geom)
        draw = (VBA / 'modCSAStairPlanDraw.bas').read_text()
        self.assertIn('Public Sub CSA_DrawPlanModel', draw)
        self.assertLess(draw.index('CSA_HostReady()'), draw.index('CSA_BuildPlanModel'))
        preview = (VBA / 'modCSAStairPreview.bas').read_text()
        self.assertIn('CSA_DrawPlanModel', preview)

    def test_phase4_section_rebar_engine_and_dst_command(self):
        geom = (VBA / 'modCSAStairSectionGeom.bas').read_text()
        self.assertLess(geom.rindex('End Type'), geom.index('Public Sub CSA_BuildSectionModel'))
        self.assertNotIn('ThisDrawing', geom)
        self.assertNotIn('ModelSpace', geom)
        draw = (VBA / 'modCSAStairSectionDraw.bas').read_text()
        self.assertIn('Public Sub CSA_DrawSectionModel', draw)
        self.assertLess(draw.index('CSA_HostReady()'), draw.index('CSA_BuildSectionModel'))
        preview = (VBA / 'modCSAStairPreview.bas').read_text()
        self.assertIn('CSA_DrawSectionModel', preview)
        main = (VBA / 'modCSAStairMain.bas').read_text()
        self.assertIn('Public Sub DST()', main)
        dst_lsp = (TOOLS / 'CSA_DST.lsp').read_text()
        self.assertIn('(defun c:DST', dst_lsp)


if __name__ == '__main__':
    unittest.main()
