Attribute VB_Name = "frmCSAStair"
Option Explicit

Private Sub UserForm_Initialize()
    Dim v As CSAStairInput
    v = CSA_DefaultInput()
    Me.Caption = "Stair Drawing"
    Me.txtStairName.Value = v.StairName
    Me.cboStairType.Clear
    Me.cboStairType.AddItem "2 FLIGHTS - U"
    Me.cboStairType.ListIndex = 0
    Me.txtFloorHeight.Value = CStr(v.FloorHeight)
    Me.txtWidth.Value = CStr(v.Width)
    Me.txtRiser.Value = CStr(v.Riser)
    Me.txtTread.Value = CStr(v.Tread)
    Me.txtLanding.Value = CStr(v.Landing)
    Me.txtSlab.Value = CStr(v.Slab)
    Me.txtX.Value = CStr(v.InsertX)
    Me.txtY.Value = CStr(v.InsertY)
    Me.chkDimensions.Value = v.DrawDimensions
    Me.chkRebar.Value = v.PreviewRebar
    Me.lblStatus.Caption = "Ready - preview is drawn on CSA-PREVIEW"
    On Error Resume Next
    ApplyCSAThemeEx Me, "Stair Drawing", "CSA TOOLS  |  STAIR DRAWING"
    On Error GoTo 0
End Sub

Private Sub cmdPreview_Click()
    If ReadForm(gCSAStair) Then
        CSA_RenderPreview gCSAStair
        Me.lblStatus.Caption = "Preview updated on CSA-PREVIEW"
    End If
End Sub

Private Sub cmdDrawSection_Click()
    If ReadForm(gCSAStair) Then
        CSA_DrawSectionFinal gCSAStair
        Me.lblStatus.Caption = "Section drawn on CSA-CONCRETE"
    End If
End Sub

Private Sub cmdDrawPlan_Click()
    If ReadForm(gCSAStair) Then
        CSA_DrawPlanFinal gCSAStair
        Me.lblStatus.Caption = "Plan drawn on CSA-CONCRETE"
    End If
End Sub

Private Sub cmdClear_Click()
    CSA_ClearPreview
    Me.lblStatus.Caption = "CSA-PREVIEW cleared"
End Sub

Private Sub cmdCancel_Click()
    Unload Me
End Sub

Private Sub cmdLoadExcel_Click()
    Dim path As String, message As String
    path = InputBox("Enter the full path to the Excel workbook:", "Load Excel")
    If Len(Trim$(path)) = 0 Then Exit Sub
    If CSA_LoadInputFromExcel(path, gCSAStair, message) Then
        WriteForm gCSAStair
        Me.lblStatus.Caption = "Excel parameters loaded"
    Else
        MsgBox message, vbExclamation, "CSA Stair Drawing"
    End If
End Sub

Private Function ReadForm(ByRef v As CSAStairInput) As Boolean
    Dim message As String
    On Error GoTo Invalid
    v.StairName = CStr(Me.txtStairName.Value)
    v.StairType = CStr(Me.cboStairType.Value)
    v.FloorHeight = CDbl(Me.txtFloorHeight.Value)
    v.Width = CDbl(Me.txtWidth.Value)
    v.Riser = CDbl(Me.txtRiser.Value)
    v.Tread = CDbl(Me.txtTread.Value)
    v.Landing = CDbl(Me.txtLanding.Value)
    v.Slab = CDbl(Me.txtSlab.Value)
    v.InsertX = CDbl(Me.txtX.Value)
    v.InsertY = CDbl(Me.txtY.Value)
    v.Flight1Risers = CLng(v.FloorHeight / v.Riser / 2#)
    v.Flight2Risers = CLng(v.FloorHeight / v.Riser) - v.Flight1Risers
    v.DrawDimensions = CBool(Me.chkDimensions.Value)
    v.PreviewRebar = CBool(Me.chkRebar.Value)
    ReadForm = CSA_ValidateInput(v, message)
    Exit Function
Invalid:
    MsgBox "Check stair inputs: " & Err.Description, vbExclamation, "CSA Stair Drawing"
End Function

Private Sub WriteForm(ByRef v As CSAStairInput)
    Me.txtStairName.Value = v.StairName
    Me.cboStairType.Value = v.StairType
    Me.txtFloorHeight.Value = CStr(v.FloorHeight)
    Me.txtWidth.Value = CStr(v.Width)
    Me.txtRiser.Value = CStr(v.Riser)
    Me.txtTread.Value = CStr(v.Tread)
    Me.txtLanding.Value = CStr(v.Landing)
    Me.txtSlab.Value = CStr(v.Slab)
    Me.txtX.Value = CStr(v.InsertX)
    Me.txtY.Value = CStr(v.InsertY)
End Sub
