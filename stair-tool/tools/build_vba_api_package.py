"""Package the three importable API diagnostic modules, not a compiled DVB."""
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

ROOT = Path(__file__).resolve().parents[1]
FILES = ('modCSAStairHost.bas', 'modCSAStairWinApi.bas',
         'modCSAStairApiTests.bas', 'API-COMPATIBILITY.md')


def build():
    target = ROOT / 'tools' / 'CSA_Stair_VBA_API_2018-2026.zip'
    with ZipFile(target, 'w', compression=ZIP_DEFLATED) as archive:
        for name in FILES:
            source = (ROOT / 'vba' / name).read_text()
            # Portable ANSI-safe BAS exports; CRLF for Windows VBA import.
            payload = (source.replace('\n', '\r\n').encode('ascii')
                       if name.endswith('.bas') else source.encode('utf-8'))
            info = ZipInfo(name, (2026, 11, 15, 0, 0, 0))
            info.compress_type = ZIP_DEFLATED
            archive.writestr(info, payload)
    with ZipFile(target) as archive:
        assert archive.testzip() is None
        assert archive.namelist() == list(FILES)
        for name in FILES:
            assert archive.read(name).decode('utf-8').replace('\r\n', '\n') == (ROOT / 'vba' / name).read_text()
    return target


if __name__ == '__main__':
    print(build())
