Attribute VB_Name = "modCSAStairFormPreview"
Option Explicit

' Pure Win32 GDI vector preview renderer for frmCSAStair Image controls.
' Converts offscreen HBITMAP to IPictureDisp via modCSAStairWinApi so MSForms
' handles repaints, MultiPage switching and memory cleanup automatically.

Private Const CLR_BG As Long = &HFFFFFF         ' White
Private Const CLR_GRID As Long = &HF9F3EE       ' Subtle blueprint grid (BGR)
Private Const CLR_BORDER As Long = &HDCCABE     ' Light steel border
Private Const CLR_TITLE As Long = &H82491B      ' CSA Navy (#1B4982)
Private Const CLR_CONCRETE As Long = &H553A26   ' Dark slate outline
Private Const CLR_FILL_CONC As Long = &HF0E8E0  ' Soft concrete fill
Private Const CLR_FILL_LAND As Long = &HF5F0EC  ' Soft landing fill
Private Const CLR_REBAR As Long = &H2222CC      ' Rebar crimson (#CC2222)
Private Const CLR_DIM As Long = &H99551B        ' Dimension blue
Private Const CLR_TEXT As Long = &H403020       ' Dark charcoal text
Private Const CLR_GUIDE As Long = &HC0B4A8      ' Elevation guide grey

Public Function CSA_RenderStairIconBitmap(ByVal widthPx As Long, ByVal heightPx As Long) As Object
    Dim canvas As CSA_GdiCanvas
    Dim pad As Long, stepW As Long, stepH As Long, i As Long
    Dim x1 As Long, y1 As Long, x2 As Long, y2 As Long
    On Error GoTo Failed
    CSA_BeginCanvas widthPx, heightPx, canvas
    CSA_CanvasFillRect canvas, 0, 0, widthPx, heightPx, CLR_BG
    pad = 4
    stepW = (widthPx - 2 * pad) \ 4
    stepH = (heightPx - 2 * pad) \ 4
    If stepW < 4 Then stepW = 4
    If stepH < 4 Then stepH = 4
    ' Draw stylized stepped stair silhouette in CSA navy
    For i = 0 To 2
        x1 = pad + i * stepW
        y2 = heightPx - pad - i * stepH
        y1 = y2 - stepH
        x2 = widthPx - pad
        CSA_CanvasFillRect canvas, x1, y1, x2, y2, CLR_TITLE
    Next i
    ' Top handrail accent line
    CSA_CanvasLine canvas, pad, heightPx - pad - stepH - 5, widthPx - pad - stepW, pad + 3, CLR_DIM, 2
    Set CSA_RenderStairIconBitmap = CSA_EndCanvasToPicture(canvas)
    Exit Function
Failed:
    CSA_DiscardCanvas canvas
End Function

