Attribute VB_Name = "modCSAStairPlanGeom"
Option Explicit

' Pure 2D Plan View geometry builder (zero ActiveX dependency).
' Generates structural/architectural plan entities from manual frmCSAStair inputs
' for Single Flight, Two Flight (U-stair), and Three Flight stairs.

Public Type CSAPlanLine
    x1 As Double
    y1 As Double
    x2 As Double
    y2 As Double
    layerName As String
End Type

Public Type CSAPlanRect
    x1 As Double
    y1 As Double
    x2 As Double
    y2 As Double
    layerName As String
    hatched As Boolean
End Type

Public Type CSAPlanCircle
    cx As Double
    cy As Double
    radius As Double
    layerName As String
End Type

Public Type CSAPlanText
    x As Double
    y As Double
    height As Double
    caption As String
    layerName As String
    centered As Boolean
End Type

Public Type CSAPlanDim
    x1 As Double
    y1 As Double
    x2 As Double
    y2 As Double
    locX As Double
    locY As Double
    angleRad As Double
    layerName As String
End Type

Public Type CSAPlanCutSym
    x As Double
    y As Double
    mark As String
    layerName As String
End Type

Public Type CSAPlanModel
    lines() As CSAPlanLine
    lineCount As Long
    rects() As CSAPlanRect
    rectCount As Long
    circles() As CSAPlanCircle
    circleCount As Long
    texts() As CSAPlanText
    textCount As Long
    dims() As CSAPlanDim
    dimCount As Long
    cutSyms() As CSAPlanCutSym
    cutSymCount As Long
    minX As Double
    minY As Double
    maxX As Double
    maxY As Double
End Type

Private Const PI_HALF As Double = 1.5707963267949

