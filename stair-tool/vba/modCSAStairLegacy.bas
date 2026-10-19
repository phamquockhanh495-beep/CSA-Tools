Attribute VB_Name = "modCSAStairLegacy"
Option Explicit

' Adapter for the workbook currently in the repository:
'   sheet  = Cau Thang Tools
'   BY     = point number
'   BZ     = X
'   CA     = Y
' It keeps the existing Excel formulas untouched and lets the new preview
' layer display the coordinates that the workbook already calculates.

Public Sub CSA_PreviewCurrentWorkbook()
    Dim path As String, message As String
    Dim xs() As Double, ys() As Double, count As Long
    path = InputBox("Enter the full path to CSA_Stair Drawing Tools.xlsm:", "Preview current workbook")
    If Len(Trim$(path)) = 0 Then Exit Sub
    If Not CSA_ReadLegacyCoordinates(path, xs, ys, count, message) Then
        MsgBox message, vbExclamation, "CSA Stair Drawing"
        Exit Sub
    End If
    CSA_EnsureLayers
    CSA_ClearPreview
    CSA_DrawLegacyPolyline xs, ys, count, CSA_LAYER_PREVIEW
    ThisDrawing.Regen acActiveViewport
    ThisDrawing.Application.ZoomExtents
End Sub

Public Function CSA_ReadLegacyCoordinates(ByVal filePath As String, ByRef xs() As Double, ByRef ys() As Double, ByRef count As Long, ByRef message As String) As Boolean
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
        message = "Cau Thang Tools does not contain at least three X/Y points in BY:BZ:CA."
        GoTo Cleanup
    End If
    CSA_ReadLegacyCoordinates = True
Cleanup:
    On Error Resume Next
    wb.Close False
    xl.Quit
    Exit Function
Fail:
    message = "Could not read the current workbook: " & Err.Description
    Resume Cleanup
End Function

Public Sub CSA_DrawLegacyPolyline(ByRef xs() As Double, ByRef ys() As Double, ByVal count As Long, ByVal targetLayer As String)
    Dim coords() As Double, i As Long
    Dim pl As Object
    ReDim coords(0 To count * 2 - 1)
    For i = 0 To count - 1
        coords(i * 2) = xs(i)
        coords(i * 2 + 1) = ys(i)
    Next i
    Set pl = ThisDrawing.ModelSpace.AddLightWeightPolyline(coords)
    pl.Closed = True
    pl.Layer = targetLayer
End Sub