Public Function CSA_RenderSectionBitmap(ByRef v As CSAStairInput, _
                                        ByVal widthPx As Long, ByVal heightPx As Long) As Object
    Dim canvas As CSA_GdiCanvas
    Dim msg As String, mark As String
    Dim padL As Long, padR As Long, padT As Long, padB As Long
    Dim drawW As Double, drawH As Double
    Dim run1 As Double, run2 As Double, maxRun As Double
    Dim totalW As Double, totalH As Double, scalePx As Double
    Dim ox As Double, oy As Double
    Dim i As Long, x1 As Long, y1 As Long, x2 As Long, y2 As Long
    Dim midElev As Double, midH As Double
    Dim supW As Double, landW As Double, uLandW As Double

    On Error GoTo Failed
    CSA_BeginCanvas widthPx, heightPx, canvas
    DrawGridBackground canvas, widthPx, heightPx

    mark = Trim$(v.SectionMark)
    If Len(mark) = 0 Then mark = "A"
    DrawPanelTitle canvas, widthPx, CSA_Tr("PV_SEC") & " " & mark & " - " & mark

    If Not CSA_ValidateInput(v, msg) Then
        CSA_CanvasText canvas, widthPx \ 2, heightPx \ 2 - 8, msg, CLR_REBAR, 13, True, CSA_ALIGN_CENTER
        Set CSA_RenderSectionBitmap = CSA_EndCanvasToPicture(canvas)
        Exit Function
    End If

    padL = 78: padR = 72: padT = 42: padB = 56
    drawW = widthPx - padL - padR
    drawH = heightPx - padT - padB
    If drawW < 40 Then drawW = 40
    If drawH < 40 Then drawH = 40

    supW = IIf(v.SupportWidth > 0#, v.SupportWidth, 200#)
    landW = IIf(v.Landing > 0#, v.Landing, 1200#)
    uLandW = IIf(v.UpperLanding > 0#, v.UpperLanding, landW)
    run1 = v.Flight1Risers * v.Tread
    run2 = v.Flight2Risers * v.Tread
    maxRun = IIf(run1 >= run2, run1, run2)

    If v.StairType = CSA_TYPE_SINGLE_FLIGHT Then
        totalW = supW + run1 + uLandW + supW
    Else
        totalW = supW + uLandW + maxRun + landW + supW
    End If
    totalH = v.FloorHeight + v.Slab + 450#
    scalePx = drawW / totalW
    If (drawH / totalH) < scalePx Then scalePx = drawH / totalH

    ox = padL + (drawW - totalW * scalePx) * 0.5
    oy = heightPx - padB - (v.Slab + 120#) * scalePx

    ' Elevation horizontal guides and level markers
    DrawElevationGuide canvas, ox, oy, totalW * scalePx, v.BottomElevation, 0#, scalePx
    If v.StairType <> CSA_TYPE_SINGLE_FLIGHT Then
        midH = v.Flight1Risers * v.Riser
        midElev = v.BottomElevation + midH / 1000#
        DrawElevationGuide canvas, ox, oy, totalW * scalePx, midElev, midH, scalePx
    End If
    DrawElevationGuide canvas, ox, oy, totalW * scalePx, v.TopElevation, v.FloorHeight, scalePx

    If v.StairType = CSA_TYPE_SINGLE_FLIGHT Then
        DrawSingleFlightSection canvas, v, ox, oy, scalePx, supW, run1, uLandW
    Else
        DrawFoldedTwoFlightSection canvas, v, ox, oy, scalePx, supW, uLandW, maxRun, landW
    End If

    ' Dimensions when enabled
    If v.DrawDimensions Then
        Dim dimY As Long, dimY2 As Long, dimX As Long
        dimY = CLng(oy + (v.Slab + 160#) * scalePx) + 14
        If dimY > heightPx - 34 Then dimY = heightPx - 34
        dimY2 = dimY + 18
        If dimY2 > heightPx - 14 Then dimY2 = heightPx - 14
        dimX = CLng(ox + totalW * scalePx) + 26
        If dimX > widthPx - 24 Then dimX = widthPx - 24

        If v.StairType = CSA_TYPE_SINGLE_FLIGHT Then
            DrawDimH canvas, CLng(ox + supW * scalePx), CLng(ox + (supW + run1) * scalePx), dimY, _
                     Format$(run1, "0") & " (" & CStr(v.Flight1Risers) & "T)"
            DrawDimH canvas, CLng(ox + (supW + run1) * scalePx), CLng(ox + (supW + run1 + uLandW) * scalePx), dimY, _
                     Format$(uLandW, "0")
        Else
            DrawDimH canvas, CLng(ox + supW * scalePx), CLng(ox + (supW + uLandW) * scalePx), dimY, _
                     Format$(uLandW, "0")
            DrawDimH canvas, CLng(ox + (supW + uLandW) * scalePx), CLng(ox + (supW + uLandW + maxRun) * scalePx), dimY, _
                     Format$(maxRun, "0") & " (" & CStr(v.Flight1Risers) & "T)"
            DrawDimH canvas, CLng(ox + (supW + uLandW + maxRun) * scalePx), CLng(ox + (supW + uLandW + maxRun + landW) * scalePx), dimY, _
                     Format$(landW, "0")
        End If
        DrawDimH canvas, CLng(ox + supW * scalePx), CLng(ox + (totalW - supW) * scalePx), dimY2, _
                 Format$(totalW - 2# * supW, "0")

        ' Vertical total height dimension
        DrawDimV canvas, dimX, CLng(oy - v.FloorHeight * scalePx), CLng(oy), Format$(v.FloorHeight, "0")

        ' Riser callout labels
        If v.StairType <> CSA_TYPE_SINGLE_FLIGHT Then
            x1 = CLng(ox + (totalW - supW) * scalePx) - 4
            y1 = CLng(oy - (v.Flight1Risers * v.Riser) * 0.5 * scalePx) - 6
            CSA_CanvasText canvas, x1, y1, CStr(v.Flight1Risers) & " " & CSA_Tr("PV_RISERS"), CLR_DIM, 11, True, CSA_ALIGN_RIGHT
            y2 = CLng(oy - (v.Flight1Risers * v.Riser + v.Flight2Risers * v.Riser * 0.5) * scalePx) - 6
            CSA_CanvasText canvas, x1, y2, CStr(v.Flight2Risers) & " " & CSA_Tr("PV_RISERS"), CLR_DIM, 11, True, CSA_ALIGN_RIGHT
        End If
    End If

    Set CSA_RenderSectionBitmap = CSA_EndCanvasToPicture(canvas)
    Exit Function
Failed:
    CSA_DiscardCanvas canvas
End Function

Public Function CSA_RenderPlanBitmap(ByRef v As CSAStairInput, _
                                     ByVal widthPx As Long, ByVal heightPx As Long) As Object
    Dim canvas As CSA_GdiCanvas
    Dim msg As String, mark As String
    Dim padL As Long, padR As Long, padT As Long, padB As Long
    Dim drawW As Double, drawH As Double
    Dim run1 As Double, run2 As Double, run3 As Double, maxRun As Double
    Dim supW As Double, landW As Double, uLandW As Double, gap As Double
    Dim totalW As Double, totalH As Double, scalePx As Double
    Dim ox As Double, oy As Double
    Dim i As Long, xPx As Long, yPx As Long, yTop As Long, yBot As Long
    Dim dir1 As String, dir2 As String

    On Error GoTo Failed
    CSA_BeginCanvas widthPx, heightPx, canvas
    DrawGridBackground canvas, widthPx, heightPx
    DrawPanelTitle canvas, widthPx, CSA_Tr("PV_PLAN")

    If Not CSA_ValidateInput(v, msg) Then
        CSA_CanvasText canvas, widthPx \ 2, heightPx \ 2 - 8, msg, CLR_REBAR, 13, True, CSA_ALIGN_CENTER
        Set CSA_RenderPlanBitmap = CSA_EndCanvasToPicture(canvas)
        Exit Function
    End If

    mark = Trim$(v.SectionMark)
    If Len(mark) = 0 Then mark = "A"
    If UCase$(Trim$(v.StartDirection)) = "DN" Then
        dir1 = CSA_Tr("DIR_DN"): dir2 = CSA_Tr("DIR_UP")
    Else
        dir1 = CSA_Tr("DIR_UP"): dir2 = CSA_Tr("DIR_DN")
    End If

    padL = 62: padR = 46: padT = 66: padB = 34
    drawW = widthPx - padL - padR
    drawH = heightPx - padT - padB
    If drawW < 40 Then drawW = 40
    If drawH < 40 Then drawH = 40

    supW = IIf(v.SupportWidth > 0#, v.SupportWidth, 200#)
    landW = IIf(v.Landing > 0#, v.Landing, 1200#)
    uLandW = IIf(v.UpperLanding > 0#, v.UpperLanding, 0#)
    gap = v.WellGap
    run1 = v.Flight1Risers * v.Tread
    run2 = v.Flight2Risers * v.Tread
    run3 = v.Flight3Risers * v.Tread

    If v.StairType = CSA_TYPE_SINGLE_FLIGHT Then
        maxRun = run1
        totalW = supW + run1 + uLandW + supW
        totalH = v.Width
    ElseIf v.StairType = CSA_TYPE_THREE_FLIGHT Then
        maxRun = IIf(run1 >= run3, run1, run3)
        If gap < run2 Then gap = run2
        totalW = supW + uLandW + maxRun + landW + supW
        totalH = 2# * v.Width + gap
    Else
        maxRun = IIf(run1 >= run2, run1, run2)
        totalW = supW + uLandW + maxRun + landW + supW
        totalH = 2# * v.Width + gap
    End If

    scalePx = drawW / totalW
    If (drawH / totalH) < scalePx Then scalePx = drawH / totalH

    ox = padL + (drawW - totalW * scalePx) * 0.5
    oy = padT + (drawH - totalH * scalePx) * 0.5

    ' Left and right support walls/beams
    CSA_CanvasRect canvas, CLng(ox), CLng(oy), CLng(ox + supW * scalePx), CLng(oy + totalH * scalePx), _
                   CLR_CONCRETE, 2, CLR_FILL_CONC
    CSA_CanvasRect canvas, CLng(ox + (totalW - supW) * scalePx), CLng(oy), _
                   CLng(ox + totalW * scalePx), CLng(oy + totalH * scalePx), _
                   CLR_CONCRETE, 2, CLR_FILL_CONC

    If v.StairType = CSA_TYPE_SINGLE_FLIGHT Then
        Dim fStart As Double
        fStart = ox + supW * scalePx
        CSA_CanvasRect canvas, CLng(fStart), CLng(oy), CLng(fStart + run1 * scalePx), CLng(oy + v.Width * scalePx), _
                       CLR_CONCRETE, 2, CLR_BG
        For i = 1 To v.Flight1Risers - 1
            xPx = CLng(fStart + i * v.Tread * scalePx)
            CSA_CanvasLine canvas, xPx, CLng(oy), xPx, CLng(oy + v.Width * scalePx), CLR_CONCRETE, 1
        Next i
        If uLandW > 0# Then
            CSA_CanvasRect canvas, CLng(fStart + run1 * scalePx), CLng(oy), _
                           CLng(fStart + (run1 + uLandW) * scalePx), CLng(oy + v.Width * scalePx), _
                           CLR_CONCRETE, 2, CLR_FILL_LAND
        End If
        DrawArrowH canvas, CLng(fStart + 10), CLng(fStart + run1 * scalePx - 10), CLng(oy + v.Width * 0.5 * scalePx), True, dir1
    Else
        Dim xU As Double, xF As Double, xL As Double, topFlightCount As Long
        xU = ox + supW * scalePx
        xF = xU + uLandW * scalePx
        xL = xF + maxRun * scalePx

        ' Upper landing (left) if positive
        If uLandW > 0# Then
            CSA_CanvasRect canvas, CLng(xU), CLng(oy), CLng(xF), CLng(oy + totalH * scalePx), _
                           CLR_CONCRETE, 2, CLR_FILL_LAND
        End If

        ' Right landing or Three-Flight landings + middle flight
        If v.StairType = CSA_TYPE_THREE_FLIGHT Then
            CSA_CanvasRect canvas, CLng(xL), CLng(oy), CLng(xL + landW * scalePx), CLng(oy + v.Width * scalePx), _
                           CLR_CONCRETE, 2, CLR_FILL_LAND
            CSA_CanvasRect canvas, CLng(xL), CLng(oy + v.Width * scalePx), CLng(xL + landW * scalePx), CLng(oy + (v.Width + gap) * scalePx), _
                           CLR_CONCRETE, 2, CLR_BG
            For i = 1 To v.Flight2Risers - 1
                yPx = CLng(oy + v.Width * scalePx + i * v.Tread * scalePx)
                If yPx < CLng(oy + (v.Width + gap) * scalePx) Then
                    CSA_CanvasLine canvas, CLng(xL), yPx, CLng(xL + landW * scalePx), yPx, CLR_CONCRETE, 1
                End If
            Next i
            CSA_CanvasRect canvas, CLng(xL), CLng(oy + (v.Width + gap) * scalePx), CLng(xL + landW * scalePx), CLng(oy + totalH * scalePx), _
                           CLR_CONCRETE, 2, CLR_FILL_LAND
            topFlightCount = v.Flight3Risers
        Else
            CSA_CanvasRect canvas, CLng(xL), CLng(oy), CLng(xL + landW * scalePx), CLng(oy + totalH * scalePx), _
                           CLR_CONCRETE, 2, CLR_FILL_LAND
            topFlightCount = v.Flight2Risers
        End If

        ' Upper flight (top band in plan)
        yTop = CLng(oy)
        yBot = CLng(oy + v.Width * scalePx)
        CSA_CanvasRect canvas, CLng(xF), yTop, CLng(xL), yBot, CLR_CONCRETE, 2, CLR_BG
        For i = 1 To topFlightCount - 1
            xPx = CLng(xF + i * v.Tread * scalePx)
            If xPx < CLng(xL) Then CSA_CanvasLine canvas, xPx, yTop, xPx, yBot, CLR_CONCRETE, 1
        Next i
        DrawArrowH canvas, CLng(xL - 8), CLng(xF + 8), (yTop + yBot) \ 2, False, dir2

        ' Stairwell gap
        If gap > 0# Then
            CSA_CanvasRect canvas, CLng(xF), yBot, CLng(xL), CLng(oy + (v.Width + gap) * scalePx), _
                           CLR_BORDER, 1, CLR_GRID
        End If

        ' Lower flight (bottom band in plan)
        yTop = CLng(oy + (v.Width + gap) * scalePx)
        yBot = CLng(oy + totalH * scalePx)
        CSA_CanvasRect canvas, CLng(xF), yTop, CLng(xL), yBot, CLR_CONCRETE, 2, CLR_BG
        For i = 1 To v.Flight1Risers - 1
            xPx = CLng(xF + i * v.Tread * scalePx)
            If xPx < CLng(xL) Then CSA_CanvasLine canvas, xPx, yTop, xPx, yBot, CLR_CONCRETE, 1
        Next i
        DrawArrowH canvas, CLng(xF + 8), CLng(xL - 8), (yTop + yBot) \ 2, True, dir1

        ' Section cut line A - A across lower flight
        Dim cutY As Long
        cutY = (yTop + yBot) \ 2
        CSA_CanvasLine canvas, CLng(ox) - 18, cutY, CLng(ox + totalW * scalePx) + 18, cutY, CLR_REBAR, 1, CSA_PEN_DASHDOT
        CSA_CanvasText canvas, CLng(ox) - 22, cutY - 16, mark, CLR_REBAR, 12, True, CSA_ALIGN_RIGHT
        CSA_CanvasText canvas, CLng(ox + totalW * scalePx) + 22, cutY - 16, mark, CLR_REBAR, 12, True, CSA_ALIGN_LEFT
    End If

    ' Plan Dimensions
    If v.DrawDimensions Then
        Dim topDim1 As Long, topDim2 As Long, leftDimX As Long
        topDim1 = CLng(oy) - 14
        topDim2 = topDim1 - 18
        leftDimX = CLng(ox) - 18
        If v.StairType = CSA_TYPE_SINGLE_FLIGHT Then
            DrawDimH canvas, CLng(ox + supW * scalePx), CLng(ox + (supW + run1) * scalePx), topDim1, Format$(run1, "0")
            If uLandW > 0# Then
                DrawDimH canvas, CLng(ox + (supW + run1) * scalePx), CLng(ox + (totalW - supW) * scalePx), topDim1, Format$(uLandW, "0")
            End If
        Else
            If uLandW > 0# Then
                DrawDimH canvas, CLng(ox + supW * scalePx), CLng(ox + (supW + uLandW) * scalePx), topDim1, Format$(uLandW, "0")
            End If
            DrawDimH canvas, CLng(ox + (supW + uLandW) * scalePx), CLng(ox + (supW + uLandW + maxRun) * scalePx), topDim1, Format$(maxRun, "0")
            DrawDimH canvas, CLng(ox + (supW + uLandW + maxRun) * scalePx), CLng(ox + (totalW - supW) * scalePx), topDim1, Format$(landW, "0")
        End If
        DrawDimH canvas, CLng(ox + supW * scalePx), CLng(ox + (totalW - supW) * scalePx), topDim2, Format$(totalW - 2# * supW, "0")
        DrawDimV canvas, leftDimX, CLng(oy), CLng(oy + v.Width * scalePx), Format$(v.Width, "0")
    End If

    Set CSA_RenderPlanBitmap = CSA_EndCanvasToPicture(canvas)
    Exit Function
Failed:
    CSA_DiscardCanvas canvas
End Function

Private Sub DrawSingleFlightSection(ByRef canvas As CSA_GdiCanvas, ByRef v As CSAStairInput, _
                                    ByVal ox As Double, ByVal oy As Double, ByVal s As Double, _
                                    ByVal supW As Double, ByVal run1 As Double, ByVal uLandW As Double)
    Dim i As Long, x0 As Double, y0 As Double, x1 As Long, y1 As Long, x2 As Long, y2 As Long
    Dim topY As Double
    x0 = ox + supW * s
    topY = oy - v.FloorHeight * s

    ' Left & right supports
    CSA_CanvasRect canvas, CLng(ox), CLng(oy - 180# * s), CLng(x0), CLng(oy + v.Slab * s), CLR_CONCRETE, 2, CLR_FILL_CONC
    CSA_CanvasRect canvas, CLng(x0 + (run1 + uLandW) * s), CLng(topY), CLng(x0 + (run1 + uLandW + supW) * s), CLng(topY + (v.Slab + 220#) * s), CLR_CONCRETE, 2, CLR_FILL_CONC

    ' Step profile
    For i = 0 To v.Flight1Risers - 1
        x1 = CLng(x0 + i * v.Tread * s)
        y1 = CLng(oy - i * v.Riser * s)
        y2 = CLng(oy - (i + 1) * v.Riser * s)
        x2 = CLng(x0 + (i + 1) * v.Tread * s)
        CSA_CanvasLine canvas, x1, y1, x1, y2, CLR_CONCRETE, 2
        CSA_CanvasLine canvas, x1, y2, x2, y2, CLR_CONCRETE, 2
    Next i
    ' Upper landing top & soffit
    CSA_CanvasLine canvas, CLng(x0 + run1 * s), CLng(topY), CLng(x0 + (run1 + uLandW) * s), CLng(topY), CLR_CONCRETE, 2
    CSA_CanvasLine canvas, CLng(x0), CLng(oy + v.Slab * s), CLng(x0 + run1 * s), CLng(topY + v.Slab * s), CLR_CONCRETE, 2
    CSA_CanvasLine canvas, CLng(x0 + run1 * s), CLng(topY + v.Slab * s), CLng(x0 + (run1 + uLandW) * s), CLng(topY + v.Slab * s), CLR_CONCRETE, 2

    If v.PreviewRebar Then
        Dim offPx As Long
        offPx = CLng(v.Slab * 0.55 * s)
        If offPx < 3 Then offPx = 3
        CSA_CanvasLine canvas, CLng(ox + supW * 0.4 * s), CLng(oy + offPx), CLng(x0 + run1 * s), CLng(topY + offPx), CLR_REBAR, 2
        CSA_CanvasLine canvas, CLng(x0 + run1 * s), CLng(topY + offPx), CLng(x0 + (run1 + uLandW + supW * 0.6) * s), CLng(topY + offPx), CLR_REBAR, 2
    End If
End Sub

Private Sub DrawFoldedTwoFlightSection(ByRef canvas As CSA_GdiCanvas, ByRef v As CSAStairInput, _
                                       ByVal ox As Double, ByVal oy As Double, ByVal s As Double, _
                                       ByVal supW As Double, ByVal uLandW As Double, _
                                       ByVal maxRun As Double, ByVal landW As Double)
    Dim i As Long, x1 As Long, y1 As Long, x2 As Long, y2 As Long
    Dim xStart As Double, xLand As Double, xRight As Double
    Dim midY As Double, topY As Double
    Dim offPx As Long

    xStart = ox + (supW + uLandW) * s
    xLand = xStart + maxRun * s
    xRight = xLand + landW * s
    midY = oy - (v.Flight1Risers * v.Riser) * s
    topY = oy - v.FloorHeight * s

    ' Support walls at bottom-left, top-left, and mid-right
    CSA_CanvasRect canvas, CLng(ox), CLng(oy - 260# * s), CLng(ox + supW * s), CLng(oy + v.Slab * s), CLR_CONCRETE, 2, CLR_FILL_CONC
    CSA_CanvasRect canvas, CLng(ox), CLng(topY - 260# * s), CLng(ox + supW * s), CLng(topY + v.Slab * s), CLR_CONCRETE, 2, CLR_FILL_CONC
    CSA_CanvasRect canvas, CLng(xRight), CLng(midY), CLng(xRight + supW * s), CLng(oy + v.Slab * s), CLR_CONCRETE, 2, CLR_FILL_CONC

    ' Base slab on left
    CSA_CanvasRect canvas, CLng(ox + supW * s), CLng(oy), CLng(xStart), CLng(oy + v.Slab * s), CLR_CONCRETE, 2, CLR_FILL_LAND

    ' Flight 1 (rising left -> right)
    For i = 0 To v.Flight1Risers - 1
        x1 = CLng(xStart + i * v.Tread * s)
        y1 = CLng(oy - i * v.Riser * s)
        y2 = CLng(oy - (i + 1) * v.Riser * s)
        x2 = CLng(xStart + (i + 1) * v.Tread * s)
        CSA_CanvasLine canvas, x1, y1, x1, y2, CLR_CONCRETE, 2
        CSA_CanvasLine canvas, x1, y2, x2, y2, CLR_CONCRETE, 2
    Next i
    ' Flight 1 soffit
    CSA_CanvasLine canvas, CLng(xStart), CLng(oy + v.Slab * s), CLng(xLand), CLng(midY + v.Slab * s), CLR_CONCRETE, 2

    ' Intermediate landing (right)
    CSA_CanvasRect canvas, CLng(xLand), CLng(midY), CLng(xRight), CLng(midY + v.Slab * s), CLR_CONCRETE, 2, CLR_FILL_LAND

    ' Flight 2 (rising right -> left back to top landing)
    For i = 0 To v.Flight2Risers - 1
        x1 = CLng(xLand - i * v.Tread * s)
        y1 = CLng(midY - i * v.Riser * s)
        y2 = CLng(midY - (i + 1) * v.Riser * s)
        x2 = CLng(xLand - (i + 1) * v.Tread * s)
        CSA_CanvasLine canvas, x1, y1, x1, y2, CLR_CONCRETE, 2
        CSA_CanvasLine canvas, x1, y2, x2, y2, CLR_CONCRETE, 2
    Next i
    ' Flight 2 soffit
    CSA_CanvasLine canvas, CLng(xLand), CLng(midY + v.Slab * s), CLng(xStart), CLng(topY + v.Slab * s), CLR_CONCRETE, 2

    ' Top landing (left)
    CSA_CanvasRect canvas, CLng(ox + supW * s), CLng(topY), CLng(xStart), CLng(topY + v.Slab * s), CLR_CONCRETE, 2, CLR_FILL_LAND

    ' Schematic reinforcement line + transverse dots
    If v.PreviewRebar Then
        offPx = CLng(v.Slab * 0.6 * s)
        If offPx < 3 Then offPx = 3
        ' Flight 1 + mid landing rebar
        CSA_CanvasLine canvas, CLng(ox + supW * 0.4 * s), CLng(oy + offPx), CLng(xStart), CLng(oy + offPx), CLR_REBAR, 2
        CSA_CanvasLine canvas, CLng(xStart), CLng(oy + offPx), CLng(xLand), CLng(midY + offPx), CLR_REBAR, 2
        CSA_CanvasLine canvas, CLng(xLand), CLng(midY + offPx), CLng(xRight + supW * 0.5 * s), CLng(midY + offPx), CLR_REBAR, 2
        ' Flight 2 + top landing rebar
        CSA_CanvasLine canvas, CLng(xLand), CLng(midY + offPx), CLng(xStart), CLng(topY + offPx), CLR_REBAR, 2
        CSA_CanvasLine canvas, CLng(xStart), CLng(topY + offPx), CLng(ox + supW * 0.4 * s), CLng(topY + offPx), CLR_REBAR, 2
        ' Transverse dots along flights
        For i = 1 To 5
            CSA_CanvasCircle canvas, CLng(xStart + (xLand - xStart) * (i / 6#)), _
                             CLng(oy + offPx - (oy - midY) * (i / 6#)), 2, CLR_REBAR, CLR_REBAR
            CSA_CanvasCircle canvas, CLng(xLand - (xLand - xStart) * (i / 6#)), _
                             CLng(midY + offPx - (midY - topY) * (i / 6#)), 2, CLR_REBAR, CLR_REBAR
        Next i
    End If
End Sub

Private Sub DrawGridBackground(ByRef canvas As CSA_GdiCanvas, ByVal w As Long, ByVal h As Long)
    Dim x As Long, y As Long, stepPx As Long
    CSA_CanvasFillRect canvas, 0, 0, w, h, CLR_BG
    stepPx = 18
    For x = stepPx To w - 1 Step stepPx
        CSA_CanvasLine canvas, x, 0, x, h, CLR_GRID, 1
    Next x
    For y = stepPx To h - 1 Step stepPx
        CSA_CanvasLine canvas, 0, y, w, y, CLR_GRID, 1
    Next y
    CSA_CanvasRect canvas, 0, 0, w - 1, h - 1, CLR_BORDER, 1
End Sub

Private Sub DrawPanelTitle(ByRef canvas As CSA_GdiCanvas, ByVal w As Long, ByVal title As String)
    Dim cx As Long
    cx = w \ 2
    CSA_CanvasText canvas, cx, 8, title, CLR_TITLE, 14, True, CSA_ALIGN_CENTER
    CSA_CanvasLine canvas, cx - 54, 25, cx + 54, 25, CLR_TITLE, 2
End Sub

Private Sub DrawElevationGuide(ByRef canvas As CSA_GdiCanvas, ByVal ox As Double, ByVal oy As Double, _
                               ByVal spanPx As Double, ByVal elevM As Double, _
                               ByVal riseMm As Double, ByVal scalePx As Double)
    Dim y As Long, xLeft As Long, label As String
    y = CLng(oy - riseMm * scalePx)
    xLeft = CLng(ox) - 62
    If xLeft < 8 Then xLeft = 8
    CSA_CanvasLine canvas, xLeft, y, CLng(ox + spanPx) + 12, y, CLR_GUIDE, 1, CSA_PEN_DASH
    ' Elevation triangle marker
    CSA_CanvasLine canvas, xLeft + 6, y, xLeft + 1, y - 7, CLR_TEXT, 1
    CSA_CanvasLine canvas, xLeft + 6, y, xLeft + 11, y - 7, CLR_TEXT, 1
    CSA_CanvasLine canvas, xLeft + 1, y - 7, xLeft + 11, y - 7, CLR_TEXT, 1
    If Abs(elevM) < 0.0005 Then
        label = "+/-0.000"
    ElseIf elevM > 0# Then
        label = "+" & Format$(elevM, "0.000")
    Else
        label = Format$(elevM, "0.000")
    End If
    CSA_CanvasText canvas, xLeft + 14, y - 16, label, CLR_TEXT, 11, True, CSA_ALIGN_LEFT
End Sub

Private Sub DrawDimH(ByRef canvas As CSA_GdiCanvas, ByVal x1 As Long, ByVal x2 As Long, _
                     ByVal y As Long, ByVal text As String)
    If Abs(x2 - x1) < 12 Then Exit Sub
    CSA_CanvasLine canvas, x1, y, x2, y, CLR_DIM, 1
    CSA_CanvasLine canvas, x1, y - 4, x1, y + 4, CLR_DIM, 1
    CSA_CanvasLine canvas, x2, y - 4, x2, y + 4, CLR_DIM, 1
    CSA_CanvasText canvas, (x1 + x2) \ 2, y - 13, text, CLR_DIM, 11, False, CSA_ALIGN_CENTER
End Sub

Private Sub DrawDimV(ByRef canvas As CSA_GdiCanvas, ByVal x As Long, ByVal yTop As Long, _
                     ByVal yBot As Long, ByVal text As String)
    If Abs(yBot - yTop) < 12 Then Exit Sub
    CSA_CanvasLine canvas, x, yTop, x, yBot, CLR_DIM, 1
    CSA_CanvasLine canvas, x - 4, yTop, x + 4, yTop, CLR_DIM, 1
    CSA_CanvasLine canvas, x - 4, yBot, x + 4, yBot, CLR_DIM, 1
    CSA_CanvasText canvas, x + 4, (yTop + yBot) \ 2 - 6, text, CLR_DIM, 11, False, CSA_ALIGN_LEFT
End Sub

Private Sub DrawArrowH(ByRef canvas As CSA_GdiCanvas, ByVal xStart As Long, ByVal xEnd As Long, _
                       ByVal y As Long, ByVal pointingRight As Boolean, ByVal label As String)
    Dim dirSign As Long
    CSA_CanvasLine canvas, xStart, y, xEnd, y, CLR_TITLE, 2
    dirSign = IIf(pointingRight, -1, 1)
    CSA_CanvasLine canvas, xEnd, y, xEnd + dirSign * 7, y - 4, CLR_TITLE, 2
    CSA_CanvasLine canvas, xEnd, y, xEnd + dirSign * 7, y + 4, CLR_TITLE, 2
    CSA_CanvasText canvas, (xStart + xEnd) \ 2, y - 15, label, CLR_TITLE, 11, True, CSA_ALIGN_CENTER
End Sub