Public Sub CSA_BuildPlanModel(ByRef v As CSAStairInput, ByRef m As CSAPlanModel)
    Dim x0 As Double, y0 As Double, supW As Double, landW As Double, uLand As Double
    Dim run1 As Double, run2 As Double, run3 As Double, maxRun As Double
    Dim gap As Double, totalH As Double, totalW As Double
    Dim xU As Double, xF As Double, xL As Double, xR As Double
    Dim yF2Bot As Double, yTop As Double, cutY As Double
    Dim i As Long, posX As Double, posY As Double
    Dim dir1 As String, dir2 As String, mark As String, titleText As String

    ResetModel m
    x0 = v.InsertX
    y0 = v.InsertY
    supW = IIf(v.SupportWidth > 0#, v.SupportWidth, 0#)
    landW = IIf(v.Landing > 0#, v.Landing, 1200#)
    uLand = IIf(v.UpperLanding > 0#, v.UpperLanding, 0#)
    gap = IIf(v.WellGap > 0#, v.WellGap, 0#)
    mark = Trim$(v.SectionMark)
    If Len(mark) = 0 Then mark = "A"
    dir1 = IIf(UCase$(Trim$(v.StartDirection)) = "DN", "DN", "UP")
    dir2 = IIf(dir1 = "UP", "DN", "UP")

    run1 = v.Flight1Risers * v.Tread
    run2 = v.Flight2Risers * v.Tread
    run3 = v.Flight3Risers * v.Tread

    If v.StairType = CSA_TYPE_SINGLE_FLIGHT Then
        totalH = v.Width
        xF = x0 + supW
        xL = xF + run1
        xR = xL + uLand
        totalW = supW + run1 + uLand + supW

        If supW > 0# Then
            AddRect m, x0, y0, xF, y0 + totalH, CSA_LAYER_PLAN, True
            AddRect m, xR, y0, xR + supW, y0 + totalH, CSA_LAYER_PLAN, True
        End If
        AddRect m, xF, y0, xL, y0 + totalH, CSA_LAYER_PLAN, False
        For i = 1 To v.Flight1Risers - 1
            posX = xF + i * v.Tread
            AddLine m, posX, y0, posX, y0 + totalH, CSA_LAYER_PLAN
        Next i
        If uLand > 0# Then
            AddRect m, xL, y0, xR, y0 + totalH, CSA_LAYER_PLAN, False
        End If

        AddZigzagBreakV m, xF + run1 * 0.5, y0, y0 + totalH, CSA_LAYER_CUT
        AddWalkingArrowH m, xF + 120#, xL - 120#, y0 + totalH * 0.5, True, dir1

        cutY = y0 + totalH * 0.5
        AddSectionCutH m, x0 - 400#, x0 + totalW + 400#, cutY, mark

        If v.DrawDimensions Then
            AddDimH m, xF, xL, y0 + totalH + 350#
            If uLand > 0# Then AddDimH m, xL, xR, y0 + totalH + 350#
            AddDimH m, xF, xR, y0 + totalH + 700#
            AddDimV m, x0 - 350#, y0, y0 + totalH
        End If

    ElseIf v.StairType = CSA_TYPE_THREE_FLIGHT Then
        maxRun = IIf(run1 >= run3, run1, run3)
        If gap < run2 Then gap = run2
        totalH = 2# * v.Width + gap
        yF2Bot = y0 + v.Width
        yTop = y0 + totalH
        xU = x0 + supW
        xF = xU + uLand
        xL = xF + maxRun
        xR = xL + landW
        totalW = supW + uLand + maxRun + landW + supW

        If supW > 0# Then
            AddRect m, x0, y0, xU, yTop, CSA_LAYER_PLAN, True
            AddRect m, xR, y0, xR + supW, yTop, CSA_LAYER_PLAN, True
        End If
        If uLand > 0# Then
            AddRect m, xU, y0, xF, yTop, CSA_LAYER_PLAN, False
        End If

        ' Flight 1 (bottom)
        AddRect m, xF, y0, xL, yF2Bot, CSA_LAYER_PLAN, False
        For i = 1 To v.Flight1Risers - 1
            posX = xF + i * v.Tread
            If posX < xL Then AddLine m, posX, y0, posX, yF2Bot, CSA_LAYER_PLAN
        Next i

        ' Landing 1 (bottom-right), Flight 2 (middle vertical), Landing 2 (top-right)
        AddRect m, xL, y0, xR, yF2Bot, CSA_LAYER_PLAN, False
        AddRect m, xL, yF2Bot, xR, yF2Bot + gap, CSA_LAYER_PLAN, False
        For i = 1 To v.Flight2Risers - 1
            posY = yF2Bot + i * v.Tread
            If posY < yF2Bot + gap Then AddLine m, xL, posY, xR, posY, CSA_LAYER_PLAN
        Next i
        AddRect m, xL, yF2Bot + gap, xR, yTop, CSA_LAYER_PLAN, False

        ' Flight 3 (top)
        AddRect m, xF, yF2Bot + gap, xL, yTop, CSA_LAYER_PLAN, False
        For i = 1 To v.Flight3Risers - 1
            posX = xL - i * v.Tread
            If posX > xF Then AddLine m, posX, yF2Bot + gap, posX, yTop, CSA_LAYER_PLAN
        Next i

        AddZigzagBreakV m, xF + maxRun * 0.5, y0, yF2Bot, CSA_LAYER_CUT
        AddWalkingArrowH m, xF + 120#, xL - 120#, y0 + v.Width * 0.5, True, dir1
        AddWalkingArrowV m, xL + landW * 0.5, yF2Bot + 80#, yF2Bot + gap - 80#, True, ""
        AddWalkingArrowH m, xL - 120#, xF + 120#, yF2Bot + gap + v.Width * 0.5, False, dir2

        cutY = y0 + v.Width * 0.5
        AddSectionCutH m, x0 - 400#, x0 + totalW + 400#, cutY, mark

        If v.DrawDimensions Then
            If uLand > 0# Then AddDimH m, xU, xF, yTop + 350#
            AddDimH m, xF, xL, yTop + 350#
            AddDimH m, xL, xR, yTop + 350#
            AddDimH m, xU, xR, yTop + 700#
            AddDimV m, x0 - 350#, y0, yF2Bot
            If gap > 0# Then AddDimV m, x0 - 350#, yF2Bot, yF2Bot + gap
            AddDimV m, x0 - 350#, yF2Bot + gap, yTop
            AddDimV m, x0 - 700#, y0, yTop
        End If

    Else
        ' Two Flight U-Stair (With Landing)
        maxRun = IIf(run1 >= run2, run1, run2)
        totalH = 2# * v.Width + gap
        yF2Bot = y0 + v.Width + gap
        yTop = y0 + totalH
        xU = x0 + supW
        xF = xU + uLand
        xL = xF + maxRun
        xR = xL + landW
        totalW = supW + uLand + maxRun + landW + supW

        If supW > 0# Then
            AddRect m, x0, y0, xU, yTop, CSA_LAYER_PLAN, True
            AddRect m, xR, y0, xR + supW, yTop, CSA_LAYER_PLAN, True
        End If
        If uLand > 0# Then
            AddRect m, xU, y0, xF, yTop, CSA_LAYER_PLAN, False
        End If

        ' Lower flight (flight 1, bottom band)
        AddRect m, xF, y0, xL, y0 + v.Width, CSA_LAYER_PLAN, False
        For i = 1 To v.Flight1Risers - 1
            posX = xF + i * v.Tread
            If posX < xL Then AddLine m, posX, y0, posX, y0 + v.Width, CSA_LAYER_PLAN
        Next i

        ' Upper flight (flight 2, top band)
        AddRect m, xF, yF2Bot, xL, yTop, CSA_LAYER_PLAN, False
        For i = 1 To v.Flight2Risers - 1
            posX = xL - i * v.Tread
            If posX > xF Then AddLine m, posX, yF2Bot, posX, yTop, CSA_LAYER_PLAN
        Next i

        ' Intermediate landing (right)
        AddRect m, xL, y0, xR, yTop, CSA_LAYER_PLAN, False

        AddZigzagBreakV m, xF + maxRun * 0.5, y0, y0 + v.Width, CSA_LAYER_CUT
        AddWalkingArrowH m, xF + 120#, xL - 120#, y0 + v.Width * 0.5, True, dir1
        AddWalkingArrowH m, xL - 120#, xF + 120#, yF2Bot + v.Width * 0.5, False, dir2

        cutY = y0 + v.Width * 0.5
        AddSectionCutH m, x0 - 400#, x0 + totalW + 400#, cutY, mark

        If v.DrawDimensions Then
            If uLand > 0# Then AddDimH m, xU, xF, yTop + 350#
            AddDimH m, xF, xL, yTop + 350#
            AddDimH m, xL, xR, yTop + 350#
            AddDimH m, xU, xR, yTop + 700#
            AddDimV m, x0 - 350#, y0, y0 + v.Width
            If gap > 0# Then AddDimV m, x0 - 350#, y0 + v.Width, yF2Bot
            AddDimV m, x0 - 350#, yF2Bot, yTop
            AddDimV m, x0 - 700#, y0, yTop
        End If
    End If

    ' Plan title centered below stair
    titleText = "PLAN VIEW - " & Trim$(v.StairName)
    AddText m, x0 + totalW * 0.5, y0 - 420#, 180#, titleText, CSA_LAYER_TEXT, True

    m.minX = x0 - 750#
    m.minY = y0 - 600#
    m.maxX = x0 + totalW + 450#
    m.maxY = y0 + totalH + 850#
End Sub

Private Sub ResetModel(ByRef m As CSAPlanModel)
    m.lineCount = 0
    m.rectCount = 0
    m.circleCount = 0
    m.textCount = 0
    m.dimCount = 0
    m.cutSymCount = 0
    Erase m.lines
    Erase m.rects
    Erase m.circles
    Erase m.texts
    Erase m.dims
    Erase m.cutSyms
End Sub

Private Sub AddLine(ByRef m As CSAPlanModel, ByVal x1 As Double, ByVal y1 As Double, _
                    ByVal x2 As Double, ByVal y2 As Double, ByVal layerName As String)
    ReDim Preserve m.lines(0 To m.lineCount)
    m.lines(m.lineCount).x1 = x1
    m.lines(m.lineCount).y1 = y1
    m.lines(m.lineCount).x2 = x2
    m.lines(m.lineCount).y2 = y2
    m.lines(m.lineCount).layerName = layerName
    m.lineCount = m.lineCount + 1
End Sub

Private Sub AddRect(ByRef m As CSAPlanModel, ByVal x1 As Double, ByVal y1 As Double, _
                    ByVal x2 As Double, ByVal y2 As Double, ByVal layerName As String, _
                    ByVal hatched As Boolean)
    Dim spacing As Double, d As Double, w As Double, h As Double
    Dim sx1 As Double, sy1 As Double, sx2 As Double, sy2 As Double
    ReDim Preserve m.rects(0 To m.rectCount)
    m.rects(m.rectCount).x1 = x1
    m.rects(m.rectCount).y1 = y1
    m.rects(m.rectCount).x2 = x2
    m.rects(m.rectCount).y2 = y2
    m.rects(m.rectCount).layerName = layerName
    m.rects(m.rectCount).hatched = hatched
    m.rectCount = m.rectCount + 1

    ' Generate lightweight 45-degree diagonal hatch strokes for support walls/beams
    If hatched Then
        w = x2 - x1
        h = y2 - y1
        spacing = 120#
        If w > 0# And h > 0# Then
            d = spacing
            Do While d < w + h
                sx1 = x1 + IIf(d <= h, 0#, d - h)
                sy1 = y1 + IIf(d <= h, d, h)
                sx2 = x1 + IIf(d <= w, d, w)
                sy2 = y1 + IIf(d <= w, 0#, d - w)
                AddLine m, sx1, sy1, sx2, sy2, CSA_LAYER_HATCH
                d = d + spacing
            Loop
        End If
    End If
End Sub

Private Sub AddCircle(ByRef m As CSAPlanModel, ByVal cx As Double, ByVal cy As Double, _
                      ByVal radius As Double, ByVal layerName As String)
    ReDim Preserve m.circles(0 To m.circleCount)
    m.circles(m.circleCount).cx = cx
    m.circles(m.circleCount).cy = cy
    m.circles(m.circleCount).radius = radius
    m.circles(m.circleCount).layerName = layerName
    m.circleCount = m.circleCount + 1
End Sub

Private Sub AddText(ByRef m As CSAPlanModel, ByVal x As Double, ByVal y As Double, _
                    ByVal height As Double, ByVal caption As String, _
                    ByVal layerName As String, ByVal centered As Boolean)
    ReDim Preserve m.texts(0 To m.textCount)
    m.texts(m.textCount).x = x
    m.texts(m.textCount).y = y
    m.texts(m.textCount).height = height
    m.texts(m.textCount).caption = caption
    m.texts(m.textCount).layerName = layerName
    m.texts(m.textCount).centered = centered
    m.textCount = m.textCount + 1
End Sub

Private Sub AddDimH(ByRef m As CSAPlanModel, ByVal x1 As Double, ByVal x2 As Double, ByVal locY As Double)
    If Abs(x2 - x1) < 1# Then Exit Sub
    ReDim Preserve m.dims(0 To m.dimCount)
    m.dims(m.dimCount).x1 = x1: m.dims(m.dimCount).y1 = locY - 300#
    m.dims(m.dimCount).x2 = x2: m.dims(m.dimCount).y2 = locY - 300#
    m.dims(m.dimCount).locX = (x1 + x2) * 0.5: m.dims(m.dimCount).locY = locY
    m.dims(m.dimCount).angleRad = 0#
    m.dims(m.dimCount).layerName = CSA_LAYER_DIM
    m.dimCount = m.dimCount + 1
End Sub

Private Sub AddDimV(ByRef m As CSAPlanModel, ByVal locX As Double, ByVal y1 As Double, ByVal y2 As Double)
    If Abs(y2 - y1) < 1# Then Exit Sub
    ReDim Preserve m.dims(0 To m.dimCount)
    m.dims(m.dimCount).x1 = locX + 300#: m.dims(m.dimCount).y1 = y1
    m.dims(m.dimCount).x2 = locX + 300#: m.dims(m.dimCount).y2 = y2
    m.dims(m.dimCount).locX = locX: m.dims(m.dimCount).locY = (y1 + y2) * 0.5
    m.dims(m.dimCount).angleRad = PI_HALF
    m.dims(m.dimCount).layerName = CSA_LAYER_DIM
    m.dimCount = m.dimCount + 1
End Sub

Private Sub AddZigzagBreakV(ByRef m As CSAPlanModel, ByVal cx As Double, _
                            ByVal yBot As Double, ByVal yTop As Double, _
                            ByVal layerName As String)
    Dim midY As Double, zig As Double, ext As Double
    midY = (yBot + yTop) * 0.5
    zig = 90#
    ext = 80#
    AddLine m, cx - 120#, yBot - ext, cx - 35#, midY - 60#, layerName
    AddLine m, cx - 35#, midY - 60#, cx - 35# - zig, midY, layerName
    AddLine m, cx - 35# - zig, midY, cx + 35# + zig, midY, layerName
    AddLine m, cx + 35# + zig, midY, cx + 35#, midY + 60#, layerName
    AddLine m, cx + 35#, midY + 60#, cx + 120#, yTop + ext, layerName
End Sub

Private Sub AddWalkingArrowH(ByRef m As CSAPlanModel, ByVal xStart As Double, _
                             ByVal xEnd As Double, ByVal y As Double, _
                             ByVal pointingRight As Boolean, ByVal label As String)
    Dim s As Double, headLen As Double, headW As Double
    s = IIf(pointingRight, -1#, 1#)
    headLen = 140#
    headW = 65#
    AddCircle m, xStart, y, 40#, CSA_LAYER_SYMBOL
    AddLine m, xStart, y, xEnd, y, CSA_LAYER_SYMBOL
    AddLine m, xEnd, y, xEnd + s * headLen, y + headW, CSA_LAYER_SYMBOL
    AddLine m, xEnd, y, xEnd + s * headLen, y - headW, CSA_LAYER_SYMBOL
    If Len(label) > 0 Then
        AddText m, (xStart + xEnd) * 0.5, y + 80#, 120#, label, CSA_LAYER_TEXT, True
    End If
End Sub

Private Sub AddWalkingArrowV(ByRef m As CSAPlanModel, ByVal x As Double, _
                             ByVal yStart As Double, ByVal yEnd As Double, _
                             ByVal pointingUp As Boolean, ByVal label As String)
    Dim s As Double, headLen As Double, headW As Double
    If Abs(yEnd - yStart) < 120# Then Exit Sub
    s = IIf(pointingUp, -1#, 1#)
    headLen = 120#
    headW = 55#
    AddLine m, x, yStart, x, yEnd, CSA_LAYER_SYMBOL
    AddLine m, x, yEnd, x - headW, yEnd + s * headLen, CSA_LAYER_SYMBOL
    AddLine m, x, yEnd, x + headW, yEnd + s * headLen, CSA_LAYER_SYMBOL
    If Len(label) > 0 Then
        AddText m, x + 90#, (yStart + yEnd) * 0.5, 110#, label, CSA_LAYER_TEXT, False
    End If
End Sub

Private Sub AddSectionCutH(ByRef m As CSAPlanModel, ByVal xLeft As Double, _
                           ByVal xRight As Double, ByVal y As Double, _
                           ByVal mark As String)
    AddLine m, xLeft, y, xRight, y, CSA_LAYER_SYMBOL
    ReDim Preserve m.cutSyms(0 To m.cutSymCount + 1)
    m.cutSyms(m.cutSymCount).x = xLeft
    m.cutSyms(m.cutSymCount).y = y
    m.cutSyms(m.cutSymCount).mark = mark
    m.cutSyms(m.cutSymCount).layerName = CSA_LAYER_SYMBOL
    m.cutSyms(m.cutSymCount + 1).x = xRight
    m.cutSyms(m.cutSymCount + 1).y = y
    m.cutSyms(m.cutSymCount + 1).mark = mark
    m.cutSyms(m.cutSymCount + 1).layerName = CSA_LAYER_SYMBOL
    m.cutSymCount = m.cutSymCount + 2
End Sub
