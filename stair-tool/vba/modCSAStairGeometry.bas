Attribute VB_Name = "modCSAStairGeometry"
Option Explicit

Public Function CSA_ValidateInput(ByRef v As CSAStairInput, ByRef message As String) As Boolean
    Dim totalRisers As Long
    message = ""
    If Len(Trim$(v.StairName)) = 0 Then message = "Stair name is required.": Exit Function
    If v.FloorHeight <= 0# Then message = "Floor height must be positive (Top > Bottom elevation).": Exit Function
    If v.Width <= 0# Then message = "Flight width must be positive.": Exit Function
    If v.Riser <= 0# Then message = "Riser must be positive.": Exit Function
    If v.Tread <= 0# Then message = "Tread must be positive.": Exit Function
    If v.Landing < 0# Then message = "Landing length cannot be negative.": Exit Function
    If v.UpperLanding < 0# Then message = "Upper landing length cannot be negative.": Exit Function
    If v.WellGap < 0# Then message = "Well gap cannot be negative.": Exit Function
    If v.SupportWidth < 0# Then message = "Support width cannot be negative.": Exit Function
    If v.Slab <= 0# Then message = "Slab thickness must be positive.": Exit Function

    Select Case v.StairType
        Case CSA_TYPE_SINGLE_FLIGHT
            If v.Flight1Risers < 1 Then message = "Single flight needs at least one riser.": Exit Function
            totalRisers = v.Flight1Risers
        Case CSA_TYPE_THREE_FLIGHT
            If v.Landing <= 0# Then message = "Landing length must be positive for three-flight stair.": Exit Function
            If v.Flight1Risers < 1 Or v.Flight2Risers < 1 Or v.Flight3Risers < 1 Then
                message = "All three flights need at least one riser.": Exit Function
            End If
            totalRisers = v.Flight1Risers + v.Flight2Risers + v.Flight3Risers
        Case Else
            If v.Landing <= 0# Then message = "Landing length must be positive.": Exit Function
            If v.Flight1Risers < 1 Or v.Flight2Risers < 1 Then
                message = "Both flights need at least one riser.": Exit Function
            End If
            totalRisers = v.Flight1Risers + v.Flight2Risers
    End Select

    If Abs(totalRisers * v.Riser - v.FloorHeight) > 0.5 Then
        message = "Total risers (" & CStr(totalRisers) & " x " & Format$(v.Riser, "0.##") & _
                  ") does not match floor height (" & Format$(v.FloorHeight, "0.##") & " mm)."
        Exit Function
    End If
    CSA_ValidateInput = True
End Function

