# VBA API target: AutoCAD 2018–2027

AutoCAD **2022** is the primary acceptance baseline, with full common-source
targeting across all **10 releases from AutoCAD 2018 through AutoCAD 2027**.
The target platform is **full AutoCAD for Windows x64 with the version-matched
Autodesk VBA Enabler**. AutoCAD LT, macOS and 32-bit AutoCAD are outside this
package's target. The Lisp v5.6 drawing implementation remains unchanged as the
reference baseline while the full VBA engine is ported.

## Release detection and test status

| AutoCAD | ACADVER major.minor | Native VBA/API/UserForm acceptance |
|---|---|---|
| 2018 | 22.0 | Pending |
| 2019 | 23.0 | Pending |
| 2020 | 23.1 | Pending |
| 2021 | 24.0 | Pending |
| **2022** | **24.1** | **Primary baseline; pending** |
| 2023 | 24.2 | Pending |
| **2024** | **24.3** | **Passed (API/GDI/UserForm; 24.3s, Win x64, DPI=110)** |
| 2025 | 25.0 | Pending |
| 2026 | 25.1 | Pending |
| **2027** | **26.0** | **Target release; pending** |

Detection uses the drawing's `ACADVER`, including values with a suffix such as
`24.1s (LMS Tech)` or `26.0.60.0`. Unknown major/minor versions fail preflight
instead of being assumed compatible. Marketing years, DWG file-format versions
and the installed Excel version are not used as substitutes for the AutoCAD API
version.

## Modules

- `modCSAStairHost.bas`: release/bitness checks (2018–2027), host document
  access, shared constants and typed `SAFEARRAY(Double)` points. Uses
  `ThisDrawing` from the hosting VBA session and never attaches to another
  AutoCAD instance with `GetObject` or launches one with `CreateObject`.
- `modCSAStairWinApi.bas`: `PtrSafe` and `LongPtr` declarations for handles;
  Win32 `int`/`LONG` parameters remain `Long`. Provides system-DPI querying,
  pixels/points conversions, native Unicode file picker (`GetOpenFileNameW`),
  and offscreen Win32 GDI canvas + `OleCreatePictureIndirect` (`IPictureDisp`)
  conversion for flicker-free 2D vector previews in `frmCSAStair`.
- `modCSAStairApiTests.bas`: release-parser tests (all 10 versions 2018–2027),
  an explicit ActiveX smoke test (`CSA_TestActiveXApi` on a disposable unsaved
  drawing), and an offscreen GDI/OLE preview test (`CSA_TestFormPreviewApi`).
- `modCSAStairFormPreview.bas` + `clsCSAStairFormController.cls` +
  `clsCSAStairFieldWatcher.cls`: zero-`.frx` programmatic UserForm matching
  `docs/CSA-Stair-Drawing-UI-Mockup.png` with manual Plan View inputs and live
  2D GDI previews.

The historical standalone `CSA_StairCase_Compat.bas` now prefixes its public
macros with `CSA_Compat_` so it can coexist in the same VBA project without
`Ambiguous name` compile errors.

## What late binding does and does not solve

CAD entities and Excel automation variables use `Object` to limit dependencies
on version-specific COM type declarations. The VBA host still requires its own
AutoCAD and MSForms (`Microsoft Forms 2.0 Object Library`) references. Late
binding cannot repair a **MISSING** project reference or make VBA run without
the matching VBA Enabler for that AutoCAD year.

Keep one source set. Compile and test within each target AutoCAD host; inspect
**Tools → References** in VBAIDE when moving the project between releases. If
one compiled `.dvb` fails to rebind across major versions (e.g., 2022 → 2027),
compile a host-specific `.dvb` from this same source set. No C#/.NET helper
DLL, third-party OCX grid, or embedded browser is required.

## First test on AutoCAD 2022 / 2027

1. Install the Autodesk VBA Enabler matching your AutoCAD release.
2. Open `VBAIDE`, create a **separate test project**, and import:
   - `modCSAStairHost.bas`
   - `modCSAStairWinApi.bas`
   - `modCSAStairApiTests.bas`
3. Inspect **Tools → References**, then run **Debug → Compile**.
4. Run `CSA_CheckCompatibility` (read-only host check).
5. Run `CSA_TestVersionMapping` (verifies all 10 release keys 2018–2027).
6. Run `CSA_TestFormPreviewApi` (verifies Win32 GDI bitmap + `IPictureDisp`
   without touching any DWG).
7. Run `CSA_TestActiveXApi` (creates and closes an unsaved test drawing).
8. Record pass/fail, full AutoCAD build, VBA Enabler version, Windows version
   and display scale (100% / 125% / 150% / 200%).

## Testing the interactive UserForm (`frmCSAStair`)

Download `tools/CSA_Stair_VBA_UI_2018-2027.zip` (all `.bas`/`.cls` files
normalized to Windows CRLF) and follow `ui/frmCSAStair.layout.md` to create a
blank UserForm named `frmCSAStair`, paste `frmCSAStair.code.bas`, compile, and
run `CSA_STAIRDRAW`.

Offline verification: `python3 -m unittest stair-tool/tests/test_vba_api_compatibility.py -v`.
