Attribute VB_Name = "modCSAStairApiTests"
Option Explicit

' Import with modCSAStairHost and modCSAStairWinApi. No UserForm required.
Private Sub Require(ByVal condition As Boolean, ByVal description As String)
    If Not condition Then Err.Raise vbObjectError + 480, "CSA API test", description
End Sub

Public Sub CSA_TestVersionMapping()
    Dim versions As Variant, years As Variant, i As Long, value As Variant
    versions = Array("22.0", "23.0", "23.1", "24.0", "24.1", "24.2", "24.3", "25.0", "25.1")
    years = Array(2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026)
    For i = 0 To UBound(versions)
        Require CSA_AcadReleaseYear(CStr(versions(i)) & "s (LMS Tech)") = CLng(years(i)), "Release mapping mismatch."
        Require CSA_AcadReleaseYear(" " & CStr(versions(i)) & ".1000 ") = CLng(years(i)), "Patch mapping mismatch."
    Next i
    For Each value In Array("", "24", "24.10", "25.2", "21.0", "AutoCAD 2022", "x24.1")
        Require CSA_AcadReleaseYear(CStr(value)) = 0, "Unknown release accepted: " & CStr(value)
    Next value
    MsgBox "Version mapping tests passed. This does not certify AutoCAD runtime compatibility.", vbInformation, "CSA API test"
End Sub

Public Sub CSA_TestActiveXApi()
    ' Explicit opt-in macro. All writes occur in a NEW unsaved test drawing.
    ' Never save, erase or change entities/resources in the user's drawing.
    Dim original As Object, app As Object, testDoc As Object, space As Object
    Dim line As Object, pline As Object, circle As Object, text As Object, dimObj As Object
    Dim blockDef As Object, blockRef As Object, attDef As Object, att As Variant
    Dim attrs As Variant, coords(0 To 5) As Double, low As Variant, high As Variant
    Dim codes(0 To 1) As Integer, values(0 To 1) As Variant
    Dim readCodes As Variant, readValues As Variant, obj As Object, dpi As Double
    Dim errorNumber As Long, errorText As String, stage As String, closeError As String
    On Error GoTo Failed
    stage = "Host preflight"
    Set original = CSA_CadDocument()
    Set app = original.Application
    stage = "Create isolated unsaved drawing"
    Set testDoc = app.Documents.Add
    testDoc.Activate
    testDoc.SetVariable "INSUNITS", 4 ' millimetres, this test document only
    Set space = testDoc.ModelSpace
    stage = "Layers and primitive entities"
    Set obj = testDoc.Layers.Add("CSA_API_TEST")
    Set line = space.AddLine(CSA_Point3D(0, 0), CSA_Point3D(100, 0))
    line.Layer = obj.Name
    coords(0) = 0: coords(1) = 0
    coords(2) = 100: coords(3) = 0
    coords(4) = 100: coords(5) = 100
    Set pline = space.AddLightWeightPolyline(coords)
    pline.Closed = False
    Set circle = space.AddCircle(CSA_Point3D(100, 100), 30#)
    Set text = space.AddText("%%C10a200", CSA_Point3D(0, 150), 10#)
    Require Abs(line.Length - 100#) < 0.000001, "Line length round trip."
    Require Abs(circle.Radius - 30#) < 0.000001, "Circle radius round trip."
    Require text.TextString = "%%C10a200", "Text round trip."
    stage = "Dimensions and bounding box"
    Set dimObj = space.AddDimAligned(CSA_Point3D(0, 0), CSA_Point3D(100, 0), CSA_Point3D(50, -50))
    dimObj.ExtLine1Suppress = True
    dimObj.ExtLine2Suppress = True
    dimObj.Update
    Require Abs(dimObj.Measurement - 100#) < 0.000001, "Dimension measurement round trip."
    circle.GetBoundingBox low, high
    Require Abs(CDbl(high(0)) - CDbl(low(0)) - 60#) < 0.000001, "Bounding box round trip."
    stage = "Block attributes"
    Set blockDef = testDoc.Blocks.Add(CSA_Point3D(0, 0), "CSA_API_TEST_BLOCK")
    Set attDef = blockDef.AddAttribute(10#, 0, "Mark", CSA_Point3D(0, 0), "SH", "1")
    Set blockRef = space.InsertBlock(CSA_Point3D(200, 0), blockDef.Name, 1#, 1#, 1#, 0#)
    attrs = blockRef.GetAttributes
    Require UBound(attrs) = LBound(attrs), "Expected one editable attribute."
    Set att = attrs(LBound(attrs))
    att.TextString = "7"
    att.Update
    Require att.TextString = "7", "Attribute update round trip."
    stage = "Preview ownership XData"
    Set obj = testDoc.RegisteredApplications.Add("CSA_API_TEST")
    codes(0) = 1001: codes(1) = 1000
    values(0) = "CSA_API_TEST": values(1) = "OWNED"
    pline.SetXData codes, values
    pline.GetXData "CSA_API_TEST", readCodes, readValues
    Require readValues(1) = "OWNED", "XData round trip."
    stage = "Windows API and redraw"
    dpi = CSA_SystemDpiX()
    Require dpi > 0, "DPI must be positive."
    testDoc.Regen CSA_AC_ALL_VIEWPORTS
    Debug.Print CSA_HostDescription(original)
    Debug.Print "ActiveX smoke test passed; system DPI=" & CStr(dpi)
    stage = "Close isolated drawing without saving"
    testDoc.Close False
    Set testDoc = Nothing
    original.Activate
    MsgBox "ActiveX/DPI smoke test passed. UserForm and stair geometry acceptance remain pending.", vbInformation, "CSA API test"
    Exit Sub
Failed:
    errorNumber = Err.Number: errorText = Err.Description
    On Error Resume Next
    Err.Clear
    If Not testDoc Is Nothing Then testDoc.Close False
    If Err.Number <> 0 Then closeError = vbCrLf & "Test drawing could not close; close it without saving."
    If Not original Is Nothing Then original.Activate
    On Error GoTo 0
    MsgBox "Failed at " & stage & " (" & CStr(errorNumber) & "): " & errorText & closeError, vbExclamation, "CSA API test"
End Sub