Public Function CSA_MakeFlight(ByRef v As CSAStairInput, ByVal flightNo As Long) As CSAFlight
    Dim f As CSAFlight
    f.Width = v.Width
    f.Riser = v.Riser
    f.Tread = v.Tread
    If flightNo = 1 Then
        f.RiserCount = v.Flight1Risers
    ElseIf flightNo = 2 Then
        f.RiserCount = v.Flight2Risers
    Else
        f.RiserCount = v.Flight3Risers
    End If
    f.RunLength = f.RiserCount * f.Tread
    f.StartX = v.InsertX
    f.StartY = v.InsertY
    f.StartZ = IIf(flightNo = 1, 0#, v.Flight1Risers * v.Riser)
    f.Angle = IIf(flightNo = 1, 0#, 3.14159265358979)
    CSA_MakeFlight = f
End Function

Public Function CSA_LocalPoint(ByRef f As CSAFlight, ByVal x As Double, ByVal y As Double, ByVal z As Double) As CSAPoint
    Dim p As CSAPoint
    p.X = f.StartX + x * Cos(f.Angle) - y * Sin(f.Angle)
    p.Y = f.StartY + x * Sin(f.Angle) + y * Cos(f.Angle)
    p.Z = f.StartZ + z
    CSA_LocalPoint = p
End Function

Public Sub CSA_AddPreviewLine(ByRef p1 As CSAPoint, ByRef p2 As CSAPoint)
    Dim a(0 To 2) As Double, b(0 To 2) As Double
    Dim ln As Object
    a(0) = p1.X: a(1) = p1.Y: a(2) = p1.Z
    b(0) = p2.X: b(1) = p2.Y: b(2) = p2.Z
    Set ln = ThisDrawing.ModelSpace.AddLine(a, b)
    If Len(CSA_RenderLayer) = 0 Then CSA_RenderLayer = CSA_LAYER_PREVIEW
    ln.Layer = CSA_RenderLayer
    ln.color = 256
    ln.Linetype = "ByLayer"
    ln.Lineweight = -1
    CSA_MarkPreview ln
End Sub

Public Sub CSA_AddPreviewPolyline(ByRef pts() As CSAPoint, ByVal closed As Boolean)
    Dim coords() As Double, i As Long
    Dim pl As Object
    ReDim coords(0 To (UBound(pts) + 1) * 2 - 1)
    For i = 0 To UBound(pts)
        coords(i * 2) = pts(i).X
        coords(i * 2 + 1) = pts(i).Y
    Next i
    Set pl = ThisDrawing.ModelSpace.AddLightWeightPolyline(coords)
    pl.Closed = closed
    If Len(CSA_RenderLayer) = 0 Then CSA_RenderLayer = CSA_LAYER_PREVIEW
    pl.Layer = CSA_RenderLayer
    pl.color = 256
    pl.Linetype = "ByLayer"
    pl.Lineweight = -1
    CSA_MarkPreview pl
End Sub

Public Sub CSA_BuildSectionPreview(ByRef v As CSAStairInput)
    Dim x As Double, y As Double, i As Long
    Dim p1 As CSAPoint, p2 As CSAPoint
    Dim run1 As Double, run2 As Double, midY As Double
    run1 = v.Flight1Risers * v.Tread
    run2 = v.Flight2Risers * v.Tread
    midY = v.InsertY + v.Flight1Risers * v.Riser

    For i = 0 To v.Flight1Risers - 1
        x = v.InsertX + i * v.Tread
        y = v.InsertY + i * v.Riser
        p1 = CSA_Point(x, y, 0#)
        p2 = CSA_Point(x, y + v.Riser, 0#)
        CSA_AddPreviewLine p1, p2
        p1 = p2
        p2 = CSA_Point(x + v.Tread, y + v.Riser, 0#)
        CSA_AddPreviewLine p1, p2
    Next i

    If v.StairType = CSA_TYPE_SINGLE_FLIGHT Then
        p1 = CSA_Point(v.InsertX + run1, midY, 0#)
        p2 = CSA_Point(v.InsertX + run1 + v.UpperLanding, midY, 0#)
        CSA_AddPreviewLine p1, p2
        p1 = CSA_Point(v.InsertX, v.InsertY - v.Slab, 0#)
        p2 = CSA_Point(v.InsertX + run1, midY - v.Slab, 0#)
        CSA_AddPreviewLine p1, p2
        Exit Sub
    End If

    p1 = CSA_Point(v.InsertX + run1, midY, 0#)
    p2 = CSA_Point(v.InsertX + run1 + v.Landing, midY, 0#)
    CSA_AddPreviewLine p1, p2

    For i = 0 To v.Flight2Risers - 1
        x = v.InsertX + run1 + v.Landing + i * v.Tread
        y = midY + i * v.Riser
        p1 = CSA_Point(x, y, 0#)
        p2 = CSA_Point(x, y + v.Riser, 0#)
        CSA_AddPreviewLine p1, p2
        p1 = p2
        p2 = CSA_Point(x + v.Tread, y + v.Riser, 0#)
        CSA_AddPreviewLine p1, p2
    Next i

    p1 = CSA_Point(v.InsertX, v.InsertY - v.Slab, 0#)
    p2 = CSA_Point(v.InsertX + run1, midY - v.Slab, 0#)
    CSA_AddPreviewLine p1, p2
    p1 = p2
    p2 = CSA_Point(v.InsertX + run1 + v.Landing, midY - v.Slab, 0#)
    CSA_AddPreviewLine p1, p2
    p1 = p2
    p2 = CSA_Point(v.InsertX + run1 + v.Landing + run2, midY + v.Flight2Risers * v.Riser - v.Slab, 0#)
    CSA_AddPreviewLine p1, p2
End Sub

Public Sub CSA_BuildPlanPreview(ByRef v As CSAStairInput)
    Dim p(0 To 3) As CSAPoint
    Dim p1 As CSAPoint, p2 As CSAPoint
    Dim run1 As Double, run2 As Double, maxRun As Double
    Dim gap As Double, upperLand As Double, x0 As Double, y0 As Double
    Dim i As Long, treadX As Double

    x0 = v.InsertX
    y0 = v.InsertY
    run1 = v.Flight1Risers * v.Tread
    run2 = v.Flight2Risers * v.Tread
    maxRun = IIf(run1 >= run2, run1, run2)
    gap = v.WellGap
    upperLand = v.UpperLanding

    If v.StairType = CSA_TYPE_SINGLE_FLIGHT Then
        p(0) = CSA_Point(x0, y0, 0#)
        p(1) = CSA_Point(x0 + run1 + upperLand, y0, 0#)
        p(2) = CSA_Point(x0 + run1 + upperLand, y0 + v.Width, 0#)
        p(3) = CSA_Point(x0, y0 + v.Width, 0#)
        CSA_AddPreviewPolyline p, True
        For i = 1 To v.Flight1Risers
            treadX = x0 + i * v.Tread
            p1 = CSA_Point(treadX, y0, 0#)
            p2 = CSA_Point(treadX, y0 + v.Width, 0#)
            CSA_AddPreviewLine p1, p2
        Next i
        Exit Sub
    End If

    ' Lower flight (flight 1)
    p(0) = CSA_Point(x0, y0, 0#)
    p(1) = CSA_Point(x0 + maxRun, y0, 0#)
    p(2) = CSA_Point(x0 + maxRun, y0 + v.Width, 0#)
    p(3) = CSA_Point(x0, y0 + v.Width, 0#)
    CSA_AddPreviewPolyline p, True
    For i = 1 To v.Flight1Risers - 1
        treadX = x0 + i * v.Tread
        p1 = CSA_Point(treadX, y0, 0#)
        p2 = CSA_Point(treadX, y0 + v.Width, 0#)
        CSA_AddPreviewLine p1, p2
    Next i

    ' Upper flight (flight 2)
    p(0) = CSA_Point(x0, y0 + v.Width + gap, 0#)
    p(1) = CSA_Point(x0 + maxRun, y0 + v.Width + gap, 0#)
    p(2) = CSA_Point(x0 + maxRun, y0 + 2# * v.Width + gap, 0#)
    p(3) = CSA_Point(x0, y0 + 2# * v.Width + gap, 0#)
    CSA_AddPreviewPolyline p, True
    For i = 1 To v.Flight2Risers - 1
        treadX = x0 + i * v.Tread
        p1 = CSA_Point(treadX, y0 + v.Width + gap, 0#)
        p2 = CSA_Point(treadX, y0 + 2# * v.Width + gap, 0#)
        CSA_AddPreviewLine p1, p2
    Next i

    ' Intermediate landing on right
    p(0) = CSA_Point(x0 + maxRun, y0, 0#)
    p(1) = CSA_Point(x0 + maxRun + v.Landing, y0, 0#)
    p(2) = CSA_Point(x0 + maxRun + v.Landing, y0 + 2# * v.Width + gap, 0#)
    p(3) = CSA_Point(x0 + maxRun, y0 + 2# * v.Width + gap, 0#)
    CSA_AddPreviewPolyline p, True

    ' Optional upper landing on left
    If upperLand > 0# Then
        p(0) = CSA_Point(x0 - upperLand, y0, 0#)
        p(1) = CSA_Point(x0, y0, 0#)
        p(2) = CSA_Point(x0, y0 + 2# * v.Width + gap, 0#)
        p(3) = CSA_Point(x0 - upperLand, y0 + 2# * v.Width + gap, 0#)
        CSA_AddPreviewPolyline p, True
    End If
End Sub

Private Function CSA_Point(ByVal x As Double, ByVal y As Double, ByVal z As Double) As CSAPoint
    Dim p As CSAPoint
    p.X = x: p.Y = y: p.Z = z
    CSA_Point = p
End Function
