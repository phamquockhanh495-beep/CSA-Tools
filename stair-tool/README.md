# CSA Stair Drawing MVP

This directory contains the first isolated implementation for the stair tool. It does not modify the existing CSA `.dvb` files.

## Current runnable milestone: Excel section UI

APPLOAD the single file [`tools/CSA_StairDrawing.lsp`](tools/CSA_StairDrawing.lsp) and run **`CSA_STAIR_DRAWING`**. Read [the workflow and acceptance instructions](tools/STAIR-DRAWING.md). It provides a native DCL dialog, file selection for a workbook already open in Excel, section preview and export to existing CSA layers. No VBA import is required for this milestone.

Version **5.6** replaces rebar LEADER entities with tracked LWPOLYLINE callouts trimmed to the Dot blank circle perimeter. Lower-layer longitudinal stems sit 50 mm to the right of dot stems. The inclined slab thickness dimension is at one third from the lower end. Outer landing lower endpoints stop 20 mm inward from the top return. At the upper junction beam, the four bars follow the confirmed independent routes: flight bottom down at far cover face, flight top into landing top axis minus 10 mm, landing top down at final-riser cover face, landing bottom along flight top axis offset inward 10 mm. These upper-junction anchors measure BJ38*d **from the bend**, plus the existing 2d return hook. See the workflow guide for the current rules; the notes below describe historical versions. Native AutoCAD acceptance remains pending.

The v5.5 interim update uses explicit model-space tick/circle markers, short extension strokes up to 200 mm, and collision-aware placement of rebar label boxes. Guide lines use existing layer 01-GB-Grid. Upper landing leader targets move inward. Native leaders intentionally have their arrows disabled because their visible markers are separate tracked entities. Dimensions keep the real measurement points but native extension lines are suppressed and replaced by short strokes. Redraw after manually changing a leader/dimension; these extra strokes are not associatively attached. v5.5.1 adds the confirmed outer-beam top-bar return down to the lower-body axis at cover; the lower bar terminates straight at cover. This outer return is determined by the two layer elevations, not BJ38.

The v5.4 update uses 200 mm fixed dimension extensions, places the upper chain 775 mm above the upper landing and annotates the flight dimension as count x tread = measured total. Elevation guide lines span both floor levels with aligned Cao do blocks at the right. Lower landing callouts now face right as do the lower flight callouts. Native leaders use AcLeaderType 2 (line with arrow); 0 disables the arrow regardless of its size. Plate tails now reference the lower-body axes: upper tails have a 10 mm inward gap, lower tails coincide. The selected Excel folder persists across sessions after a successful load.

The v5.3.1 hotfix fixes `bad function: 120.0` during preflight: anchorage parameters no longer shadow AutoLISP's LENGTH builtin. The offline evaluator now rejects dynamic value/function symbol collisions; the regression reproduces the original failure with BJ38=10 and d12. Geometric anchorage fit is still checked separately.

The v5.3 update uses BJ38 times the diameter of each bar. Beam embedment is the developed length inside the beam, including the entry run and vertical leg, excluding the 2d return hook and any traversal through a neck outside the beam. Flight bars turn up at the upper beam and down at the lower beam. At unsupported plate joints, both flight tails reference the lower landing axis: upper +10 mm, lower 0 mm. Landing tails similarly reference the lower flight axis: upper +10 mm inward, lower 0 mm. Unsupported necks taller than 100 mm receive a rounded d8a200 tie (centerline R4) and four d8 corner dots with native CSA notes. Free outer landing ends retain the top return and lower cover + 20 mm setback. Layout, enlarged dots, leader arrows and fixed dimension extensions remain available. No binary DVB is included.

The original workbook fixture's upper support does not fit 30d upward anchorage for d12 at cover 25. Preflight reports the end/layer and required length instead of trimming anchors. The workbook is never modified. Native AutoCAD acceptance is still required.

Accepted block scales: `Cao do` **0.25**, `Daucat` **0.01**, `So hieu thep` **0.35**, and `CSA_Sohieu-KCthep` **1.0**. The first three match the user's annotated image; the note block retains its previous sample scale. These are template-specific defaults, not a general DimStyle scaling formula.

This milestone uses the existing section coordinates in `Cau Thang Tools`. Plan geometry, complete reinforcement detailing and a packaged DVB UserForm remain outstanding. An optional centreline draft now uses Excel for longitudinal and landing reinforcement with Excel-driven joint anchorage and 30-degree/2d return hooks, transverse reinforcement dots, and polyline callouts with explicit Architectural tick / Dot blank markers. Step-count labels read U28/AI23 and landing switches read Z23:Z26; see the reinforcement section in the workflow guide. AutoCAD/Excel COM and the UI require validation on Windows; offline tests do not replace that acceptance.

The MVP targets a two-flight U-shaped stair and uses AutoCAD layer `CSA-PREVIEW` for disposable geometry. The same coordinate builder is used for preview and final drawing so the preview is a faithful check of the geometry that will be committed.

## AutoCAD 2018–2027 VBA API & UserForm foundation

