Attribute VB_Name = "modCSAStairApiTests"
Option Explicit

' Import with modCSAStairHost and modCSAStairWinApi. No UserForm required.
Private Sub Require(ByVal condition As Boolean, ByVal description As String)
    If Not condition Then Err.Raise vbObjectError + 480, "CSA API test", description
End Sub

Public Sub CSA_TestVersionMapping()
    Dim versions As Variant, years As Variant, i As Long, value As Variant
    versions = Array("22.0", "23.0", "23.1", "24.0", "24.1", "24.2", "24.3", "25.0", "25.1", "26.0")
    years = Array(2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, 2026, 2027)
    For i = 0 To UBound(versions)
        Require CSA_AcadReleaseYear(CStr(versions(i)) & "s (LMS Tech)") = CLng(years(i)), "Release mapping mismatch."
        Require CSA_AcadReleaseYear(" " & CStr(versions(i)) & ".1000 ") = CLng(years(i)), "Patch mapping mismatch."
    Next i
    For Each value In Array("", "24", "24.10", "25.2", "26.1", "21.0", "AutoCAD 2022", "x24.1")
        Require CSA_AcadReleaseYear(CStr(value)) = 0, "Unknown release accepted: " & CStr(value)
    Next value
    MsgBox "Version mapping tests passed (2018-2027). This does not certify AutoCAD runtime compatibility.", vbInformation, "CSA API test"
End Sub

Public Sub CSA_TestActiveXApi()
    ' Explicit opt-in macro. All writes occur in a NEW unsaved test drawing.
    ' Never save, erase or change entities/resources in the user's drawing.
    Dim original As Object, app As Object, testDoc As Object, space As Object
    Dim lineObj As Object, pline As Object, circleObj As Object, textObj As Object, dimObj As Object
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
    Set lineObj = space.AddLine(CSA_Point3D(0, 0), CSA_Point3D(100, 0))
    lineObj.Layer = obj.Name
    coords(0) = 0: coords(1) = 0
    coords(2) = 100: coords(3) = 0
    coords(4) = 100: coords(5) = 100
    Set pline = space.AddLightWeightPolyline(coords)
    pline.Closed = False
    Set circleObj = space.AddCircle(CSA_Point3D(100, 100), 30#)
    Set textObj = space.AddText("%%C10a200", CSA_Point3D(0, 150), 10#)
    Require Abs(lineObj.Length - 100#) < 0.000001, "Line length round trip."
    Require Abs(circleObj.Radius - 30#) < 0.000001, "Circle radius round trip."
    Require textObj.TextString = "%%C10a200", "Text round trip."
    stage = "Dimensions and bounding box"
    Set dimObj = space.AddDimAligned(CSA_Point3D(0, 0), CSA_Point3D(100, 0), CSA_Point3D(50, -50))
    dimObj.ExtLine1Suppress = True
    dimObj.ExtLine2Suppress = True
    dimObj.Update
    Require Abs(dimObj.Measurement - 100#) < 0.000001, "Dimension measurement round trip."
    circleObj.GetBoundingBox low, high
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

Public Sub CSA_TestFormPreviewApi()
    ' Verifies Win32 GDI offscreen bitmap + OleCreatePictureIndirect without modifying any DWG.
    Dim canvas As CSA_GdiCanvas
    Dim pic As Object
    Dim dpi As Double, px As Long
    On Error GoTo Failed
    dpi = CSA_SystemDpiX()
    Require dpi > 0#, "System DPI must be positive."
    px = CSA_FormPointsToPixels(100#)
    Require px > 0, "Points-to-pixels conversion must be positive."
    Require CSA_BeginCanvas(240, 160, canvas), "Failed to start GDI canvas."
    CSA_CanvasFillRect canvas, 0, 0, 240, 160, RGB(255, 255, 255)
    CSA_CanvasRect canvas, 10, 10, 230, 150, RGB(27, 73, 130), 2
    CSA_CanvasLine canvas, 20, 130, 220, 30, RGB(200, 30, 30), 2
    CSA_CanvasCircle canvas, 120, 80, 12, RGB(27, 73, 130), RGB(230, 240, 255)
    CSA_CanvasText canvas, 120, 16, "CSA GDI OK", RGB(27, 73, 130), 14, True, CSA_ALIGN_CENTER
    Set pic = CSA_EndCanvasToPicture(canvas)
    Require Not pic Is Nothing, "OleCreatePictureIndirect returned Nothing."
    Require pic.Width > 0 And pic.Height > 0, "Generated IPictureDisp has empty dimensions."
    Set pic = Nothing
    MsgBox "Form GDI preview API test passed (DPI=" & CStr(dpi) & ").", vbInformation, "CSA API test"
    Exit Sub
Failed:
    CSA_DiscardCanvas canvas
    MsgBox "Form GDI preview API test failed (" & CStr(Err.Number) & "): " & Err.Description, vbExclamation, "CSA API test"
End Sub
