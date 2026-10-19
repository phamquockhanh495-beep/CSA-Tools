# `frmCSAStair` layout

Use a standard VBA UserForm sized about 700 x 520 points. The existing CSA theme can add the title bar and colors.

Controls and required names:

| Control | Name | Caption / purpose |
|---|---|---|
| TextBox | `txtStairName` | Stair name |
| ComboBox | `cboStairType` | `2 FLIGHTS - U` |
| TextBox | `txtFloorHeight` | Floor height (mm) |
| TextBox | `txtWidth` | Flight width (mm) |
| TextBox | `txtRiser` | Riser (mm) |
| TextBox | `txtTread` | Tread (mm) |
| TextBox | `txtLanding` | Landing length (mm) |
| TextBox | `txtSlab` | Slab thickness (mm) |
| TextBox | `txtX` | Insert X |
| TextBox | `txtY` | Insert Y |
| CheckBox | `chkDimensions` | Draw dimensions |
| CheckBox | `chkRebar` | Preview reinforcement |
| Label | `lblStatus` | Validation and preview status |
| CommandButton | `cmdLoadExcel` | Load Excel |
| CommandButton | `cmdPreview` | Preview |
| CommandButton | `cmdDrawSection` | Draw section |
| CommandButton | `cmdDrawPlan` | Draw plan |
| CommandButton | `cmdClear` | Clear preview |
| CommandButton | `cmdCancel` | Cancel |

Place the inputs in a left `Frame` named `fraParameters`, the preview instructions in a right `Frame` named `fraPreview`, and the options/buttons along the bottom. The actual preview is the AutoCAD viewport; `fraPreview` displays the active layer and calculated summary.