AutoCAD 2022 is the primary acceptance baseline across all **10 target releases
(AutoCAD 2018–2027, including `ACADVER` 26.0)**. The source targets full AutoCAD
for Windows x64 with the version-matched VBA Enabler. Read
[`vba/API-COMPATIBILITY.md`](vba/API-COMPATIBILITY.md) for the ten-release matrix,
import instructions, limitations and native smoke tests. Native compile/runtime
acceptance is pending on Windows for all ten releases.

- Download the [API diagnostic source package](tools/CSA_Stair_VBA_API_2018-2027.zip)
  for an isolated host + ActiveX + GDI check (`modCSAStairHost.bas`,
  `modCSAStairWinApi.bas`, `modCSAStairApiTests.bas`). Run
  `CSA_CheckCompatibility`, `CSA_TestVersionMapping`, `CSA_TestFormPreviewApi`,
  then `CSA_TestActiveXApi`.
- Download the [complete VBA UserForm package](tools/CSA_Stair_VBA_UI_2018-2027.zip)
  (all `.bas`/`.cls` normalized to Windows CRLF) for the programmatic `frmCSAStair`
  UI matching `docs/CSA-Stair-Drawing-UI-Mockup.png`, manual Plan View inputs,
  native file picker and live 2D Win32 GDI previews.

## Import order in AutoCAD VBA

0. Import `vba/modCSAStairHost.bas` and `vba/modCSAStairWinApi.bas`.
1. Import `vba/modCSAStairTypes.bas`.
2. Import `vba/modCSAStairLayers.bas`.
3. Import `vba/modCSAStairGeometry.bas` and `vba/modCSAStairFormPreview.bas`.
4. Import `vba/modCSAStairExcel.bas`.
5. Import `vba/modCSAStairLegacy.bas` and `vba/modCSAStairAdapter.bas`.
6. Import `vba/modCSAStairPreview.bas` and `vba/modCSAStairMain.bas`.
7. Import class modules `ui/clsCSAStairFieldWatcher.cls` and `ui/clsCSAStairFormController.cls`.
8. Insert a blank UserForm named `frmCSAStair` and paste `ui/frmCSAStair.code.bas` (see `ui/frmCSAStair.layout.md` — no manual control dragging or `.frx` needed).

If the target CSA project already contains `modCSATheme` and its button class, uncomment `ApplyCSAThemeEx Me, "Stair Drawing", "CSA TOOLS  |  STAIR DRAWING"` at the end of `UserForm_Initialize`. Keep that call commented for projects without the theme dependency.

For the workbook currently in the repository, run `CSA_PreviewCurrentWorkbook`. It reads the calculated `Cau Thang Tools` coordinates from columns `BY/BZ/CA` and draws the existing result on `CSA-PREVIEW` without changing the workbook formulas.

## Current scope

- one-, two- and three-flight stair parameters with manual Plan View inputs in `frmCSAStair`;
- live 2D Win32 GDI preview inside `frmCSAStair` (`Section View` / `Plan View`) plus CAD viewport preview on `CSA-PREVIEW`;
- Excel loader reading `Cau Thang Tools` (attaching to an open Excel session first);
- adapter for the current `3-SIDES` -> `Cau Thang Tools` workbook output (`BY/BZ/CA`);
- explicit cleanup before each preview and before final drawing;
- full concrete/rebar v5.6 engine port to VBA is scheduled for the next phases; Lisp v5.6 remains the runnable reference.

The modules are source artifacts. Building a binary `.dvb` still requires AutoCAD VBA on Windows.

## One-file compatibility route

`CSA_StairCase_Compat.bas` is a single standard module with no UDT declarations. Its public macros use the `CSA_Compat_` prefix (`CSA_Compat_PreviewCurrentWorkbook`, `CSA_Compat_CleanPreview`, `CSA_Compat_StairDraw`) so it can coexist in the same project without name collisions.

## CSA native standards acceptance

For the next test, load only [`tools/CSA_StairStandardsTest.lsp`](tools/CSA_StairStandardsTest.lsp) with APPLOAD. Follow [the test instructions](tools/STAIR-STANDARDS-TEST.md). This is a standards sample panel, not a completed stair drawing. It has a DimStyle picker, four tagged CSA blocks, a sample dimension and targeted cleanup. The tested resource names come from [`standards/csa-profile.json`](standards/csa-profile.json), tied to the user's native CSV export commit.

VBA layer constants now target native CSA layers. Existing layer properties are preserved, only a missing `CSA-PREVIEW` can be created, and new preview geometry is tagged for cleanup. Previously untagged preview geometry is intentionally retained. The standalone compatibility module remains independent of the multi-module sources.

`vba/modCSAStairAdapter.bas` provides `CSA_MissingStandards`, tag-based block insertion helpers and aligned dimensions using an existing style. It has no UDT or Excel dependency; import it together with `modCSAStairHost.bas` for later integration. The Lisp acceptance tool requires no VBA import.

Offline validation: `python3 -m unittest discover -s stair-tool/tests -v`. Fetch the recorded source commit from `origin/main` first if not present locally. These checks compare names/tags/attributes with the native CSV export and inspect source structure; they do not compile VBA or execute AutoCAD.

Version 5.5.2 fixes label-placement aborts: dimension display strokes/text replace solid aggregate dimension bounds, leader obstacles use segments, and the search tries both horizontal directions. After 144 local candidates, an outer clear row is used instead of aborting the section; distant placements print the rebar mark for review. Native AutoCAD verification remains pending.
