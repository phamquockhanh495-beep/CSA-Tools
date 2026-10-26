# CSA Stair Drawing MVP

This directory contains the first isolated implementation for the stair tool. It does not modify the existing CSA `.dvb` files.

## Current runnable milestone: Excel section UI

APPLOAD the single file [`tools/CSA_StairDrawing.lsp`](tools/CSA_StairDrawing.lsp) and run **`CSA_STAIR_DRAWING`**. Read [the workflow and acceptance instructions](tools/STAIR-DRAWING.md). It provides a native DCL dialog, file selection for a workbook already open in Excel, section preview and export to existing CSA layers. No VBA import is required for this milestone.

The v5.5 interim update uses explicit model-space tick/circle markers, short extension strokes up to 200 mm, and collision-aware placement of rebar label boxes. Guide lines use existing layer 01-GB-Grid. Upper landing leader targets move inward. Native leaders intentionally have their arrows disabled because their visible markers are separate tracked entities. Dimensions keep the real measurement points but native extension lines are suppressed and replaced by short strokes. Redraw after manually changing a leader/dimension; these extra strokes are not associatively attached. v5.5.1 adds the confirmed outer-beam top-bar return down to the lower-body axis at cover; the lower bar terminates straight at cover. This outer return is determined by the two layer elevations, not BJ38.

The v5.4 update uses 200 mm fixed dimension extensions, places the upper chain 775 mm above the upper landing and annotates the flight dimension as count x tread = measured total. Elevation guide lines span both floor levels with aligned Cao do blocks at the right. Lower landing callouts now face right as do the lower flight callouts. Native leaders use AcLeaderType 2 (line with arrow); 0 disables the arrow regardless of its size. Plate tails now reference the lower-body axes: upper tails have a 10 mm inward gap, lower tails coincide. The selected Excel folder persists across sessions after a successful load.

The v5.3.1 hotfix fixes `bad function: 120.0` during preflight: anchorage parameters no longer shadow AutoLISP's LENGTH builtin. The offline evaluator now rejects dynamic value/function symbol collisions; the regression reproduces the original failure with BJ38=10 and d12. Geometric anchorage fit is still checked separately.

The v5.3 update uses BJ38 times the diameter of each bar. Beam embedment is the developed length inside the beam, including the entry run and vertical leg, excluding the 2d return hook and any traversal through a neck outside the beam. Flight bars turn up at the upper beam and down at the lower beam. At unsupported plate joints, both flight tails reference the lower landing axis: upper +10 mm, lower 0 mm. Landing tails similarly reference the lower flight axis: upper +10 mm inward, lower 0 mm. Unsupported necks taller than 100 mm receive a rounded d8a200 tie (centerline R4) and four d8 corner dots with native CSA notes. Free outer landing ends retain the top return and lower cover + 20 mm setback. Layout, enlarged dots, leader arrows and fixed dimension extensions remain available. No binary DVB is included.

The original workbook fixture's upper support does not fit 30d upward anchorage for d12 at cover 25. Preflight reports the end/layer and required length instead of trimming anchors. The workbook is never modified. Native AutoCAD acceptance is still required.

Accepted block scales: `Cao do` **0.25**, `Daucat` **0.01**, `So hieu thep` **0.35**, and `CSA_Sohieu-KCthep` **1.0**. The first three match the user's annotated image; the note block retains its previous sample scale. These are template-specific defaults, not a general DimStyle scaling formula.

This milestone uses the existing section coordinates in `Cau Thang Tools`. Plan geometry, complete reinforcement detailing and a packaged DVB UserForm remain outstanding. An optional centreline draft now uses Excel for longitudinal and landing reinforcement with Excel-driven joint anchorage and 30-degree/2d return hooks, transverse reinforcement dots, and native leaders (Architectural tick / Dot blank). Step-count labels read U28/AI23 and landing switches read Z23:Z26; see the reinforcement section in the workflow guide. AutoCAD/Excel COM and the UI require validation on Windows; offline tests do not replace that acceptance.

The MVP targets a two-flight U-shaped stair and uses AutoCAD layer `CSA-PREVIEW` for disposable geometry. The same coordinate builder is used for preview and final drawing so the preview is a faithful check of the geometry that will be committed.

## Import order in AutoCAD VBA

1. Import `vba/modCSAStairTypes.bas`.
2. Import `vba/modCSAStairLayers.bas`.
3. Import `vba/modCSAStairGeometry.bas`.
4. Import `vba/modCSAStairExcel.bas`.
5. Import `vba/modCSAStairLegacy.bas` when using the workbook currently in this repository.
6. Import `vba/modCSAStairPreview.bas`.
7. Import `vba/modCSAStairMain.bas`.
8. Add the controls described in `ui/frmCSAStair.layout.md` and paste `ui/frmCSAStair.code.bas` into the form code module.

If the target CSA project already contains `modCSATheme` and its button class, uncomment `ApplyCSAThemeEx Me, "Stair Drawing", "CSA TOOLS  |  STAIR DRAWING"` at the end of `UserForm_Initialize`. Keep that call commented for projects without the theme dependency.

For the workbook currently in the repository, run `CSA_PreviewCurrentWorkbook`. It reads the calculated `Cau Thang Tools` coordinates from columns `BY/BZ/CA` and draws the existing result on `CSA-PREVIEW` without changing the workbook formulas.

## Current scope

- two-flight U-shaped geometry;
- section and plan preview on `CSA-PREVIEW`;
- named Excel inputs with safe defaults;
- adapter for the current `3-SIDES` -> `Cau Thang Tools` workbook output (`BY/BZ/CA`);
- explicit cleanup before each preview and before final drawing;
- reinforcement follows the confirmed Excel/drafting rules; the tool does not calculate reinforcement design or a fabrication schedule.

The modules are source artifacts. Building a binary `.dvb` with a UserForm still requires AutoCAD VBA on Windows.

## One-file compatibility route

`CSA_StairCase_Compat.bas` is a single standard module with no UDT declarations. Import this one file into a blank DVB or an existing CSA project when the host reports `User-defined type not defined`. It provides `CSA_PreviewCurrentWorkbook`, `CSA_CleanPreviewCommand`, and `CSA_STAIRDRAW` without requiring the other MVP modules.

## CSA native standards acceptance

For the next test, load only [`tools/CSA_StairStandardsTest.lsp`](tools/CSA_StairStandardsTest.lsp) with APPLOAD. Follow [the test instructions](tools/STAIR-STANDARDS-TEST.md). This is a standards sample panel, not a completed stair drawing. It has a DimStyle picker, four tagged CSA blocks, a sample dimension and targeted cleanup. The tested resource names come from [`standards/csa-profile.json`](standards/csa-profile.json), tied to the user's native CSV export commit.

VBA layer constants now target native CSA layers. Existing layer properties are preserved, only a missing `CSA-PREVIEW` can be created, and new preview geometry is tagged for cleanup. Previously untagged preview geometry is intentionally retained. The standalone compatibility module remains independent of the multi-module sources.

`vba/modCSAStairAdapter.bas` provides `CSA_MissingStandards`, tag-based block insertion helpers and aligned dimensions using an existing style. It has no UDT or Excel dependency and can be imported independently for later integration. The Lisp acceptance tool requires no VBA import.

Offline validation: `python3 -m unittest discover -s stair-tool/tests -v`. Fetch the recorded source commit from `origin/main` first if not present locally. These checks compare names/tags/attributes with the native CSV export and inspect source structure; they do not compile VBA or execute AutoCAD.
