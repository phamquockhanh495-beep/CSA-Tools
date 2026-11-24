Attribute VB_Name = "modCSAStairExcel"
Option Explicit

' Reads stair concrete & rebar parameters + 24-point section contract from
' sheet "Cau Thang Tools" (preferring an already-open Excel session, read-only).

Public Function CSA_LoadInputFromExcel(ByVal filePath As String, ByRef v As CSAStairInput, ByRef message As String) As Boolean
    Dim xl As Object, wb As Object, ws As Object
    Dim createdExcel As Boolean, openedWorkbook As Boolean, keepOpen As Boolean
    Dim wbItem As Object, fileName As String, sepPos As Long
    Dim bottomElev As Double, floorH As Double, widthVal As Double
    Dim riserVal As Double, slabVal As Double, landVal As Double, uLandVal As Double
    Dim flightRun As Double, flightSteps As Long, stairTitle As String
    Dim r As Long, ptCount As Long, idVal As Variant, xVal As Variant, yVal As Variant
    Dim downVal As Double, coverVal As Double, ancVal As Double

    On Error GoTo Fail
    keepOpen = v.OpenExcel
    sepPos = InStrRev(filePath, "\")
    fileName = IIf(sepPos > 0, Mid$(filePath, sepPos + 1), filePath)

    ' 1. Attach to already-running Excel session first (never edits or closes user's workbook).
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

    ' 2. Otherwise open read-only in a temporary Excel session.
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
        downVal = CSA_CellNumber(ws, "D33", v.BeamDownstand)
        If downVal >= 0# Then v.BeamDownstand = downVal

        riserVal = CSA_CellNumber(ws, "AV21", v.Riser)
        If riserVal > 0# Then v.Riser = riserVal
        v.ExcelLowerSteps = CLng(CSA_CellNumber(ws, "U28", 0#))
        flightSteps = CLng(CSA_CellNumber(ws, "AI23", 0#))
        v.ExcelFlightSteps = flightSteps
        flightRun = CSA_CellNumber(ws, "Z19", 0#)
        If flightSteps > 0 And flightRun > 0# Then
            v.Tread = flightRun / CDbl(flightSteps)
        End If

        ' Rebar contract cells (BJ28:BJ39, Z23:Z26)
        coverVal = CSA_CellNumber(ws, "BJ28", v.CoverMm)
        If coverVal > 0# Then v.CoverMm = coverVal
        v.LowerLandingBotBar = CSA_CellText(ws, "BJ32", v.LowerLandingBotBar)
        v.LowerLandingTopBar = CSA_CellText(ws, "BJ33", v.LowerLandingTopBar)
        v.FlightBotBar = CSA_CellText(ws, "BJ34", v.FlightBotBar)
        v.FlightTopBar = CSA_CellText(ws, "BJ35", v.FlightTopBar)
        v.DistBar = CSA_CellText(ws, "BJ36", v.DistBar)
        v.RebarLayers = CLng(CSA_CellNumber(ws, "BJ37", CDbl(v.RebarLayers)))
        If v.RebarLayers < 1 Or v.RebarLayers > 2 Then v.RebarLayers = 2
        ancVal = CSA_CellNumber(ws, "BJ38", v.AnchorFactor)
        If ancVal > 0# Then v.AnchorFactor = ancVal
        v.StartBarMark = CLng(CSA_CellNumber(ws, "BJ39", CDbl(v.StartBarMark)))
        If v.StartBarMark < 1 Then v.StartBarMark = 1
        v.HasUpperLandingBars = CSA_CellFlag(ws, "Z23", True)
        v.HasLowerLandingBars = CSA_CellFlag(ws, "Z24", True)
        v.HasUpperLandingDots = CSA_CellFlag(ws, "Z25", True)
        v.HasLowerLandingDots = CSA_CellFlag(ws, "Z26", True)

        ' Read 24-point concrete coordinate table BY2:CA25 (columns 77, 78, 79)
        ptCount = 0
        For r = 2 To 25
            idVal = ws.Cells(r, 77).Value
            xVal = ws.Cells(r, 78).Value
            yVal = ws.Cells(r, 79).Value
            If IsEmpty(idVal) Or Not IsNumeric(xVal) Or Not IsNumeric(yVal) Then Exit For
            v.ExcelRawX(ptCount) = CDbl(xVal)
            v.ExcelRawY(ptCount) = CDbl(yVal)
            ptCount = ptCount + 1
        Next r
        If ptCount = 24 Then
            v.HasExcelCoords = True
            v.ExcelPointCount = 24
        Else
            v.HasExcelCoords = False
            v.ExcelPointCount = 0
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
        v.Flight1Risers = CLng(CSA_NamedNumber(wb, "Flight1Risers", v.Flight1Risers))
        v.Flight2Risers = CLng(CSA_NamedNumber(wb, "Flight2Risers", v.Flight2Risers))
    End If

    If openedWorkbook And Not keepOpen Then
        If Not wb Is Nothing Then wb.Close False
        If createdExcel And Not xl Is Nothing Then xl.Quit
    End If
    CSA_LoadInputFromExcel = True
    Exit Function
Fail:
    message = "Excel load failed: " & Err.Description
    On Error Resume Next
    If openedWorkbook And Not keepOpen Then
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

Private Function CSA_CellFlag(ByVal ws As Object, ByVal addr As String, ByVal fallback As Boolean) As Boolean
    Dim s As String
    s = UCase$(CSA_CellText(ws, addr, IIf(fallback, "YES", "NO")))
    If s = "NO" Or s = "0" Or s = "FALSE" Or s = "N" Then
        CSA_CellFlag = False
    Else
        CSA_CellFlag = True
    End If
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
