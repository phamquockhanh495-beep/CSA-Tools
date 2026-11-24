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
' docs/CSA-Stair-Drawing-UI-Mockup.png plus manual Plan View inputs.

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

' Parameter controls - Plan & CAD tab (manual plan inputs)
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
Private txtX As MSForms.TextBox
Private txtY As MSForms.TextBox
Private WithEvents cmdPickPoint As MSForms.CommandButton

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
    BuildLayout
    LoadCadDimStyles
    LoadSavedPreferences gCSAStair
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
    Dim lbl As MSForms.Label
    Dim pageGen As Object, pagePlan As Object
    Dim rowY As Double, rowStep As Double

    mForm.Caption = "Stair Drawing  |  CSA Tools"
    mForm.Width = 764
    mForm.Height = 548
    mForm.BackColor = CLR_FORM_BG
    mForm.Font.Name = "Segoe UI"
    mForm.Font.Size = 9

    ' --- Header Bar ---
    Set hdr = AddFrame(mForm, "fraHeader", 0, 0, 760, 52, CLR_CARD_BG)
    Set imgLogo = hdr.Controls.Add("Forms.Image.1", "imgLogo", True)
    imgLogo.Left = 12: imgLogo.Top = 8: imgLogo.Width = 36: imgLogo.Height = 36
    imgLogo.BorderStyle = 0
    imgLogo.BackColor = CLR_CARD_BG
    imgLogo.PictureSizeMode = 0
    On Error Resume Next
    Set imgLogo.Picture = CSA_RenderStairIconBitmap(CSA_FormPointsToPixels(36#), CSA_FormPointsToPixels(36#))
    On Error GoTo 0

    Set lbl = AddLabel(hdr, "lblTitle", "Stair Drawing", 56, 6, 260, 24, 15, True, CLR_NAVY)
    Set lbl = AddLabel(hdr, "lblSubTitle", "CSA TOOLS  |  STAIR DRAWING", 56, 30, 260, 14, 8, False, CLR_TEXT_MUTED)
    Set lbl = AddLabel(hdr, "lblAuthor", "Author: CoAnTran", 560, 28, 180, 16, 9, True, CLR_NAVY)
    lbl.Font.Italic = True
    lbl.TextAlign = 3 ' fmTextAlignRight

    ' --- Left Panel: Stair Parameters ---
    Set leftPanel = AddFrame(mForm, "fraParameters", 10, 58, 252, 366, CLR_CARD_BG)
    AddSectionBanner leftPanel, "lblParamsHdr", "  Stair Parameters", 250

    Set mpgParams = leftPanel.Controls.Add("Forms.MultiPage.1", "mpgParams", True)
    mpgParams.Left = 4: mpgParams.Top = 24: mpgParams.Width = 242: mpgParams.Height = 336
    mpgParams.Font.Name = "Segoe UI": mpgParams.Font.Size = 8.5
    mpgParams.Pages(0).Caption = "General"
    mpgParams.Pages(1).Caption = "Plan & CAD"

    ' Page 0: General parameters (matching mockup 1:1)
    Set pageGen = mpgParams.Pages(0)
    rowY = 10: rowStep = 31
    Set txtStairName = AddLabeledText(pageGen, "Stair Name:", "txtStairName", rowY, 108, 118, "", "name")
    rowY = rowY + rowStep
    Set cboStairType = AddLabeledCombo(pageGen, "Stair Type:", "cboStairType", rowY, 108, 118)
    cboStairType.AddItem CSA_TYPE_TWO_FLIGHT
    cboStairType.AddItem CSA_TYPE_THREE_FLIGHT
    cboStairType.AddItem CSA_TYPE_SINGLE_FLIGHT
    rowY = rowY + rowStep
    Set txtWidth = AddLabeledText(pageGen, "Width (mm):", "txtWidth", rowY, 108, 118, "", "width")
    rowY = rowY + rowStep
    Set txtBottomElev = AddLabeledText(pageGen, "Bottom Elev.:", "txtBottomElev", rowY, 108, 96, "m", "elev")
    rowY = rowY + rowStep
    Set txtTopElev = AddLabeledText(pageGen, "Top Elev.:", "txtTopElev", rowY, 108, 96, "m", "elev")
    rowY = rowY + rowStep
    Set txtRiser = AddLabeledText(pageGen, "Riser (mm):", "txtRiser", rowY, 108, 118, "", "riser")
    rowY = rowY + rowStep
    Set txtTread = AddLabeledText(pageGen, "Tread (mm):", "txtTread", rowY, 108, 118, "", "tread")
    rowY = rowY + rowStep
    Set txtSlab = AddLabeledText(pageGen, "Slab Thick. (mm):", "txtSlab", rowY, 108, 118, "", "slab")
    rowY = rowY + rowStep
    Set cboScale = AddLabeledCombo(pageGen, "Scale:", "cboScale", rowY, 108, 118)
    cboScale.AddItem "1:25"
    cboScale.AddItem "1:50"
    cboScale.AddItem "1:75"
    cboScale.AddItem "1:100"

    ' Page 1: Manual Plan View & CAD settings
    Set pagePlan = mpgParams.Pages(1)
    rowY = 8: rowStep = 25
    Set txtFlight1 = AddLabeledText(pagePlan, "Flight 1 Risers:", "txtFlight1", rowY, 112, 114, "", "flight")
    rowY = rowY + rowStep
    Set txtFlight2 = AddLabeledText(pagePlan, "Flight 2 Risers:", "txtFlight2", rowY, 112, 114, "", "flight")
    rowY = rowY + rowStep
    Set txtFlight3 = AddLabeledText(pagePlan, "Flight 3 Risers:", "txtFlight3", rowY, 112, 114, "", "flight")
    rowY = rowY + rowStep
    Set txtLanding = AddLabeledText(pagePlan, "Mid Landing (mm):", "txtLanding", rowY, 112, 114, "", "plan")
    rowY = rowY + rowStep
    Set txtUpperLanding = AddLabeledText(pagePlan, "Upper Landing:", "txtUpperLanding", rowY, 112, 114, "", "plan")
    rowY = rowY + rowStep
    Set txtWellGap = AddLabeledText(pagePlan, "Well Gap (mm):", "txtWellGap", rowY, 112, 114, "", "plan")
    rowY = rowY + rowStep
    Set txtSupportWidth = AddLabeledText(pagePlan, "Support Width:", "txtSupportWidth", rowY, 112, 114, "", "plan")
    rowY = rowY + rowStep
    Set cboDirection = AddLabeledCombo(pagePlan, "Start Direction:", "cboDirection", rowY, 112, 114)
    cboDirection.AddItem "UP"
    cboDirection.AddItem "DN"
    rowY = rowY + rowStep
    Set txtSectionMark = AddLabeledText(pagePlan, "Section Mark:", "txtSectionMark", rowY, 112, 114, "", "mark")
    rowY = rowY + rowStep
    Set cboDimStyle = AddLabeledCombo(pagePlan, "DimStyle:", "cboDimStyle", rowY, 112, 114)
    rowY = rowY + rowStep
    Set txtX = AddLabeledText(pagePlan, "Insert X / Y:", "txtX", rowY, 78, 52, "", "pos")
    Set txtY = pagePlan.Controls.Add("Forms.TextBox.1", "txtY", True)
    txtY.Left = 134: txtY.Top = rowY: txtY.Width = 52: txtY.Height = 19
    txtY.Font.Name = "Segoe UI": txtY.Font.Size = 8.5
    WatchField txtY, "pos"
    Set cmdPickPoint = AddButton(pagePlan, "cmdPickPoint", "Pick", 190, rowY, 38, 19, CLR_ACCENT_BTN)

    ' --- Right Panel: Preview ---
    Set rightPanel = AddFrame(mForm, "fraPreview", 270, 58, 480, 366, CLR_CARD_BG)
    AddSectionBanner rightPanel, "lblPreviewHdr", "  Preview", 478

    Set mpgPreview = rightPanel.Controls.Add("Forms.MultiPage.1", "mpgPreview", True)
    mpgPreview.Left = 6: mpgPreview.Top = 24: mpgPreview.Width = 466: mpgPreview.Height = 294
    mpgPreview.Font.Name = "Segoe UI": mpgPreview.Font.Size = 9
    mpgPreview.Pages(0).Caption = "Section View"
    mpgPreview.Pages(1).Caption = "Plan View"

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

    Set lblStatus = AddLabel(rightPanel, "lblStatus", "Ready - AutoCAD 2018-2027 x64 VBA", 8, 345, 462, 16, 8, False, CLR_TEXT_MUTED)

    ' --- Bottom Panel: Options ---
    Set optPanel = AddFrame(mForm, "fraOptions", 10, 430, 740, 46, CLR_CARD_BG)
    AddSectionBanner optPanel, "lblOptionsHdr", "  Options", 738

    Set chkDimensions = AddCheck(optPanel, "chkDimensions", "Draw Dimensions", 14, 24, 150)
    Set chkRebar = AddCheck(optPanel, "chkRebar", "Draw Reinforcement", 190, 24, 160)
    Set chkCreateLayers = AddCheck(optPanel, "chkCreateLayers", "Create Layers", 385, 24, 140)
    Set chkOpenExcel = AddCheck(optPanel, "chkOpenExcel", "Open Excel", 560, 24, 140)

    ' --- Bottom Action Buttons ---
    Set cmdLoadExcel = AddButton(mForm, "cmdLoadExcel", "Load Excel", 10, 484, 116, 28, CLR_SUMMARY_BG)
    Set cmdPreview = AddButton(mForm, "cmdPreview", "Preview", 134, 484, 118, 28, CLR_ACCENT_BTN)
    cmdPreview.Font.Bold = True
    Set cmdDrawSection = AddButton(mForm, "cmdDrawSection", "Draw Section", 260, 484, 118, 28, CLR_SUMMARY_BG)
    Set cmdDrawPlan = AddButton(mForm, "cmdDrawPlan", "Draw Plan", 386, 484, 118, 28, CLR_SUMMARY_BG)
    Set cmdClear = AddButton(mForm, "cmdClear", "Clear", 512, 484, 114, 28, CLR_SUMMARY_BG)
    Set cmdCancel = AddButton(mForm, "cmdCancel", "Cancel", 634, 484, 116, 28, CLR_SUMMARY_BG)
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
    preferred = GetSetting(REG_APP, REG_SECTION, "DimStyle", "GB 25")
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
    cboDimStyle.AddItem "GB 25"
    cboDimStyle.AddItem "GB 50"
    cboDimStyle.ListIndex = 0
End Sub

Private Sub LoadSavedPreferences(ByRef v As CSAStairInput)
    Dim savedScale As String, savedDim As String
    savedScale = GetSetting(REG_APP, REG_SECTION, "Scale", v.ScaleText)
    savedDim = GetSetting(REG_APP, REG_SECTION, "DimStyle", v.DimStyleName)
    If Len(savedScale) > 0 Then v.ScaleText = savedScale
    If Len(savedDim) > 0 Then v.DimStyleName = savedDim
End Sub

Public Sub OnFieldChanged(ByVal fieldKey As String)
    Dim v As CSAStairInput, msg As String
    If mUpdating Then Exit Sub
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
            risersText = CStr(v.Flight1Risers) & " RISERS"
        Case CSA_TYPE_THREE_FLIGHT
            risersText = CStr(CSA_TotalRisers(v)) & " RISERS (" & CStr(v.Flight1Risers) & "+" & CStr(v.Flight2Risers) & "+" & CStr(v.Flight3Risers) & ")"
        Case Else
            risersText = CStr(CSA_TotalRisers(v)) & " RISERS (" & CStr(v.Flight1Risers) & "+" & CStr(v.Flight2Risers) & ")"
    End Select
    lblSummary.Caption = risersText & "  |  RISE " & Format$(v.Riser, "0") & _
                         "  |  TREAD " & Format$(v.Tread, "0") & "  |  WIDTH " & Format$(v.Width, "0")
    If valid Then
        lblStatus.ForeColor = CLR_TEXT_MUTED
        lblStatus.Caption = "Ready  |  Floor height: " & Format$(v.FloorHeight, "0") & " mm  |  DimStyle: " & v.DimStyleName
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
    v.StairType = CStr(cboStairType.Value)
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
    v.InsertX = CDbl(txtX.Value)
    v.InsertY = CDbl(txtY.Value)
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

    TryReadForm = CSA_ValidateInput(v, message)
    Exit Function
ParseError:
    message = "Enter valid numeric stair parameters."
    TryReadForm = False
End Function

Private Sub WriteForm(ByRef v As CSAStairInput)
    Dim prevUpdating As Boolean
    prevUpdating = mUpdating
    mUpdating = True
    txtStairName.Value = v.StairName
    SelectComboValue cboStairType, v.StairType
    txtWidth.Value = Format$(v.Width, "0.##")
    txtBottomElev.Value = Format$(v.BottomElevation, "0.000")
    txtTopElev.Value = Format$(v.TopElevation, "0.000")
    txtRiser.Value = Format$(v.Riser, "0.##")
    txtTread.Value = Format$(v.Tread, "0.##")
    txtSlab.Value = Format$(v.Slab, "0.##")
    SelectComboValue cboScale, v.ScaleText
    txtFlight1.Value = CStr(v.Flight1Risers)
    txtFlight2.Value = CStr(v.Flight2Risers)
    txtFlight3.Value = CStr(v.Flight3Risers)
    txtLanding.Value = Format$(v.Landing, "0.##")
    txtUpperLanding.Value = Format$(v.UpperLanding, "0.##")
    txtWellGap.Value = Format$(v.WellGap, "0.##")
    txtSupportWidth.Value = Format$(v.SupportWidth, "0.##")
    SelectComboValue cboDirection, v.StartDirection
    txtSectionMark.Value = v.SectionMark
    SelectComboValue cboDimStyle, v.DimStyleName
    txtX.Value = Format$(v.InsertX, "0.##")
    txtY.Value = Format$(v.InsertY, "0.##")
    chkDimensions.Value = v.DrawDimensions
    chkRebar.Value = v.PreviewRebar
    chkCreateLayers.Value = v.CreateLayers
    chkOpenExcel.Value = v.OpenExcel
    UpdateFlightEnableState
    mUpdating = prevUpdating
End Sub

Private Sub UpdateFlightEnableState()
    Dim isSingle As Boolean, isThree As Boolean
    isSingle = (CStr(cboStairType.Value) = CSA_TYPE_SINGLE_FLIGHT)
    isThree = (CStr(cboStairType.Value) = CSA_TYPE_THREE_FLIGHT)
    txtFlight2.Enabled = Not isSingle
    txtFlight3.Enabled = isThree
    txtWellGap.Enabled = Not isSingle
End Sub

Private Sub SavePreferences(ByRef v As CSAStairInput)
    On Error Resume Next
    SaveSetting REG_APP, REG_SECTION, "Scale", v.ScaleText
    SaveSetting REG_APP, REG_SECTION, "DimStyle", v.DimStyleName
End Sub

' --- Event handlers ---

Private Sub cboStairType_Change()
    Dim v As CSAStairInput, msg As String
    If mUpdating Then Exit Sub
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

Private Sub chkDimensions_Click()
    If Not mUpdating Then RefreshPreview
End Sub

Private Sub chkRebar_Click()
    If Not mUpdating Then RefreshPreview
End Sub

Private Sub mpgPreview_Change()
    If Not mUpdating Then RefreshPreview
End Sub

Private Sub cmdPickPoint_Click()
    Dim doc As Object, pt As Variant
    On Error GoTo Cancelled
    Set doc = CSA_CadDocument()
    mForm.Hide
    pt = doc.Utility.GetPoint(, vbCrLf & "Pick stair insertion point: ")
    mUpdating = True
    txtX.Value = Format$(CDbl(pt(0)), "0.##")
    txtY.Value = Format$(CDbl(pt(1)), "0.##")
    mUpdating = False
    mForm.Show
    RefreshPreview
    Exit Sub
Cancelled:
    On Error Resume Next
    mForm.Show
End Sub

Private Sub cmdLoadExcel_Click()
    Dim initDir As String, filePath As String, msg As String, folder As String, sepPos As Long
    initDir = GetSetting(REG_APP, REG_SECTION, "ExcelFolder", "")
    filePath = CSA_PickExcelFile(initDir, "Select CSA Stair Excel Workbook")
    If Len(Trim$(filePath)) = 0 Then Exit Sub

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
        lblStatus.Caption = "Loaded Excel: " & Mid$(filePath, sepPos + 1)
    Else
        lblStatus.ForeColor = CLR_ERR_RED
        lblStatus.Caption = msg
        MsgBox msg, vbExclamation, "CSA Stair Drawing"
    End If
End Sub

Private Sub cmdPreview_Click()
    Dim v As CSAStairInput, msg As String
    If Not TryReadForm(v, msg, False) Then
        lblStatus.ForeColor = CLR_ERR_RED
        lblStatus.Caption = msg
        MsgBox msg, vbExclamation, "CSA Stair Drawing"
        Exit Sub
    End If
    gCSAStair = v
    SavePreferences gCSAStair
    RefreshPreview
    CSA_RenderPreview gCSAStair
    lblStatus.ForeColor = CLR_NAVY
    lblStatus.Caption = "Preview updated in form and on CSA-PREVIEW"
End Sub

Private Sub cmdDrawSection_Click()
    Dim v As CSAStairInput, msg As String
    If Not TryReadForm(v, msg, False) Then
        MsgBox msg, vbExclamation, "CSA Stair Drawing"
        Exit Sub
    End If
    gCSAStair = v
    SavePreferences gCSAStair
    CSA_DrawSectionFinal gCSAStair
    lblStatus.ForeColor = CLR_NAVY
    lblStatus.Caption = "Section drawn on " & CSA_LAYER_CONCRETE
End Sub

Private Sub cmdDrawPlan_Click()
    Dim v As CSAStairInput, msg As String
    If Not TryReadForm(v, msg, False) Then
        MsgBox msg, vbExclamation, "CSA Stair Drawing"
        Exit Sub
    End If
    gCSAStair = v
    SavePreferences gCSAStair
    CSA_DrawPlanFinal gCSAStair
    lblStatus.ForeColor = CLR_NAVY
    lblStatus.Caption = "Plan drawn on " & CSA_LAYER_PLAN
End Sub

Private Sub cmdClear_Click()
    CSA_ClearPreview
    lblStatus.ForeColor = CLR_TEXT_MUTED
    lblStatus.Caption = "CSA-PREVIEW cleared"
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

Private Sub AddSectionBanner(ByVal container As Object, ByVal name As String, _
                             ByVal caption As String, ByVal widthPt As Double)
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
End Sub

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

Private Function AddLabeledText(ByVal container As Object, ByVal caption As String, _
                                ByVal name As String, ByVal topPt As Double, _
                                ByVal inputLeft As Double, ByVal inputWidth As Double, _
                                ByVal unitText As String, ByVal watchKey As String) As MSForms.TextBox
    Dim tb As MSForms.TextBox
    AddLabel container, "lbl_" & name, caption, 6, topPt + 2, inputLeft - 8, 16, 8.5, False, CLR_TEXT_DARK
    Set tb = container.Controls.Add("Forms.TextBox.1", name, True)
    tb.Left = inputLeft: tb.Top = topPt: tb.Width = inputWidth: tb.Height = 19
    tb.Font.Name = "Segoe UI": tb.Font.Size = 8.5
    tb.BorderStyle = 1: tb.BorderColor = &HC0B0A0
    If Len(unitText) > 0 Then
        AddLabel container, "unit_" & name, unitText, inputLeft + inputWidth + 4, topPt + 2, 18, 16, 8.5, False, CLR_TEXT_MUTED
    End If
    WatchField tb, watchKey
    Set AddLabeledText = tb
End Function

Private Function AddLabeledCombo(ByVal container As Object, ByVal caption As String, _
                                 ByVal name As String, ByVal topPt As Double, _
                                 ByVal inputLeft As Double, ByVal inputWidth As Double) As MSForms.ComboBox
    Dim cb As MSForms.ComboBox
    AddLabel container, "lbl_" & name, caption, 6, topPt + 2, inputLeft - 8, 16, 8.5, False, CLR_TEXT_DARK
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
