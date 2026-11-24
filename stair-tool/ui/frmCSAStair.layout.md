# `frmCSAStair` setup (Zero-drag programmatic UserForm)

`frmCSAStair` now builds all controls at runtime via [`clsCSAStairFormController.cls`](clsCSAStairFormController.cls) and [`clsCSAStairFieldWatcher.cls`](clsCSAStairFieldWatcher.cls). You **do not** need to drag controls manually or ship a binary `.frx` file across AutoCAD 2018–2027.

## 1-minute setup in AutoCAD VBAIDE

1. Import the standard `.bas` modules and `.cls` class modules in order:
   - `vba/modCSAStairHost.bas`
   - `vba/modCSAStairWinApi.bas`
   - `vba/modCSAStairLang.bas`
   - `vba/modCSAStairTypes.bas`
   - `vba/modCSAStairLayers.bas`
   - `vba/modCSAStairGeometry.bas`
   - `vba/modCSAStairPlanGeom.bas`
   - `vba/modCSAStairPlanDraw.bas`
   - `vba/modCSAStairFormPreview.bas`
   - `vba/modCSAStairExcel.bas`
   - `vba/modCSAStairLegacy.bas`
   - `vba/modCSAStairAdapter.bas`
   - `vba/modCSAStairPreview.bas`
   - `vba/modCSAStairMain.bas`
   - `vba/modCSAStairApiTests.bas`
   - `ui/clsCSAStairFieldWatcher.cls`
   - `ui/clsCSAStairFormController.cls`
2. In VBAIDE, choose **Insert → UserForm**.
3. In the Properties window, change `(Name)` to **`frmCSAStair`**. Leave the form blank.
4. Double-click the blank form, replace all code with [`ui/frmCSAStair.code.bas`](frmCSAStair.code.bas) (excluding the first `Attribute VB_Name` line).
5. Run **Debug → Compile**. If VBA reports `User-defined type not defined` on `MSForms.TextBox` and `Microsoft Forms 2.0 Object Library` is not visible in **Tools → References**:
   - Click **Browse…** in **Tools → References** and open `C:\Program Files\Microsoft Office\Root\VFS\System\FM20.DLL` (Office x64 Click-to-Run) or `C:\Windows\System32\FM20.DLL`.
   - Or open `frmCSAStair` in Design view, drop one temporary control from the Toolbox onto the form and delete it; VBA will bind `Microsoft Forms 2.0 Object Library` automatically.
6. Run macro **`CSA_STAIRDRAW`** (or `CSA_StairTools`).

## Layout built at runtime (matches `docs/CSA-Stair-Drawing-UI-Mockup.png`)

- **Header:** CSA stair vector emblem, `Stair Drawing`, `CSA TOOLS | STAIR DRAWING`, `Author: CoAnTran`.
- **Left panel (`Stair Parameters`):**
  - **General tab:** `Stair Name`, `Stair Type` (`Two Flight (With Landing)`, `Three Flight`, `Single Flight`), `Width (mm)`, `Bottom Elev. (m)`, `Top Elev. (m)`, `Riser (mm)`, `Tread (mm)`, `Slab Thick. (mm)`, `Scale`.
  - **Plan & CAD tab (manual Plan inputs):** `Flight 1/2/3 Risers`, `Mid Landing`, `Upper Landing`, `Well Gap`, `Support Width`, `Start Direction (UP/DN)`, `Section Mark`, `DimStyle` (loaded from active DWG), `Insert X / Y` + `Pick` button.
- **Right panel (`Preview`):**
  - `MultiPage` with **Section View** and **Plan View** tabs rendering live 2D vector bitmaps via Win32 GDI (`modCSAStairFormPreview.bas`).
  - Summary bar (`24 RISERS (12+12) | RISE 150 | TREAD 300 | WIDTH 1200`) and live validation status line.
- **Bottom bar:** `Options` (`Draw Dimensions`, `Draw Reinforcement`, `Create Layers`, `Open Excel`) and buttons (`Load Excel`, `Preview`, `Draw Section`, `Draw Plan`, `Clear`, `Cancel`).
