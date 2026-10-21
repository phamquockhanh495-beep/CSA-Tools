# CSA Stair Drawing MVP

This directory contains the first isolated implementation for the stair tool. It does not modify the existing CSA `.dvb` files.

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
- no reinforcement design decisions are made by the code. Reinforcement is a separate input contract to be added after the geometry is accepted by the engineer.

The modules are source artifacts. Building a binary `.dvb` with a UserForm still requires AutoCAD VBA on Windows.

## One-file compatibility route

`CSA_StairCase_Compat.bas` is a single standard module with no UDT declarations. Import this one file into a blank DVB or an existing CSA project when the host reports `User-defined type not defined`. It provides `CSA_PreviewCurrentWorkbook`, `CSA_CleanPreviewCommand`, and `CSA_STAIRDRAW` without requiring the other MVP modules.

## CSA native standards acceptance

For the next test, load only [`tools/CSA_StairStandardsTest.lsp`](tools/CSA_StairStandardsTest.lsp) with APPLOAD. Follow [the test instructions](tools/STAIR-STANDARDS-TEST.md). This is a standards sample panel, not a completed stair drawing. It has a DimStyle picker, four tagged CSA blocks, a sample dimension and targeted cleanup. The tested resource names come from [`standards/csa-profile.json`](standards/csa-profile.json), tied to the user's native CSV export commit.

VBA layer constants now target native CSA layers. Existing layer properties are preserved, only a missing `CSA-PREVIEW` can be created, and new preview geometry is tagged for cleanup. Previously untagged preview geometry is intentionally retained. The standalone compatibility module remains independent of the multi-module sources.

`vba/modCSAStairAdapter.bas` provides `CSA_MissingStandards`, tag-based block insertion helpers and aligned dimensions using an existing style. It has no UDT or Excel dependency and can be imported independently for later integration. The Lisp acceptance tool requires no VBA import.

Offline validation: `python3 -m unittest discover -s stair-tool/tests -v`. Fetch the recorded source commit from `origin/main` first if not present locally. These checks compare names/tags/attributes with the native CSV export and inspect source structure; they do not compile VBA or execute AutoCAD.
