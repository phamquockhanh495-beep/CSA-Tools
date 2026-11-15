# VBA API target: AutoCAD 2018–2026

AutoCAD **2022** is the user's primary acceptance version. The common-source
target is **full AutoCAD for Windows x64 with the matching Autodesk VBA Enabler**.
AutoCAD LT, macOS and 32-bit AutoCAD are outside this package's target.
This is a compatibility foundation, not a completed WPF-style UserForm or a
certified binary `.dvb`. The Lisp v5.6 drawing implementation is unchanged.

## Release detection and test status

| AutoCAD | ACADVER major.minor | Native VBA/API/UserForm acceptance |
|---|---|---|
| 2018 | 22.0 | Pending |
| 2019 | 23.0 | Pending |
| 2020 | 23.1 | Pending |
| 2021 | 24.0 | Pending |
| **2022** | **24.1** | **Primary target; pending** |
| 2023 | 24.2 | Pending |
| 2024 | 24.3 | Pending |
| 2025 | 25.0 | Pending |
| 2026 | 25.1 | Pending |

Detection uses the drawing's `ACADVER`, including values with a suffix such as
`24.1s (LMS Tech)`. Unknown major/minor versions fail preflight instead of being
assumed compatible. Marketing years, DWG file-format versions and the installed
Excel version are not used as substitutes for the AutoCAD API version.

## Modules

- `modCSAStairHost.bas`: release/bitness checks, host document access, shared
  constants and typed `SAFEARRAY(Double)` points. It uses `ThisDrawing` from
  the hosting VBA session. It never attaches to another AutoCAD instance with
  `GetObject` or launches one with `CreateObject`.
- `modCSAStairWinApi.bas`: `PtrSafe` and `LongPtr` declarations for handles;
  Win32 `int`/`LONG` parameters remain `Long`. Includes system-DPI querying and
  pixels-to-MSForms-points conversion. The screen DC is released on both paths.
  This is a system-DPI baseline, not per-monitor DPI handling or a GDI preview
  renderer. Form units (points), preview pixels and CAD model units (mm) stay
  separate.
- `modCSAStairApiTests.bas`: release-parser tests and an explicit ActiveX/GDI
  smoke-test command. The latter writes only to a new unsaved drawing, then
  closes it without saving and reactivates the original document.

The existing multi-module VBA UI/preview commands now run host preflight before
opening the form or editing the drawing. Existing native block and dimension
adapter entry points also run that check. The independent historical
`CSA_StairCase_Compat.bas` keeps its old standalone contract; it is not the new
cross-version API package and does not receive these dependencies.

## What late binding does and does not solve

CAD entities and Excel automation variables use `Object` to limit dependencies
on version-specific COM type declarations. The VBA host still requires its own
AutoCAD and MSForms references. Late binding cannot repair a **MISSING** project
reference or make a VBA runtime work without the appropriate VBA Enabler.

Keep one source set. Compile and test within each target AutoCAD host; inspect
Tools → References in VBAIDE when moving the project between releases. If the
same DVB fails to load/rebind, build a host-specific DVB from that source. Do not
promise a single binary works on all nine releases before testing it. This
foundation needs no C#/.NET helper DLL, optional OCX grid, or embedded browser.

## First test on AutoCAD 2022

1. Install the Autodesk VBA Enabler matching AutoCAD 2022, if not already present.
2. Run `VBAIDE`, create a **separate test project**, and import only the three
   `.bas` files listed above. The API checks do not need `frmCSAStair`.
3. Inspect Tools → References, then Debug → Compile. Resolve missing host
   references before running a macro.
4. Run `CSA_CheckCompatibility`: expect AutoCAD 2022 / ACADVER 24.1 / x64.
   This is read-only and only checks host access.
5. Run `CSA_TestVersionMapping`: tests all nine release keys, suffixes, patches,
   empty input and unsupported releases. It does not run nine AutoCAD versions.
6. Run `CSA_TestActiveXApi`: checks line/polyline/circle/text creation, aligned
   dimension measurement and extension suppression, bounding boxes, editable
   block attributes, XData, redraw and Windows DPI. A new test drawing is
   created temporarily. If cleanup fails, the message identifies that drawing
   should be closed without saving; user drawings are never closed by the test.
7. Record pass/fail, full AutoCAD build, VBA Enabler version, Windows version and
   display scale. Then perform the same procedure on other target releases.

Existing prototype integration: import `modCSAStairHost.bas` before the old
multi-module MVP modules. Add the Windows API and API-test modules for diagnostics.
The form still must be created according to `ui/frmCSAStair.layout.md`; this
change does not create a binary UserForm or port the v5.6 reinforcement engine.

## Further acceptance before shipping the UserForm

Test UI at 100%, 125%, 150% and 200% display scale, multiple drawings and multiple
AutoCAD instances, cancel/error cleanup, CSA block fonts/scales, Excel import,
preview updates and final output. The smoke test is deliberately narrower:
passing it establishes only those API operations, not complete stair behavior.
Native compile/runtime acceptance cannot be performed in the Linux workspace.

Offline verification: `python3 -m unittest discover -s stair-tool/tests -v`.
These include release-table and declaration/integration guards; they do not
compile VBA or execute COM/GDI.
