Attribute VB_Name = "modCSAStairExcel"
Option Explicit

' Reads stair inputs from the CSA Excel workbook (sheet "Cau Thang Tools").
' Prefers attaching to an already-open Excel session (read-only, never edits
' or closes a user-opened workbook). Falls back to named ranges if the sheet
' is absent.

Public Function CSA_LoadInputFromExcel(ByVal filePath As String, ByRef v As CSAStairInput, ByRef message As String) As Boolean
    Dim xl As Object, wb As Object, ws As Object
    Dim createdExcel As Boolean, openedWorkbook As Boolean, keepOpen As Boolean
    Dim wbItem As Object, fileName As String, sepPos As Long
    Dim bottomElev As Double, floorH As Double, widthVal As Double
    Dim riserVal As Double, slabVal As Double, landVal As Double, uLandVal As Double
    Dim flightRun As Double, flightSteps As Long, stairTitle As String

    On Error GoTo Fail
    keepOpen = v.OpenExcel
    sepPos = InStrRev(filePath, "\")
    fileName = IIf(sepPos > 0, Mid$(filePath, sepPos + 1), filePath)

    ' 1. Try attaching to an already-running Excel session first.
    On Error Resume Next
    Set xl = GetObject(, "Excel.Application")
    On Error GoTo Fail
    If Not xl Is Nothing Then
        For Each wbItem In xl.Workbooks
            If StrComp(CStr(wbItem.FullName), filePath, vbTextCompare) = 0 Or _
               StrComp(CStr(wbItem.Name), fileName, vbTextCompare) = 0 Then
                Set wb = wbItem
                Exit For
            End If
        Next wbItem
    End If

    ' 2. If not open yet, open read-only in a temporary Excel session (or keep open if requested).
    If wb Is Nothing Then
        If xl Is Nothing Then
            Set xl = CreateObject("Excel.Application")
            createdExcel = True
        End If
        Set wb = xl.Workbooks.Open(filePath, False, True)
        openedWorkbook = True
        If keepOpen And createdExcel Then xl.Visible = True
    End If

    v = CSA_DefaultInput()
    v.OpenExcel = keepOpen
    v.ExcelPath = filePath

    On Error Resume Next
    Set ws = wb.Worksheets("Cau Thang Tools")
    On Error GoTo Fail

    If Not ws Is Nothing Then
        stairTitle = CSA_CellText(ws, "AD33", v.StairName)
        v.StairName = stairTitle
        floorH = CSA_CellNumber(ws, "D22", v.FloorHeight)
        If floorH > 0# Then v.FloorHeight = floorH
        bottomElev = CSA_CellNumber(ws, "M30", v.BottomElevation)
        v.BottomElevation = bottomElev
        v.TopElevation = bottomElev + v.FloorHeight / 1000#

        widthVal = CSA_CellNumber(ws, "BJ29", v.Width)
        If widthVal > 0# Then v.Width = widthVal
        slabVal = CSA_CellNumber(ws, "AO27", v.Slab)
        If slabVal > 0# Then v.Slab = slabVal
        landVal = CSA_CellNumber(ws, "H19", v.Landing)
        If landVal > 0# Then v.Landing = landVal
        uLandVal = CSA_CellNumber(ws, "BA19", v.UpperLanding)
        If uLandVal >= 0# Then v.UpperLanding = uLandVal

        riserVal = CSA_CellNumber(ws, "AV21", v.Riser)
        If riserVal > 0# Then v.Riser = riserVal
        flightSteps = CLng(CSA_CellNumber(ws, "AI23", 0#))
        flightRun = CSA_CellNumber(ws, "Z19", 0#)
        If flightSteps > 0 And flightRun > 0# Then
            v.Tread = flightRun / CDbl(flightSteps)
        End If
        CSA_DistributeRisers v
    Else
        v.StairName = CSA_NamedText(wb, "StairName", v.StairName)
        v.StairType = CSA_NamedText(wb, "StairType", v.StairType)
        v.FloorHeight = CSA_NamedNumber(wb, "FloorHeight", v.FloorHeight)
        v.TopElevation = v.BottomElevation + v.FloorHeight / 1000#
        v.Width = CSA_NamedNumber(wb, "StairWidth", v.Width)
        v.Riser = CSA_NamedNumber(wb, "RiserHeight", v.Riser)
        v.Tread = CSA_NamedNumber(wb, "TreadDepth", v.Tread)
        v.Landing = CSA_NamedNumber(wb, "LandingLength", v.Landing)
        v.Slab = CSA_NamedNumber(wb, "SlabThickness", v.Slab)
        v.InsertX = CSA_NamedNumber(wb, "InsertX", v.InsertX)
        v.InsertY = CSA_NamedNumber(wb, "InsertY", v.InsertY)
        v.Flight1Risers = CLng(CSA_NamedNumber(wb, "Flight1Risers", v.Flight1Risers))
        v.Flight2Risers = CLng(CSA_NamedNumber(wb, "Flight2Risers", v.Flight2Risers))
    End If

    If openedWorkbook And Not v.OpenExcel Then
        If Not wb Is Nothing Then wb.Close False
        If createdExcel And Not xl Is Nothing Then xl.Quit
    End If
    CSA_LoadInputFromExcel = True
    Exit Function
Fail:
    message = "Excel load failed: " & Err.Description
    On Error Resume Next
    If openedWorkbook And Not v.OpenExcel Then
        If Not wb Is Nothing Then wb.Close False
        If createdExcel And Not xl Is Nothing Then xl.Quit
    End If
End Function

Private Function CSA_CellNumber(ByVal ws As Object, ByVal addr As String, ByVal fallback As Double) As Double
    Dim value As Variant
    On Error GoTo UseFallback
    value = ws.Range(addr).Value
    If IsNumeric(value) And Not IsEmpty(value) Then
        CSA_CellNumber = CDbl(value)
    Else
        CSA_CellNumber = fallback
    End If
    Exit Function
UseFallback:
    CSA_CellNumber = fallback
End Function

Private Function CSA_CellText(ByVal ws As Object, ByVal addr As String, ByVal fallback As String) As String
    Dim value As Variant
    On Error GoTo UseFallback
    value = ws.Range(addr).Value
    If Not IsError(value) And Len(Trim$(CStr(value))) > 0 Then
        CSA_CellText = Trim$(CStr(value))
    Else
        CSA_CellText = fallback
    End If
    Exit Function
UseFallback:
    CSA_CellText = fallback
End Function

Private Function CSA_NamedNumber(ByVal wb As Object, ByVal name As String, ByVal fallback As Double) As Double
    Dim value As Variant
    On Error GoTo Fallback
    value = wb.Names(name).RefersToRange.Value
    If IsNumeric(value) Then CSA_NamedNumber = CDbl(value) Else CSA_NamedNumber = fallback
    Exit Function
Fallback:
    CSA_NamedNumber = fallback
End Function

Private Function CSA_NamedText(ByVal wb As Object, ByVal name As String, ByVal fallback As String) As String
    Dim value As Variant
    On Error GoTo Fallback
    value = wb.Names(name).RefersToRange.Value
    If Len(Trim$(CStr(value))) > 0 Then CSA_NamedText = CStr(value) Else CSA_NamedText = fallback
    Exit Function
Fallback:
    CSA_NamedText = fallback
End Function
