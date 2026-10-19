Attribute VB_Name = "CSA_StairCase_Compat"
Option Explicit

' Single-module compatibility build for AutoCAD VBA.
' It intentionally avoids custom UDT declarations because some AutoCAD
' VBA hosts report "User-defined type not defined" when those declarations
' are imported into an existing CSA project.

Private Const LAYER_PREVIEW As String = "CSA-PREVIEW"
Private Const LAYER_CONCRETE As String = "CSA-CONCRETE"

Public Sub CSA_PreviewCurrentWorkbook()
    Dim filePath As String, message As String
    Dim xs() As Double, ys() As Double, count As Long
    filePath = InputBox("Enter the Excel file path or its folder:" & vbCrLf & "Example: C:\CSA Tools\CSA_Worksheet\CSA_Stair Drawing Tools.xlsm", "CSA Stair Drawing")
    If Len(Trim$(filePath)) = 0 Then Exit Sub
    filePath = ResolveWorkbookPath(filePath)
    If Not ReadLegacyCoordinates(filePath, xs, ys, count, message) Then
        MsgBox message, vbExclamation, "CSA Stair Drawing"
        Exit Sub
    End If
    EnsureLayer LAYER_PREVIEW, 4
    ClearLayer LAYER_PREVIEW
    DrawPolyline xs, ys, count, LAYER_PREVIEW
    ThisDrawing.Regen 0
    ThisDrawing.Application.ZoomExtents
    MsgBox CStr(count) & " points previewed on " & LAYER_PREVIEW & ".", vbInformation, "CSA Stair Drawing"
End Sub

Public Sub CSA_CleanPreviewCommand()
    ClearLayer LAYER_PREVIEW
    ThisDrawing.Regen 0
End Sub

