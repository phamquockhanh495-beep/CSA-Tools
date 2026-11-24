VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "clsCSAStairFormController"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Explicit

' Programmatic MSForms controller for frmCSAStair.
' Builds all controls at runtime (zero binary .frx dependency) matching
' docs/CSA-Stair-Drawing-UI-Mockup.png, with bilingual EN/VI toggle,
' manual Plan & Rebar settings, and direct pick-point-and-draw workflow.

Private Const CLR_NAVY As Long = &H82491B       ' #1B4982
Private Const CLR_FORM_BG As Long = &HF8F5F2    ' Light neutral canvas
Private Const CLR_CARD_BG As Long = &HFFFFFF    ' White card
Private Const CLR_SUMMARY_BG As Long = &HEBE5DF ' Summary bar grey
Private Const CLR_ACCENT_BTN As Long = &HF8E6D6 ' Soft blue highlight for Preview
Private Const CLR_TEXT_DARK As Long = &H382818
Private Const CLR_TEXT_MUTED As Long = &H786858
Private Const CLR_ERR_RED As Long = &H2222C0

Private Const REG_APP As String = "CSATools"
Private Const REG_SECTION As String = "StairDrawing"

Private mForm As Object
Private mWatchers As Collection
Private mUpdating As Boolean

' Header & language selector
Private lblTitle As MSForms.Label
Private lblSubTitle As MSForms.Label
Private WithEvents cboLanguage As MSForms.ComboBox
Private lblParamsHdr As MSForms.Label
Private lblPreviewHdr As MSForms.Label
Private lblOptionsHdr As MSForms.Label

' Caption labels (stored so ApplyLanguage updates everything live)
Private lblStairName As MSForms.Label
Private lblStairType As MSForms.Label
Private lblWidth As MSForms.Label
Private lblBottomElev As MSForms.Label
Private lblTopElev As MSForms.Label
Private lblRiser As MSForms.Label
Private lblTread As MSForms.Label
Private lblSlab As MSForms.Label
Private lblScale As MSForms.Label
Private lblFlight1 As MSForms.Label
Private lblLanding As MSForms.Label
Private lblUpperLanding As MSForms.Label
Private lblWellGap As MSForms.Label
Private lblSupportWidth As MSForms.Label
Private lblDirection As MSForms.Label
Private lblSectionMark As MSForms.Label
Private lblDimStyle As MSForms.Label
Private lblCover As MSForms.Label
Private lblMainBar As MSForms.Label
Private lblDistBar As MSForms.Label
Private lblAnchorSym As MSForms.Label

' Parameter controls - General tab (mockup 1:1)
Private txtStairName As MSForms.TextBox
Private WithEvents cboStairType As MSForms.ComboBox
Private txtWidth As MSForms.TextBox
Private txtBottomElev As MSForms.TextBox
Private txtTopElev As MSForms.TextBox
Private txtRiser As MSForms.TextBox
Private txtTread As MSForms.TextBox
Private txtSlab As MSForms.TextBox
Private WithEvents cboScale As MSForms.ComboBox

' Parameter controls - Details & Rebar tab (manual plan + rebar inputs, no X/Y boxes)
Private txtFlight1 As MSForms.TextBox
Private txtFlight2 As MSForms.TextBox
Private txtFlight3 As MSForms.TextBox
Private txtLanding As MSForms.TextBox
Private txtUpperLanding As MSForms.TextBox
Private txtWellGap As MSForms.TextBox
Private txtSupportWidth As MSForms.TextBox
Private WithEvents cboDirection As MSForms.ComboBox
Private txtSectionMark As MSForms.TextBox
Private WithEvents cboDimStyle As MSForms.ComboBox
Private txtCover As MSForms.TextBox
Private txtMainBar As MSForms.TextBox
Private txtDistBar As MSForms.TextBox
Private txtAnchorFactor As MSForms.TextBox
Private WithEvents cboBarSymbol As MSForms.ComboBox

' Preview & status controls
Private WithEvents mpgParams As MSForms.MultiPage
Private WithEvents mpgPreview As MSForms.MultiPage
Private imgLogo As MSForms.Image
Private imgSectionPreview As MSForms.Image
Private imgPlanPreview As MSForms.Image
Private lblSummary As MSForms.Label
Private lblStatus As MSForms.Label

' Options controls
Private WithEvents chkDimensions As MSForms.CheckBox
Private WithEvents chkRebar As MSForms.CheckBox
Private WithEvents chkCreateLayers As MSForms.CheckBox
Private WithEvents chkOpenExcel As MSForms.CheckBox

' Action buttons
Private WithEvents cmdLoadExcel As MSForms.CommandButton
Private WithEvents cmdPreview As MSForms.CommandButton
Private WithEvents cmdDrawSection As MSForms.CommandButton
Private WithEvents cmdDrawPlan As MSForms.CommandButton
Private WithEvents cmdClear As MSForms.CommandButton
Private WithEvents cmdCancel As MSForms.CommandButton

Public Sub Attach(ByVal form As Object)
    Set mForm = form
    Set mWatchers = New Collection
    mUpdating = True
    CSA_SetLanguage GetSetting(REG_APP, REG_SECTION, "Language", CSA_LANG_EN)
    BuildLayout
    LoadCadDimStyles
    LoadSavedPreferences gCSAStair
    ApplyLanguage
    WriteForm gCSAStair
    mUpdating = False
    RefreshPreview
End Sub

Public Sub Detach()
    Dim w As clsCSAStairFieldWatcher
    On Error Resume Next
    If Not mWatchers Is Nothing Then
        For Each w In mWatchers
            w.Unbind
        Next w
    End If
    Set mWatchers = Nothing
    Set imgLogo = Nothing
    Set imgSectionPreview = Nothing
    Set imgPlanPreview = Nothing
    Set mForm = Nothing
End Sub

