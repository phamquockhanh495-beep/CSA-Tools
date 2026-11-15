"""Source-contract guards; real VBA/COM tests are shipped as runnable macros.

These tests do not emulate VBA or certify any AutoCAD release.
"""
import re
import unittest
from pathlib import Path

VBA = Path(__file__).resolve().parents[1] / 'vba'


class VbaApiCompatibilityTests(unittest.TestCase):
    def test_release_contract_has_exact_nine_targets_and_primary_2022(self):
        source = (VBA / 'modCSAStairHost.bas').read_text()
        pairs = re.findall(r'Case "([0-9.]+)": CSA_AcadReleaseYear = (\d+)', source)
        expected = [('22.0', '2018'), ('23.0', '2019'), ('23.1', '2020'),
                    ('24.0', '2021'), ('24.1', '2022'), ('24.2', '2023'),
                    ('24.3', '2024'), ('25.0', '2025'), ('25.1', '2026')]
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
        self.assertEqual(vba7.count('Declare PtrSafe'), 3)
        self.assertRegex(vba7, r'GetDC.*ByVal hwnd As LongPtr\) As LongPtr')
        self.assertRegex(vba7, r'ReleaseDC.*hwnd As LongPtr.*hdc As LongPtr\) As Long')
        self.assertRegex(vba7, r'GetDeviceCaps.*hdc As LongPtr.*index As Long\) As Long')
        body = source.split('Public Function CSA_SystemDpiX', 1)[1]
        success, failure = body.split('Failed:', 1)
        self.assertIn('ReleaseDC 0, hdc', success)
        self.assertIn('If hdc <> 0 Then ReleaseDC 0, hdc', failure)

    def test_api_smoke_writes_only_to_disposable_document(self):
        source = (VBA / 'modCSAStairApiTests.bas').read_text()
        self.assertIn('Set original = CSA_CadDocument()', source)
        self.assertIn('Set app = original.Application', source)
        self.assertIn('Set testDoc = app.Documents.Add', source)
        self.assertIn('Set space = testDoc.ModelSpace', source)
        self.assertNotRegex(source, r'original\.(?:Close|Save|SetVariable|ModelSpace|Layers|Blocks)')
        self.assertNotRegex(source, r'\b(?:SaveAs|SendCommand)\b')
        success, failure = source.split('Failed:', 1)
        for branch in (success, failure):
            self.assertIn('testDoc.Close False', branch)
            self.assertIn('original.Activate', branch)
        for api in ('AddLightWeightPolyline', 'AddDimAligned', 'GetBoundingBox',
                    'InsertBlock', 'GetAttributes', 'SetXData', 'GetXData'):
            self.assertIn(api, source)

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


if __name__ == '__main__':
    unittest.main()