Public Sub CSA_DrawTwoFlightPreview()
    Dim floorHeight As Double, riser As Double, tread As Double
    Dim width As Double, landing As Double, insertX As Double, insertY As Double
    Dim count1 As Long, count2 As Long
    floorHeight = ReadNumber("Floor height (mm):", 3600#)
    riser = ReadNumber("Riser (mm):", 150#)
    tread = ReadNumber("Tread (mm):", 300#)
    width = ReadNumber("Flight width (mm):", 1200#)
    landing = ReadNumber("Landing length (mm):", 1500#)
    insertX = ReadNumber("Insert X:", 0#)
    insertY = ReadNumber("Insert Y:", 0#)
    If floorHeight <= 0# Or riser <= 0# Or tread <= 0# Or width <= 0# Or landing <= 0# Then
        MsgBox "All dimensions must be positive.", vbExclamation, "CSA Stair Drawing"
        Exit Sub
    End If
    count1 = CLng(Int(floorHeight / riser / 2# + 0.5))
    count2 = CLng(Int(floorHeight / riser + 0.5)) - count1
    If count1 < 1 Or count2 < 1 Then
        MsgBox "The calculated riser count is invalid.", vbExclamation, "CSA Stair Drawing"
        Exit Sub
    End If
    If Abs((count1 + count2) * riser - floorHeight) > 0.5 Then
        MsgBox "Floor height is not an exact multiple of the riser.", vbExclamation, "CSA Stair Drawing"
        Exit Sub
    End If
    EnsureLayer LAYER_PREVIEW, 4
    ClearLayer LAYER_PREVIEW
    DrawSection insertX, insertY, count1, count2, riser, tread, landing, LAYER_PREVIEW
    DrawPlan insertX, insertY + (floorHeight + landing) * 1.25, count1, count2, tread, width, landing, LAYER_PREVIEW
    ThisDrawing.Regen 0
    ThisDrawing.Application.ZoomExtents
End Sub

Public Sub CSA_STAIRDRAW()
    CSA_DrawTwoFlightPreview
End Sub

Private Function ReadLegacyCoordinates(ByVal filePath As String, ByRef xs() As Double, ByRef ys() As Double, ByRef count As Long, ByRef message As String) As Boolean
    Dim xl As Object, wb As Object, ws As Object
    Dim r As Long, xv As Variant, yv As Variant
    On Error GoTo Fail
    Set xl = CreateObject("Excel.Application")
    Set wb = xl.Workbooks.Open(filePath, False, True)
    Set ws = wb.Worksheets("Cau Thang Tools")
    count = 0
    ReDim xs(0 To 0)
    ReDim ys(0 To 0)
    For r = 2 To 500
        xv = ws.Cells(r, 78).Value
        yv = ws.Cells(r, 79).Value
        If IsNumeric(xv) And IsNumeric(yv) Then
            If count > 0 Then
                ReDim Preserve xs(0 To count)
                ReDim Preserve ys(0 To count)
            End If
            xs(count) = CDbl(xv)
            ys(count) = CDbl(yv)
            count = count + 1
        ElseIf count > 0 Then
            Exit For
        End If
    Next r
    If count < 3 Then
        message = "The workbook has fewer than three X/Y points in BY:BZ:CA."
        GoTo Cleanup
    End If
    ReadLegacyCoordinates = True
Cleanup:
    On Error Resume Next
    wb.Close False
    xl.Quit
    Exit Function
Fail:
    message = "Could not read the workbook: " & Err.Description
    Resume Cleanup
End Function

Private Function ResolveWorkbookPath(ByVal value As String) As String
    Dim attr As Long, folder As String
    value = Replace(Trim$(value), """", "")
    On Error GoTo TreatAsFile
    attr = GetAttr(value)
    If (attr And vbDirectory) <> 0 Then
        folder = value
        If Right$(folder, 1) <> "\" Then folder = folder & "\"
        ResolveWorkbookPath = folder & "CSA_Stair Drawing Tools.xlsm"
        Exit Function
    End If
TreatAsFile:
    ResolveWorkbookPath = value
End Function

Private Sub EnsureLayer(ByVal layerName As String, ByVal colorIndex As Integer)
    Dim layer As Object
    On Error Resume Next
    Set layer = ThisDrawing.Layers.Item(layerName)
    On Error GoTo 0
    If layer Is Nothing Then Set layer = ThisDrawing.Layers.Add(layerName)
    layer.color = colorIndex
End Sub

Private Sub ClearLayer(ByVal layerName As String)
    Dim doomed As Collection, ent As Object, item As Variant
    Set doomed = New Collection
    For Each ent In ThisDrawing.ModelSpace
        On Error Resume Next
        If UCase$(ent.Layer) = UCase$(layerName) Then doomed.Add ent
        On Error GoTo 0
    Next ent
    For Each item In doomed
        On Error Resume Next
        item.Delete
        On Error GoTo 0
    Next item
End Sub

Private Sub DrawPolyline(ByRef xs() As Double, ByRef ys() As Double, ByVal count As Long, ByVal layerName As String)
    Dim coords() As Double, i As Long, pl As Object
    ReDim coords(0 To count * 2 - 1)
    For i = 0 To count - 1
        coords(i * 2) = xs(i)
        coords(i * 2 + 1) = ys(i)
    Next i
    Set pl = ThisDrawing.ModelSpace.AddLightWeightPolyline(coords)
    pl.Closed = True
    pl.Layer = layerName
End Sub

Private Sub DrawSection(ByVal x0 As Double, ByVal y0 As Double, ByVal n1 As Long, ByVal n2 As Long, ByVal rise As Double, ByVal tread As Double, ByVal landing As Double, ByVal layerName As String)
    Dim i As Long, x As Double, z As Double, midZ As Double
    midZ = n1 * rise
    For i = 0 To n1 - 1
        x = x0 + i * tread
        z = y0 + i * rise
        DrawLine x, z, x + tread, z, layerName
        DrawLine x + tread, z, x + tread, z + rise, layerName
    Next i
    DrawLine x0 + n1 * tread, y0 + midZ, x0 + n1 * tread + landing, y0 + midZ, layerName
    For i = 0 To n2 - 1
        x = x0 + n1 * tread + landing + i * tread
        z = y0 + midZ + i * rise
        DrawLine x, z, x + tread, z, layerName
        DrawLine x + tread, z, x + tread, z + rise, layerName
    Next i
End Sub

Private Sub DrawPlan(ByVal x0 As Double, ByVal y0 As Double, ByVal n1 As Long, ByVal n2 As Long, ByVal tread As Double, ByVal width As Double, ByVal landing As Double, ByVal layerName As String)
    Dim run As Double, gap As Double
    run = n1 * tread
    gap = width * 0.25
    DrawRectangle x0, y0, x0 + run, y0 + width, layerName
    DrawRectangle x0, y0 + width + gap, x0 + n2 * tread, y0 + 2# * width + gap, layerName
    DrawRectangle x0 + run - landing, y0, x0 + run, y0 + 2# * width + gap, layerName
End Sub

Private Sub DrawRectangle(ByVal x1 As Double, ByVal y1 As Double, ByVal x2 As Double, ByVal y2 As Double, ByVal layerName As String)
    DrawLine x1, y1, x2, y1, layerName
    DrawLine x2, y1, x2, y2, layerName
    DrawLine x2, y2, x1, y2, layerName
    DrawLine x1, y2, x1, y1, layerName
End Sub

Private Sub DrawLine(ByVal x1 As Double, ByVal y1 As Double, ByVal x2 As Double, ByVal y2 As Double, ByVal layerName As String)
    Dim a(0 To 2) As Double, b(0 To 2) As Double, ln As Object
    a(0) = x1: a(1) = y1: a(2) = 0#
    b(0) = x2: b(1) = y2: b(2) = 0#
    Set ln = ThisDrawing.ModelSpace.AddLine(a, b)
    ln.Layer = layerName
End Sub

Private Function ReadNumber(ByVal prompt As String, ByVal fallback As Double) As Double
    Dim value As String
    value = InputBox(prompt, "CSA Stair Drawing", CStr(fallback))
    If Len(Trim$(value)) = 0 Then
        ReadNumber = fallback
    ElseIf IsNumeric(value) Then
        ReadNumber = CDbl(value)
    Else
        ReadNumber = -1#
    End If
End Function
