Attribute VB_Name = "modCSAStairExcel"
Option Explicit

Public Function CSA_LoadInputFromExcel(ByVal filePath As String, ByRef v As CSAStairInput, ByRef message As String) As Boolean
    Dim xl As Object, wb As Object
    On Error GoTo Fail
    Set xl = CreateObject("Excel.Application")
    Set wb = xl.Workbooks.Open(filePath, False, True)
    v = CSA_DefaultInput()
    v.StairName = CSA_NamedText(wb, "StairName", v.StairName)
    v.StairType = CSA_NamedText(wb, "StairType", v.StairType)
    v.FloorHeight = CSA_NamedNumber(wb, "FloorHeight", v.FloorHeight)
    v.Width = CSA_NamedNumber(wb, "StairWidth", v.Width)
    v.Riser = CSA_NamedNumber(wb, "RiserHeight", v.Riser)
    v.Tread = CSA_NamedNumber(wb, "TreadDepth", v.Tread)
    v.Landing = CSA_NamedNumber(wb, "LandingLength", v.Landing)
    v.Slab = CSA_NamedNumber(wb, "SlabThickness", v.Slab)
    v.InsertX = CSA_NamedNumber(wb, "InsertX", v.InsertX)
    v.InsertY = CSA_NamedNumber(wb, "InsertY", v.InsertY)
    v.Flight1Risers = CLng(CSA_NamedNumber(wb, "Flight1Risers", v.Flight1Risers))
    v.Flight2Risers = CLng(CSA_NamedNumber(wb, "Flight2Risers", v.Flight2Risers))
    If Not wb Is Nothing Then wb.Close False
    If Not xl Is Nothing Then xl.Quit
    CSA_LoadInputFromExcel = True
    Exit Function
Fail:
    message = "Excel load failed: " & Err.Description
    On Error Resume Next
    If Not wb Is Nothing Then wb.Close False
    If Not xl Is Nothing Then xl.Quit
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
