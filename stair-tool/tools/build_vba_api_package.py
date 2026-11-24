"""Package importable Windows CRLF VBA bundles (not compiled binary DVBs).

Builds:
  1. tools/CSA_Stair_VBA_API_2018-2027.zip — isolated API & GDI diagnostic set.
  2. tools/CSA_Stair_VBA_UI_2018-2027.zip  — full programmatic UserForm + preview set.
"""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parents[1]

API_FILES = (
    ('vba', 'modCSAStairHost.bas'),
    ('vba', 'modCSAStairWinApi.bas'),
    ('vba', 'modCSAStairApiTests.bas'),
    ('vba', 'API-COMPATIBILITY.md'),
)

UI_FILES = (
    ('vba', 'modCSAStairHost.bas'),
    ('vba', 'modCSAStairWinApi.bas'),
    ('vba', 'modCSAStairLang.bas'),
    ('vba', 'modCSAStairTypes.bas'),
    ('vba', 'modCSAStairLayers.bas'),
    ('vba', 'modCSAStairGeometry.bas'),
    ('vba', 'modCSAStairPlanGeom.bas'),
    ('vba', 'modCSAStairPlanDraw.bas'),
    ('vba', 'modCSAStairFormPreview.bas'),
    ('vba', 'modCSAStairExcel.bas'),
    ('vba', 'modCSAStairLegacy.bas'),
    ('vba', 'modCSAStairAdapter.bas'),
    ('vba', 'modCSAStairPreview.bas'),
    ('vba', 'modCSAStairMain.bas'),
    ('vba', 'modCSAStairApiTests.bas'),
    ('ui', 'clsCSAStairFieldWatcher.cls'),
    ('ui', 'clsCSAStairFormController.cls'),
    ('ui', 'frmCSAStair.code.bas'),
    ('ui', 'frmCSAStair.layout.md'),
    ('vba', 'API-COMPATIBILITY.md'),
    ('tools', 'Update_CSA_Staicase_DVB.vbs'),
)


def _write_bundle(target: Path, entries) -> Path:
    with ZipFile(target, 'w', compression=ZIP_DEFLATED) as archive:
        for folder, name in entries:
            source = (ROOT / folder / name).read_text(encoding='utf-8')
            is_vba = name.endswith(('.bas', '.cls', '.vbs'))
            # Portable ASCII-safe VBA/VBS exports with Windows CRLF.
            payload = (source.replace('\r\n', '\n').replace('\n', '\r\n').encode('ascii')
                       if is_vba else source.encode('utf-8'))
            info = ZipInfo(name, (2026, 11, 24, 0, 0, 0))
            info.compress_type = ZIP_DEFLATED
            archive.writestr(info, payload)
    with ZipFile(target) as archive:
        assert archive.testzip() is None
        assert archive.namelist() == [name for _, name in entries]
        for folder, name in entries:
            raw = archive.read(name)
            if name.endswith(('.bas', '.cls')):
                assert b'\r\n' in raw and b'\n' not in raw.replace(b'\r\n', b'')
            expected = (ROOT / folder / name).read_text(encoding='utf-8').replace('\r\n', '\n')
            assert raw.decode('utf-8').replace('\r\n', '\n') == expected
    return target


def build():
    api_zip = _write_bundle(ROOT / 'tools' / 'CSA_Stair_VBA_API_2018-2027.zip', API_FILES)
    ui_zip = _write_bundle(ROOT / 'tools' / 'CSA_Stair_VBA_UI_2018-2027.zip', UI_FILES)
    return api_zip, ui_zip


if __name__ == '__main__':
    for path in build():
        print(path)