Private Sub BuildLayout()
    Dim hdr As MSForms.Frame
    Dim leftPanel As MSForms.Frame, rightPanel As MSForms.Frame, optPanel As MSForms.Frame
    Dim lblAuthor As MSForms.Label
    Dim pageGen As Object, pagePlan As Object
    Dim rowY As Double, rowStep As Double

    mForm.Caption = "Stair Drawing  |  CSA Tools"
    mForm.Width = 768
    mForm.Height = 548
    mForm.BackColor = CLR_FORM_BG
    mForm.Font.Name = "Segoe UI"
    mForm.Font.Size = 9

    ' --- Header Bar ---
    Set hdr = AddFrame(mForm, "fraHeader", 0, 0, 764, 52, CLR_CARD_BG)
    Set imgLogo = hdr.Controls.Add("Forms.Image.1", "imgLogo", True)
    imgLogo.Left = 12: imgLogo.Top = 8: imgLogo.Width = 36: imgLogo.Height = 36
    imgLogo.BorderStyle = 0
    imgLogo.BackColor = CLR_CARD_BG
    imgLogo.PictureSizeMode = 0
    On Error Resume Next
    Set imgLogo.Picture = CSA_RenderStairIconBitmap(CSA_FormPointsToPixels(36#), CSA_FormPointsToPixels(36#))
    On Error GoTo 0

    Set lblTitle = AddLabel(hdr, "lblTitle", "Stair Drawing", 56, 6, 280, 24, 15, True, CLR_NAVY)
    Set lblSubTitle = AddLabel(hdr, "lblSubTitle", "CSA TOOLS  |  STAIR DRAWING", 56, 30, 280, 14, 8, False, CLR_TEXT_MUTED)

    ' Language selector (English / Tieng Viet)
    Set cboLanguage = hdr.Controls.Add("Forms.ComboBox.1", "cboLanguage", True)
    cboLanguage.Left = 510: cboLanguage.Top = 15: cboLanguage.Width = 104: cboLanguage.Height = 20
    cboLanguage.Font.Name = "Segoe UI": cboLanguage.Font.Size = 8.5
    cboLanguage.Style = 2 ' fmStyleDropDownList
    cboLanguage.AddItem CSA_Tr("EN_NAME")
    cboLanguage.AddItem CSA_Tr("VI_NAME")
    cboLanguage.ListIndex = IIf(CSA_CurrentLang() = CSA_LANG_VI, 1, 0)

    Set lblAuthor = AddLabel(hdr, "lblAuthor", "Author: CoAnTran", 622, 18, 128, 16, 9, True, CLR_NAVY)
    lblAuthor.Font.Italic = True
    lblAuthor.TextAlign = 3 ' fmTextAlignRight

    ' --- Left Panel: Stair Parameters ---
    Set leftPanel = AddFrame(mForm, "fraParameters", 10, 58, 256, 366, CLR_CARD_BG)
    Set lblParamsHdr = AddSectionBanner(leftPanel, "lblParamsHdr", "  Stair Parameters", 254)

    Set mpgParams = leftPanel.Controls.Add("Forms.MultiPage.1", "mpgParams", True)
    mpgParams.Left = 4: mpgParams.Top = 24: mpgParams.Width = 246: mpgParams.Height = 336
    mpgParams.Font.Name = "Segoe UI": mpgParams.Font.Size = 8.5

    ' Page 0: General parameters (matching mockup 1:1)
    Set pageGen = mpgParams.Pages(0)
    rowY = 10: rowStep = 31
    Set txtStairName = AddLabeledText(pageGen, "Stair Name:", "txtStairName", rowY, 96, 134, "", "name", lblStairName)
    rowY = rowY + rowStep
    Set cboStairType = AddLabeledCombo(pageGen, "Stair Type:", "cboStairType", rowY, 96, 134, lblStairType)
    rowY = rowY + rowStep
    Set txtWidth = AddLabeledText(pageGen, "Width (mm):", "txtWidth", rowY, 96, 134, "", "width", lblWidth)
    rowY = rowY + rowStep
    Set txtBottomElev = AddLabeledText(pageGen, "Bottom Elev.:", "txtBottomElev", rowY, 96, 114, "m", "elev", lblBottomElev)
    rowY = rowY + rowStep
    Set txtTopElev = AddLabeledText(pageGen, "Top Elev.:", "txtTopElev", rowY, 96, 114, "m", "elev", lblTopElev)
    rowY = rowY + rowStep
    Set txtRiser = AddLabeledText(pageGen, "Riser (mm):", "txtRiser", rowY, 96, 134, "", "riser", lblRiser)
    rowY = rowY + rowStep
    Set txtTread = AddLabeledText(pageGen, "Tread (mm):", "txtTread", rowY, 96, 134, "", "tread", lblTread)
    rowY = rowY + rowStep
    Set txtSlab = AddLabeledText(pageGen, "Slab Thick. (mm):", "txtSlab", rowY, 96, 134, "", "slab", lblSlab)
    rowY = rowY + rowStep
    Set cboScale = AddLabeledCombo(pageGen, "Scale:", "cboScale", rowY, 96, 134, lblScale)
    cboScale.AddItem "1:25"
    cboScale.AddItem "1:50"
    cboScale.AddItem "1:75"
    cboScale.AddItem "1:100"

    ' Page 1: Manual Plan View & Rebar settings (direct viewport pick replaces X/Y boxes)
    Set pagePlan = mpgParams.Pages(1)
    rowY = 8: rowStep = 25
    ' Compact 3-flight riser counts on one row
    Set txtFlight1 = AddLabeledText(pagePlan, "Flights 1/2/3:", "txtFlight1", rowY, 102, 38, "", "flight", lblFlight1)
    Set txtFlight2 = AddSmallText(pagePlan, "txtFlight2", 144, rowY, 38, "flight")
    Set txtFlight3 = AddSmallText(pagePlan, "txtFlight3", 186, rowY, 44, "flight")
    rowY = rowY + rowStep
    Set txtLanding = AddLabeledText(pagePlan, "Mid Landing (mm):", "txtLanding", rowY, 108, 122, "", "plan", lblLanding)
    rowY = rowY + rowStep
    Set txtUpperLanding = AddLabeledText(pagePlan, "Upper Landing:", "txtUpperLanding", rowY, 108, 122, "", "plan", lblUpperLanding)
    rowY = rowY + rowStep
    Set txtWellGap = AddLabeledText(pagePlan, "Well Gap (mm):", "txtWellGap", rowY, 108, 122, "", "plan", lblWellGap)
    rowY = rowY + rowStep
    Set txtSupportWidth = AddLabeledText(pagePlan, "Support Width:", "txtSupportWidth", rowY, 108, 122, "", "plan", lblSupportWidth)
    rowY = rowY + rowStep
    Set cboDirection = AddLabeledCombo(pagePlan, "Start Direction:", "cboDirection", rowY, 108, 122, lblDirection)
    cboDirection.AddItem "UP"
    cboDirection.AddItem "DN"
    rowY = rowY + rowStep
    Set txtSectionMark = AddLabeledText(pagePlan, "Section Mark:", "txtSectionMark", rowY, 108, 122, "", "mark", lblSectionMark)
    rowY = rowY + rowStep
    Set cboDimStyle = AddLabeledCombo(pagePlan, "DimStyle:", "cboDimStyle", rowY, 108, 122, lblDimStyle)
    rowY = rowY + rowStep
    Set txtCover = AddLabeledText(pagePlan, "Cover (mm):", "txtCover", rowY, 108, 122, "", "rebar", lblCover)
    rowY = rowY + rowStep
    Set txtMainBar = AddLabeledText(pagePlan, "Main Rebar:", "txtMainBar", rowY, 108, 122, "", "rebar", lblMainBar)
    rowY = rowY + rowStep
    Set txtDistBar = AddLabeledText(pagePlan, "Dist. Rebar:", "txtDistBar", rowY, 108, 122, "", "rebar", lblDistBar)
    rowY = rowY + rowStep
    Set txtAnchorFactor = AddLabeledText(pagePlan, "Anchor / Sym:", "txtAnchorFactor", rowY, 108, 54, "", "rebar", lblAnchorSym)
    Set cboBarSymbol = pagePlan.Controls.Add("Forms.ComboBox.1", "cboBarSymbol", True)
    cboBarSymbol.Left = 166: cboBarSymbol.Top = rowY: cboBarSymbol.Width = 64: cboBarSymbol.Height = 19
    cboBarSymbol.Font.Name = "Segoe UI": cboBarSymbol.Font.Size = 8.5
    cboBarSymbol.Style = 2
    cboBarSymbol.AddItem "%%C"
    cboBarSymbol.AddItem "T"

    ' --- Right Panel: Preview ---
    Set rightPanel = AddFrame(mForm, "fraPreview", 274, 58, 480, 366, CLR_CARD_BG)
    Set lblPreviewHdr = AddSectionBanner(rightPanel, "lblPreviewHdr", "  Preview", 478)

    Set mpgPreview = rightPanel.Controls.Add("Forms.MultiPage.1", "mpgPreview", True)
    mpgPreview.Left = 6: mpgPreview.Top = 24: mpgPreview.Width = 466: mpgPreview.Height = 294
    mpgPreview.Font.Name = "Segoe UI": mpgPreview.Font.Size = 9

    Set imgSectionPreview = mpgPreview.Pages(0).Controls.Add("Forms.Image.1", "imgSectionPreview", True)
    imgSectionPreview.Left = 4: imgSectionPreview.Top = 4
    imgSectionPreview.Width = 450: imgSectionPreview.Height = 260
    imgSectionPreview.BorderStyle = 0
    imgSectionPreview.BackColor = CLR_CARD_BG
    imgSectionPreview.PictureSizeMode = 0

    Set imgPlanPreview = mpgPreview.Pages(1).Controls.Add("Forms.Image.1", "imgPlanPreview", True)
    imgPlanPreview.Left = 4: imgPlanPreview.Top = 4
    imgPlanPreview.Width = 450: imgPlanPreview.Height = 260
    imgPlanPreview.BorderStyle = 0
    imgPlanPreview.BackColor = CLR_CARD_BG
    imgPlanPreview.PictureSizeMode = 0

    Set lblSummary = AddLabel(rightPanel, "lblSummary", "", 6, 322, 466, 20, 8.5, True, CLR_NAVY)
    lblSummary.BackStyle = 1 ' fmBackStyleOpaque
    lblSummary.BackColor = CLR_SUMMARY_BG
    lblSummary.TextAlign = 2 ' fmTextAlignCenter

    Set lblStatus = AddLabel(rightPanel, "lblStatus", "Ready", 8, 345, 462, 16, 8, False, CLR_TEXT_MUTED)

    ' --- Bottom Panel: Options ---
    Set optPanel = AddFrame(mForm, "fraOptions", 10, 430, 744, 46, CLR_CARD_BG)
    Set lblOptionsHdr = AddSectionBanner(optPanel, "lblOptionsHdr", "  Options", 742)

    Set chkDimensions = AddCheck(optPanel, "chkDimensions", "Draw Dimensions", 14, 24, 155)
    Set chkRebar = AddCheck(optPanel, "chkRebar", "Draw Reinforcement", 190, 24, 165)
    Set chkCreateLayers = AddCheck(optPanel, "chkCreateLayers", "Create CSA Layers", 385, 24, 150)
    Set chkOpenExcel = AddCheck(optPanel, "chkOpenExcel", "Open Excel", 560, 24, 145)

    ' --- Bottom Action Buttons ---
    Set cmdLoadExcel = AddButton(mForm, "cmdLoadExcel", "Load Excel", 10, 484, 117, 28, CLR_SUMMARY_BG)
    Set cmdPreview = AddButton(mForm, "cmdPreview", "Preview", 135, 484, 118, 28, CLR_ACCENT_BTN)
    cmdPreview.Font.Bold = True
    Set cmdDrawSection = AddButton(mForm, "cmdDrawSection", "Draw Section", 261, 484, 118, 28, CLR_SUMMARY_BG)
    Set cmdDrawPlan = AddButton(mForm, "cmdDrawPlan", "Draw Plan", 387, 484, 118, 28, CLR_SUMMARY_BG)
    Set cmdClear = AddButton(mForm, "cmdClear", "Clear", 513, 484, 115, 28, CLR_SUMMARY_BG)
    Set cmdCancel = AddButton(mForm, "cmdCancel", "Cancel", 636, 484, 118, 28, CLR_SUMMARY_BG)
End Sub

Private Sub ApplyLanguage()
    Dim prevUpdating As Boolean, prevTypeIdx As Long
    prevUpdating = mUpdating
    mUpdating = True

    lblTitle.Caption = CSA_Tr("TITLE")
    lblSubTitle.Caption = CSA_Tr("SUBTITLE")
    lblParamsHdr.Caption = CSA_Tr("HDR_PARAMS")
    lblPreviewHdr.Caption = CSA_Tr("HDR_PREVIEW")
    lblOptionsHdr.Caption = CSA_Tr("HDR_OPTIONS")

    mpgParams.Pages(0).Caption = CSA_Tr("TAB_GENERAL")
    mpgParams.Pages(1).Caption = CSA_Tr("TAB_PLAN_CAD")
    mpgPreview.Pages(0).Caption = CSA_Tr("TAB_SECTION")
    mpgPreview.Pages(1).Caption = CSA_Tr("TAB_PLAN")

    lblStairName.Caption = CSA_Tr("STAIR_NAME")
    lblStairType.Caption = CSA_Tr("STAIR_TYPE")
    lblWidth.Caption = CSA_Tr("WIDTH")
    lblBottomElev.Caption = CSA_Tr("BOT_ELEV")
    lblTopElev.Caption = CSA_Tr("TOP_ELEV")
    lblRiser.Caption = CSA_Tr("RISER")
    lblTread.Caption = CSA_Tr("TREAD")
    lblSlab.Caption = CSA_Tr("SLAB")
    lblScale.Caption = CSA_Tr("SCALE")

    lblFlight1.Caption = CSA_Tr("FLIGHT1")
    lblLanding.Caption = CSA_Tr("MID_LAND")
    lblUpperLanding.Caption = CSA_Tr("UP_LAND")
    lblWellGap.Caption = CSA_Tr("WELL_GAP")
    lblSupportWidth.Caption = CSA_Tr("SUP_WIDTH")
    lblDirection.Caption = CSA_Tr("DIR")
    lblSectionMark.Caption = CSA_Tr("SEC_MARK")
    lblDimStyle.Caption = CSA_Tr("DIMSTYLE")
    lblCover.Caption = CSA_Tr("COVER")
    lblMainBar.Caption = CSA_Tr("MAIN_BAR")
    lblDistBar.Caption = CSA_Tr("DIST_BAR")
    lblAnchorSym.Caption = CSA_Tr("ANCHOR_D")

    chkDimensions.Caption = CSA_Tr("OPT_DIM")
    chkRebar.Caption = CSA_Tr("OPT_REBAR")
    chkCreateLayers.Caption = CSA_Tr("OPT_LAYERS")
    chkOpenExcel.Caption = CSA_Tr("OPT_EXCEL")

    cmdLoadExcel.Caption = CSA_Tr("BTN_EXCEL")
    cmdPreview.Caption = CSA_Tr("BTN_PREVIEW")
    cmdDrawSection.Caption = CSA_Tr("BTN_SECTION")
    cmdDrawPlan.Caption = CSA_Tr("BTN_PLAN")
    cmdClear.Caption = CSA_Tr("BTN_CLEAR")
    cmdCancel.Caption = CSA_Tr("BTN_CANCEL")

    prevTypeIdx = cboStairType.ListIndex
    If prevTypeIdx < 0 Then prevTypeIdx = StairTypeToIndex(gCSAStair.StairType)
    cboStairType.Clear
    cboStairType.AddItem CSA_Tr("TYPE_2F")
    cboStairType.AddItem CSA_Tr("TYPE_3F")
    cboStairType.AddItem CSA_Tr("TYPE_1F")
    cboStairType.ListIndex = prevTypeIdx

    mUpdating = prevUpdating
End Sub

Private Sub LoadCadDimStyles()
    Dim doc As Object, style As Object, preferred As String, i As Long
    cboDimStyle.Clear
    On Error GoTo Fallback
    Set doc = CSA_CadDocument()
    For Each style In doc.DimStyles
        cboDimStyle.AddItem CStr(style.Name)
    Next style
    If cboDimStyle.ListCount = 0 Then GoTo Fallback
    preferred = GetSetting(REG_APP, REG_SECTION, "DimStyle", "")
    If Len(preferred) = 0 Then preferred = CStr(doc.ActiveDimStyle.Name)
    For i = 0 To cboDimStyle.ListCount - 1
        If StrComp(CStr(cboDimStyle.List(i)), preferred, vbTextCompare) = 0 Then
            cboDimStyle.ListIndex = i
            Exit Sub
        End If
    Next i
    cboDimStyle.ListIndex = 0
    Exit Sub
Fallback:
    cboDimStyle.Clear
    cboDimStyle.AddItem "CSA 25"
    cboDimStyle.AddItem "GB 25"
    cboDimStyle.ListIndex = 0
End Sub

Private Sub LoadSavedPreferences(ByRef v As CSAStairInput)
    Dim savedScale As String, savedDim As String
    savedScale = GetSetting(REG_APP, REG_SECTION, "Scale", v.ScaleText)
    savedDim = GetSetting(REG_APP, REG_SECTION, "DimStyle", "")
    If Len(savedScale) > 0 Then v.ScaleText = savedScale
    If Len(savedDim) > 0 Then
        v.DimStyleName = savedDim
    ElseIf cboDimStyle.ListIndex >= 0 Then
        v.DimStyleName = CStr(cboDimStyle.Value)
    End If
End Sub

Public Sub OnFieldChanged(ByVal fieldKey As String)
    Dim v As CSAStairInput, msg As String
    If mUpdating Then Exit Sub
    ' Manual geometry edits switch back from raw Excel 24-pt mode to parametric mode.
    If fieldKey = "width" Or fieldKey = "elev" Or fieldKey = "riser" Or _
       fieldKey = "tread" Or fieldKey = "slab" Or fieldKey = "flight" Or fieldKey = "plan" Then
        gCSAStair.HasExcelCoords = False
    End If
    If fieldKey = "elev" Or fieldKey = "riser" Then
        If TryReadForm(v, msg, True) Then
            mUpdating = True
            txtFlight1.Value = CStr(v.Flight1Risers)
            txtFlight2.Value = CStr(v.Flight2Risers)
            txtFlight3.Value = CStr(v.Flight3Risers)
            mUpdating = False
        End If
    End If
    RefreshPreview
End Sub

Public Sub RefreshPreview()
    Dim v As CSAStairInput, msg As String, valid As Boolean
    Dim pxW As Long, pxH As Long
    If mForm Is Nothing Then Exit Sub
    valid = TryReadForm(v, msg, False)
    UpdateSummaryBar v, valid, msg

    pxW = CSA_FormPointsToPixels(imgSectionPreview.Width)
    pxH = CSA_FormPointsToPixels(imgSectionPreview.Height)
    On Error Resume Next
    Set imgSectionPreview.Picture = CSA_RenderSectionBitmap(v, pxW, pxH)
    Set imgPlanPreview.Picture = CSA_RenderPlanBitmap(v, pxW, pxH)
    On Error GoTo 0
End Sub

Private Sub UpdateSummaryBar(ByRef v As CSAStairInput, ByVal valid As Boolean, ByVal msg As String)
    Dim risersText As String
    Select Case v.StairType
        Case CSA_TYPE_SINGLE_FLIGHT
            risersText = CStr(v.Flight1Risers) & " " & CSA_Tr("PV_RISERS")
        Case CSA_TYPE_THREE_FLIGHT
            risersText = CStr(CSA_TotalRisers(v)) & " " & CSA_Tr("PV_RISERS") & " (" & CStr(v.Flight1Risers) & "+" & CStr(v.Flight2Risers) & "+" & CStr(v.Flight3Risers) & ")"
        Case Else
            risersText = CStr(CSA_TotalRisers(v)) & " " & CSA_Tr("PV_RISERS") & " (" & CStr(v.Flight1Risers) & "+" & CStr(v.Flight2Risers) & ")"
    End Select
    lblSummary.Caption = risersText & "  |  " & CSA_Tr("PV_RISE") & " " & FormatTrim(v.Riser) & _
                         "  |  " & CSA_Tr("PV_TREAD") & " " & FormatTrim(v.Tread) & _
                         "  |  " & CSA_Tr("PV_WIDTH") & " " & FormatTrim(v.Width)
    If valid Then
        lblStatus.ForeColor = CLR_TEXT_MUTED
        lblStatus.Caption = CSA_Tr("READY") & "  |  " & CSA_Tr("FLOOR_H") & ": " & _
                            FormatTrim(v.FloorHeight) & " mm  |  DimStyle: " & v.DimStyleName
    Else
        lblStatus.ForeColor = CLR_ERR_RED
        lblStatus.Caption = msg
    End If
End Sub

Private Function TryReadForm(ByRef v As CSAStairInput, ByRef message As String, _
                             ByVal autoDistribute As Boolean) As Boolean
    On Error GoTo ParseError
    v = gCSAStair
    v.StairName = Trim$(CStr(txtStairName.Value))
    v.StairType = IndexToStairType(cboStairType.ListIndex)
    v.Width = CDbl(txtWidth.Value)
    v.BottomElevation = CDbl(txtBottomElev.Value)
    v.TopElevation = CDbl(txtTopElev.Value)
    v.FloorHeight = (v.TopElevation - v.BottomElevation) * 1000#
    v.Riser = CDbl(txtRiser.Value)
    v.Tread = CDbl(txtTread.Value)
    v.Slab = CDbl(txtSlab.Value)
    v.ScaleText = CStr(cboScale.Value)
    v.Landing = CDbl(txtLanding.Value)
    v.UpperLanding = CDbl(txtUpperLanding.Value)
    v.WellGap = CDbl(txtWellGap.Value)
    v.SupportWidth = CDbl(txtSupportWidth.Value)
    v.StartDirection = CStr(cboDirection.Value)
    v.SectionMark = Trim$(CStr(txtSectionMark.Value))
    v.DimStyleName = CStr(cboDimStyle.Value)
    v.CoverMm = CDbl(txtCover.Value)
    v.FlightBotBar = Trim$(CStr(txtMainBar.Value))
    v.FlightTopBar = v.FlightBotBar
    v.LowerLandingBotBar = v.FlightBotBar
    v.LowerLandingTopBar = v.FlightBotBar
    v.DistBar = Trim$(CStr(txtDistBar.Value))
    v.AnchorFactor = CDbl(txtAnchorFactor.Value)
    v.BarSymbol = CStr(cboBarSymbol.Value)
    v.DrawDimensions = CBool(chkDimensions.Value)
    v.PreviewRebar = CBool(chkRebar.Value)
    v.CreateLayers = CBool(chkCreateLayers.Value)
    v.OpenExcel = CBool(chkOpenExcel.Value)

    If autoDistribute Then
        CSA_DistributeRisers v
    Else
        v.Flight1Risers = CLng(txtFlight1.Value)
        v.Flight2Risers = CLng(txtFlight2.Value)
        v.Flight3Risers = CLng(txtFlight3.Value)
    End If

    If v.CoverMm <= 0# Then message = "Cover must be positive.": Exit Function
    If v.AnchorFactor <= 0# Then message = "Anchor factor must be positive.": Exit Function
    TryReadForm = CSA_ValidateInput(v, message)
    Exit Function
ParseError:
    message = CSA_Tr("ERR_NUM")
    TryReadForm = False
End Function

Private Sub WriteForm(ByRef v As CSAStairInput)
    Dim prevUpdating As Boolean
    prevUpdating = mUpdating
    mUpdating = True
    txtStairName.Value = v.StairName
    cboStairType.ListIndex = StairTypeToIndex(v.StairType)
    txtWidth.Value = FormatTrim(v.Width)
    txtBottomElev.Value = Format$(v.BottomElevation, "0.000")
    txtTopElev.Value = Format$(v.TopElevation, "0.000")
    txtRiser.Value = FormatTrim(v.Riser)
    txtTread.Value = FormatTrim(v.Tread)
    txtSlab.Value = FormatTrim(v.Slab)
    SelectComboValue cboScale, v.ScaleText
    txtFlight1.Value = CStr(v.Flight1Risers)
    txtFlight2.Value = CStr(v.Flight2Risers)
    txtFlight3.Value = CStr(v.Flight3Risers)
    txtLanding.Value = FormatTrim(v.Landing)
    txtUpperLanding.Value = FormatTrim(v.UpperLanding)
    txtWellGap.Value = FormatTrim(v.WellGap)
    txtSupportWidth.Value = FormatTrim(v.SupportWidth)
    SelectComboValue cboDirection, v.StartDirection
    txtSectionMark.Value = v.SectionMark
    SelectComboValue cboDimStyle, v.DimStyleName
    txtCover.Value = FormatTrim(v.CoverMm)
    txtMainBar.Value = v.FlightBotBar
    txtDistBar.Value = v.DistBar
    txtAnchorFactor.Value = FormatTrim(v.AnchorFactor)
    SelectComboValue cboBarSymbol, v.BarSymbol
    chkDimensions.Value = v.DrawDimensions
    chkRebar.Value = v.PreviewRebar
    chkCreateLayers.Value = v.CreateLayers
    chkOpenExcel.Value = v.OpenExcel
    UpdateFlightEnableState
    mUpdating = prevUpdating
End Sub

Private Sub UpdateFlightEnableState()
    Dim st As String
    st = IndexToStairType(cboStairType.ListIndex)
    txtFlight2.Enabled = (st <> CSA_TYPE_SINGLE_FLIGHT)
    txtFlight3.Enabled = (st = CSA_TYPE_THREE_FLIGHT)
    txtWellGap.Enabled = (st <> CSA_TYPE_SINGLE_FLIGHT)
End Sub

Private Sub SavePreferences(ByRef v As CSAStairInput)
    On Error Resume Next
    SaveSetting REG_APP, REG_SECTION, "Scale", v.ScaleText
    SaveSetting REG_APP, REG_SECTION, "DimStyle", v.DimStyleName
    SaveSetting REG_APP, REG_SECTION, "Language", CSA_CurrentLang()
End Sub

Private Function PickInsertionPoint(ByVal promptText As String, ByRef outX As Double, ByRef outY As Double) As Boolean
    Dim doc As Object, pt As Variant
    On Error GoTo Cancelled
    Set doc = CSA_CadDocument()
    mForm.Hide
    pt = doc.Utility.GetPoint(, vbCrLf & promptText)
    outX = CDbl(pt(0))
    outY = CDbl(pt(1))
    PickInsertionPoint = True
    Exit Function
Cancelled:
    PickInsertionPoint = False
End Function

Private Function FormatTrim(ByVal num As Double) As String
    Dim s As String
    s = Format$(num, "0.##")
    If Right$(s, 1) = "." Then s = Left$(s, Len(s) - 1)
    FormatTrim = s
End Function

Private Function StairTypeToIndex(ByVal stairType As String) As Long
    Select Case stairType
        Case CSA_TYPE_THREE_FLIGHT: StairTypeToIndex = 1
        Case CSA_TYPE_SINGLE_FLIGHT: StairTypeToIndex = 2
        Case Else: StairTypeToIndex = 0
    End Select
End Function

Private Function IndexToStairType(ByVal idx As Long) As String
    Select Case idx
        Case 1: IndexToStairType = CSA_TYPE_THREE_FLIGHT
        Case 2: IndexToStairType = CSA_TYPE_SINGLE_FLIGHT
        Case Else: IndexToStairType = CSA_TYPE_TWO_FLIGHT
    End Select
End Function

' --- Event handlers ---

Private Sub cboLanguage_Change()
    If mUpdating Then Exit Sub
    If cboLanguage.ListIndex = 1 Then
        CSA_SetLanguage CSA_LANG_VI
    Else
        CSA_SetLanguage CSA_LANG_EN
    End If
    On Error Resume Next
    SaveSetting REG_APP, REG_SECTION, "Language", CSA_CurrentLang()
    On Error GoTo 0
    ApplyLanguage
    RefreshPreview
End Sub

Private Sub cboStairType_Change()
    Dim v As CSAStairInput, msg As String
    If mUpdating Then Exit Sub
    gCSAStair.HasExcelCoords = False
    UpdateFlightEnableState
    If TryReadForm(v, msg, True) Then
        mUpdating = True
        txtFlight1.Value = CStr(v.Flight1Risers)
        txtFlight2.Value = CStr(v.Flight2Risers)
        txtFlight3.Value = CStr(v.Flight3Risers)
        mUpdating = False
    End If
    RefreshPreview
End Sub

Private Sub cboScale_Change()
    If Not mUpdating Then RefreshPreview
End Sub

Private Sub cboDirection_Change()
    If Not mUpdating Then RefreshPreview
End Sub

Private Sub cboDimStyle_Change()
    If Not mUpdating Then RefreshPreview
End Sub

Private Sub cboBarSymbol_Change()
    If Not mUpdating Then RefreshPreview
End Sub

Private Sub chkDimensions_Click()
    If Not mUpdating Then RefreshPreview
End Sub

Private Sub chkRebar_Click()
    If Not mUpdating Then RefreshPreview
End Sub

Private Sub mpgPreview_Change()
    If Not mUpdating Then RefreshPreview
End Sub

Private Sub cmdLoadExcel_Click()
    Dim initDir As String, filePath As String, msg As String, folder As String, sepPos As Long
    initDir = GetSetting(REG_APP, REG_SECTION, "ExcelFolder", "")
    filePath = CSA_PickExcelFile(initDir, "Select CSA Stair Excel Workbook")
    If Len(Trim$(filePath)) = 0 Then Exit Sub

    gCSAStair.OpenExcel = CBool(chkOpenExcel.Value)
    If CSA_LoadInputFromExcel(filePath, gCSAStair, msg) Then
        gCSAStair.ExcelPath = filePath
        sepPos = InStrRev(filePath, "\")
        If sepPos > 0 Then
            folder = Left$(filePath, sepPos - 1)
            SaveSetting REG_APP, REG_SECTION, "ExcelFolder", folder
        End If
        WriteForm gCSAStair
        RefreshPreview
        lblStatus.ForeColor = CLR_NAVY
        lblStatus.Caption = CSA_Tr("MSG_EXCEL_OK") & Mid$(filePath, sepPos + 1)
    Else
        lblStatus.ForeColor = CLR_ERR_RED
        lblStatus.Caption = msg
        MsgBox msg, vbExclamation, "CSA Stair Drawing"
    End If
End Sub

Private Sub cmdPreview_Click()
    Dim v As CSAStairInput, msg As String, px As Double, py As Double
    On Error GoTo Failed
    If Not TryReadForm(v, msg, False) Then
        lblStatus.ForeColor = CLR_ERR_RED
        lblStatus.Caption = msg
        MsgBox msg, vbExclamation, "CSA Stair Drawing"
        Exit Sub
    End If
    If Not PickInsertionPoint(CSA_Tr("PICK_PREV"), px, py) Then
        lblStatus.ForeColor = CLR_TEXT_MUTED
        lblStatus.Caption = CSA_Tr("MSG_CANCEL_PICK")
        mForm.Show
        Exit Sub
    End If
    v.InsertX = px: v.InsertY = py
    gCSAStair = v
    SavePreferences gCSAStair
    CSA_RenderPreview gCSAStair
    lblStatus.ForeColor = CLR_NAVY
    lblStatus.Caption = CSA_Tr("MSG_PREVIEW_OK")
    mForm.Show
    RefreshPreview
    Exit Sub
Failed:
    On Error Resume Next
    mForm.Show
    lblStatus.ForeColor = CLR_ERR_RED
    lblStatus.Caption = Err.Description
    MsgBox Err.Description, vbExclamation, "CSA Stair Drawing"
End Sub

Private Sub cmdDrawSection_Click()
    Dim v As CSAStairInput, msg As String, px As Double, py As Double
    On Error GoTo Failed
    If Not TryReadForm(v, msg, False) Then
        MsgBox msg, vbExclamation, "CSA Stair Drawing"
        Exit Sub
    End If
    If Not PickInsertionPoint(CSA_Tr("PICK_SEC"), px, py) Then
        lblStatus.ForeColor = CLR_TEXT_MUTED
        lblStatus.Caption = CSA_Tr("MSG_CANCEL_PICK")
        mForm.Show
        Exit Sub
    End If
    v.InsertX = px: v.InsertY = py
    gCSAStair = v
    SavePreferences gCSAStair
    CSA_DrawSectionFinal gCSAStair
    lblStatus.ForeColor = CLR_NAVY
    lblStatus.Caption = CSA_Tr("MSG_SEC_OK") & CSA_LAYER_CONCRETE
    mForm.Show
    Exit Sub
Failed:
    On Error Resume Next
    mForm.Show
    lblStatus.ForeColor = CLR_ERR_RED
    lblStatus.Caption = Err.Description
    MsgBox Err.Description, vbExclamation, "CSA Stair Drawing"
End Sub

Private Sub cmdDrawPlan_Click()
    Dim v As CSAStairInput, msg As String, px As Double, py As Double
    On Error GoTo Failed
    If Not TryReadForm(v, msg, False) Then
        MsgBox msg, vbExclamation, "CSA Stair Drawing"
        Exit Sub
    End If
    If Not PickInsertionPoint(CSA_Tr("PICK_PLAN"), px, py) Then
        lblStatus.ForeColor = CLR_TEXT_MUTED
        lblStatus.Caption = CSA_Tr("MSG_CANCEL_PICK")
        mForm.Show
        Exit Sub
    End If
    v.InsertX = px: v.InsertY = py
    gCSAStair = v
    SavePreferences gCSAStair
    CSA_DrawPlanFinal gCSAStair
    lblStatus.ForeColor = CLR_NAVY
    lblStatus.Caption = CSA_Tr("MSG_PLAN_OK") & CSA_LAYER_PLAN
    mForm.Show
    Exit Sub
Failed:
    On Error Resume Next
    mForm.Show
    lblStatus.ForeColor = CLR_ERR_RED
    lblStatus.Caption = Err.Description
    MsgBox Err.Description, vbExclamation, "CSA Stair Drawing"
End Sub

Private Sub cmdClear_Click()
    On Error GoTo Failed
    CSA_ClearPreview
    lblStatus.ForeColor = CLR_TEXT_MUTED
    lblStatus.Caption = CSA_Tr("MSG_CLEAR_OK")
    Exit Sub
Failed:
    lblStatus.ForeColor = CLR_ERR_RED
    lblStatus.Caption = Err.Description
    MsgBox Err.Description, vbExclamation, "CSA Stair Drawing"
End Sub

Private Sub cmdCancel_Click()
    Unload mForm
End Sub

' --- Control factory helpers ---

Private Function AddFrame(ByVal container As Object, ByVal name As String, _
                          ByVal l As Double, ByVal t As Double, _
                          ByVal w As Double, ByVal h As Double, _
                          ByVal bgColor As Long) As MSForms.Frame
    Dim f As MSForms.Frame
    Set f = container.Controls.Add("Forms.Frame.1", name, True)
    f.Left = l: f.Top = t: f.Width = w: f.Height = h
    f.Caption = ""
    f.SpecialEffect = 0
    f.BorderStyle = 1
    f.BorderColor = &HD8C8B8
    f.BackColor = bgColor
    Set AddFrame = f
End Function

Private Function AddSectionBanner(ByVal container As Object, ByVal name As String, _
                                  ByVal caption As String, ByVal widthPt As Double) As MSForms.Label
    Dim lbl As MSForms.Label
    Set lbl = container.Controls.Add("Forms.Label.1", name, True)
    lbl.Left = 0: lbl.Top = 0: lbl.Width = widthPt: lbl.Height = 20
    lbl.Caption = caption
    lbl.BackStyle = 1
    lbl.BackColor = CLR_NAVY
    lbl.ForeColor = &HFFFFFF
    lbl.Font.Name = "Segoe UI"
    lbl.Font.Size = 9.5
    lbl.Font.Bold = True
    Set AddSectionBanner = lbl
End Function

Private Function AddLabel(ByVal container As Object, ByVal name As String, _
                          ByVal caption As String, ByVal l As Double, ByVal t As Double, _
                          ByVal w As Double, ByVal h As Double, ByVal fontSize As Double, _
                          ByVal bold As Boolean, ByVal foreColor As Long) As MSForms.Label
    Dim lbl As MSForms.Label
    Set lbl = container.Controls.Add("Forms.Label.1", name, True)
    lbl.Left = l: lbl.Top = t: lbl.Width = w: lbl.Height = h
    lbl.Caption = caption
    lbl.BackStyle = 0
    lbl.ForeColor = foreColor
    lbl.Font.Name = "Segoe UI"
    lbl.Font.Size = fontSize
    lbl.Font.Bold = bold
    Set AddLabel = lbl
End Function

Private Function AddSmallText(ByVal container As Object, ByVal name As String, _
                              ByVal l As Double, ByVal t As Double, ByVal w As Double, _
                              ByVal watchKey As String) As MSForms.TextBox
    Dim tb As MSForms.TextBox
    Set tb = container.Controls.Add("Forms.TextBox.1", name, True)
    tb.Left = l: tb.Top = t: tb.Width = w: tb.Height = 19
    tb.Font.Name = "Segoe UI": tb.Font.Size = 8.5
    tb.BorderStyle = 1: tb.BorderColor = &HC0B0A0
    WatchField tb, watchKey
    Set AddSmallText = tb
End Function

Private Function AddLabeledText(ByVal container As Object, ByVal caption As String, _
                                ByVal name As String, ByVal topPt As Double, _
                                ByVal inputLeft As Double, ByVal inputWidth As Double, _
                                ByVal unitText As String, ByVal watchKey As String, _
                                ByRef outLabel As MSForms.Label) As MSForms.TextBox
    Dim tb As MSForms.TextBox
    Set outLabel = AddLabel(container, "lbl_" & name, caption, 4, topPt + 2, inputLeft - 6, 16, 8.5, False, CLR_TEXT_DARK)
    Set tb = container.Controls.Add("Forms.TextBox.1", name, True)
    tb.Left = inputLeft: tb.Top = topPt: tb.Width = inputWidth: tb.Height = 19
    tb.Font.Name = "Segoe UI": tb.Font.Size = 8.5
    tb.BorderStyle = 1: tb.BorderColor = &HC0B0A0
    If Len(unitText) > 0 Then
        AddLabel container, "unit_" & name, unitText, inputLeft + inputWidth + 4, topPt + 2, 16, 16, 8.5, False, CLR_TEXT_MUTED
    End If
    WatchField tb, watchKey
    Set AddLabeledText = tb
End Function

Private Function AddLabeledCombo(ByVal container As Object, ByVal caption As String, _
                                 ByVal name As String, ByVal topPt As Double, _
                                 ByVal inputLeft As Double, ByVal inputWidth As Double, _
                                 ByRef outLabel As MSForms.Label) As MSForms.ComboBox
    Dim cb As MSForms.ComboBox
    Set outLabel = AddLabel(container, "lbl_" & name, caption, 4, topPt + 2, inputLeft - 6, 16, 8.5, False, CLR_TEXT_DARK)
    Set cb = container.Controls.Add("Forms.ComboBox.1", name, True)
    cb.Left = inputLeft: cb.Top = topPt: cb.Width = inputWidth: cb.Height = 19
    cb.Font.Name = "Segoe UI": cb.Font.Size = 8.5
    cb.Style = 2 ' fmStyleDropDownList
    Set AddLabeledCombo = cb
End Function

Private Function AddCheck(ByVal container As Object, ByVal name As String, _
                          ByVal caption As String, ByVal l As Double, ByVal t As Double, _
                          ByVal w As Double) As MSForms.CheckBox
    Dim chk As MSForms.CheckBox
    Set chk = container.Controls.Add("Forms.CheckBox.1", name, True)
    chk.Left = l: chk.Top = t: chk.Width = w: chk.Height = 18
    chk.Caption = caption
    chk.BackColor = CLR_CARD_BG
    chk.ForeColor = CLR_TEXT_DARK
    chk.Font.Name = "Segoe UI": chk.Font.Size = 8.5
    Set AddCheck = chk
End Function

Private Function AddButton(ByVal container As Object, ByVal name As String, _
                           ByVal caption As String, ByVal l As Double, ByVal t As Double, _
                           ByVal w As Double, ByVal h As Double, _
                           ByVal bgColor As Long) As MSForms.CommandButton
    Dim btn As MSForms.CommandButton
    Set btn = container.Controls.Add("Forms.CommandButton.1", name, True)
    btn.Left = l: btn.Top = t: btn.Width = w: btn.Height = h
    btn.Caption = caption
    btn.BackColor = bgColor
    btn.ForeColor = CLR_TEXT_DARK
    btn.Font.Name = "Segoe UI": btn.Font.Size = 9
    Set AddButton = btn
End Function

Private Sub WatchField(ByVal tb As MSForms.TextBox, ByVal key As String)
    Dim w As clsCSAStairFieldWatcher
    Set w = New clsCSAStairFieldWatcher
    w.Bind tb, Me, key
    mWatchers.Add w
End Sub

Private Sub SelectComboValue(ByVal cb As MSForms.ComboBox, ByVal target As String)
    Dim i As Long
    For i = 0 To cb.ListCount - 1
        If StrComp(CStr(cb.List(i)), target, vbTextCompare) = 0 Then
            cb.ListIndex = i
            Exit Sub
        End If
    Next i
    If cb.ListCount > 0 Then cb.ListIndex = 0
End Sub
