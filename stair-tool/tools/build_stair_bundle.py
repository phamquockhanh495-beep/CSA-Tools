"""Build a single APPLOAD file with no external Lisp or DCL dependencies."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def bundle():
    helpers = (ROOT / 'tools/CSA_StairStandardsTest.lsp').read_text()
    details = (ROOT / 'ui/CSA_StairConcreteDetails.lsp').read_text()
    core = (ROOT / 'ui/CSA_StairDrawing.core.lsp').read_text()
    return (';;; Generated standalone CSA Stair Drawing; do not edit this bundle.\n'
            ';;; Source: standards helpers + ui/CSA_StairConcreteDetails.lsp + ui/CSA_StairDrawing.core.lsp\n'
            + helpers + '\n' + details + '\n' + core)


if __name__ == '__main__':
    path = ROOT / 'tools/CSA_StairDrawing.lsp'
    path.write_text(bundle())
    print(path)
