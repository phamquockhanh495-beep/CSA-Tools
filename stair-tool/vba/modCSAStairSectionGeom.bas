Attribute VB_Name = "modCSAStairSectionGeom"
Option Explicit

' Pure 2D structural Section View geometry & rebar detailing engine (zero ActiveX).
' Supports both:
'   1. Excel 24-point contract (Cau Thang Tools BY2:CA25 + BJ28:BJ39 + Z23:Z26)
'   2. Parametric structural stair section (Single / Two / Three Flight) with
'      true perpendicular waist thickness, stepped profile, closed concrete outlines,
'      2-layer reinforcement, 30-deg/2d hooks, transverse dots and polyline callouts.

Public Type CSASecPoly
    xs(0 To 127) As Double
    ys(0 To 127) As Double
    ptCount As Long
    closed As Boolean
    layerName As String
End Type

Public Type CSASecLine
    x1 As Double
    y1 As Double
    x2 As Double
    y2 As Double
    layerName As String
End Type

Public Type CSASecCircle
    cx As Double
    cy As Double
    radius As Double
    layerName As String
    filled As Boolean
End Type

Public Type CSASecDim
    kind As String          ' "H", "V", "A"
    x1 As Double
    y1 As Double
    x2 As Double
    y2 As Double
    locX As Double
    locY As Double
    overrideText As String
    layerName As String
End Type

Public Type CSASecLevel
    x As Double
    y As Double
    elevText As String
    layerName As String
End Type

Public Type CSASecBarNote
    x As Double
    y As Double
    markText As String
    barSpecText As String
    rightAligned As Boolean
    layerName As String
End Type

Public Type CSASecText
    x As Double
    y As Double
    height As Double
    caption As String
    layerName As String
    centered As Boolean
End Type

Public Type CSASecCutSym
    x As Double
    y As Double
    mark As String
    layerName As String
    enabled As Boolean
End Type

Public Type CSASectionModel
    polys() As CSASecPoly
    polyCount As Long
    lines() As CSASecLine
    lineCount As Long
    circles() As CSASecCircle
    circleCount As Long
    dims() As CSASecDim
    dimCount As Long
    levels() As CSASecLevel
    levelCount As Long
    notes() As CSASecBarNote
    noteCount As Long
    texts() As CSASecText
    textCount As Long
    cutSym As CSASecCutSym
End Type

Private Const COS_30 As Double = 0.866025403784439
Private Const SIN_30 As Double = 0.5
Private Const FOOT_LIMIT As Double = 200#

Public Sub CSA_BuildSectionModel(ByRef v As CSAStairInput, ByRef m As CSASectionModel)
    ResetSecModel m
    If v.HasExcelCoords And v.ExcelPointCount = 24 Then
        BuildExcel24Section v, m
    ElseIf v.StairType = CSA_TYPE_SINGLE_FLIGHT Then
        BuildParametricSingleSection v, m
    Else
        BuildParametricFoldedSection v, m
    End If
End Sub

Public Function CSA_ParseBar(ByVal barSpec As String, ByRef diamMm As Double, _
                             ByRef spacingMm As Double, ByRef cleanLabel As String) As Boolean
    Dim s As String, idx As Long, dStr As String, spStr As String
    s = UCase$(Replace(Trim$(barSpec), " ", ""))
    If Left$(s, 3) = "%%C" Then s = Mid$(s, 4)
    If Len(s) > 1 Then
        If Left$(s, 1) = "D" Or Left$(s, 1) = "T" Or Left$(s, 1) = "R" Then s = Mid$(s, 2)
    End If
    idx = InStr(1, s, "A")
    If idx = 0 Then idx = InStr(1, s, "@")
    If idx <= 1 Then Exit Function
    dStr = Left$(s, idx - 1)
    spStr = Mid$(s, idx + 1)
    If Not IsNumeric(dStr) Or Not IsNumeric(spStr) Then Exit Function
    diamMm = CDbl(dStr)
    spacingMm = CDbl(spStr)
    If diamMm <= 0# Or spacingMm <= 0# Then Exit Function
    cleanLabel = TrimZero(diamMm) & "a" & TrimZero(spacingMm)
    CSA_ParseBar = True
End Function

Public Function CSA_FormatElevation(ByVal elevM As Double) As String
    If Abs(elevM) < 0.0005 Then
        CSA_FormatElevation = "+0.000"
    ElseIf elevM > 0# Then
        CSA_FormatElevation = "+" & Format$(elevM, "0.000")
    Else
        CSA_FormatElevation = Format$(elevM, "0.000")
    End If
End Function

Public Function CSA_FormatBarNotation(ByVal barSpec As String, ByVal symbolPrefix As String) As String
    Dim d As Double, sp As Double, clean As String, pref As String
    pref = IIf(UCase$(Trim$(symbolPrefix)) = "T", "T", "%%C")
    If CSA_ParseBar(barSpec, d, sp, clean) Then
        CSA_FormatBarNotation = pref & clean
    Else
        CSA_FormatBarNotation = pref & Trim$(barSpec)
    End If
End Function

' =============================================================================
' MODE 1: PARAMETRIC FOLDED TWO/THREE-FLIGHT STRUCTURAL SECTION
' =============================================================================
Private Sub BuildParametricFoldedSection(ByRef v As CSAStairInput, ByRef m As CSASectionModel)
    Dim x0 As Double, y0 As Double
    Dim supW As Double, uLand As Double, landW As Double, downH As Double
    Dim n1 As Long, n2 As Long, run1 As Double, run2 As Double, maxRun As Double
    Dim midRise As Double, topRise As Double, slabT As Double
    Dim soffitDy1 As Double, soffitDy2 As Double, cosA1 As Double, cosA2 As Double
    Dim xW0 As Double, xU0 As Double, xF0 As Double, xF1 As Double, xR0 As Double, xR1 As Double
    Dim yBot As Double, yMid As Double, yTop As Double
    Dim cover As Double, mainD As Double, mainSp As Double, distD As Double, distSp As Double
    Dim cleanMain As String, cleanDist As String, markNo As Long
    Dim p As CSASecPoly, i As Long, k As Long
    Dim span1 As Double, ux1 As Double, uy1 As Double, nx1 As Double, ny1 As Double
    Dim span2 As Double, ux2 As Double, uy2 As Double, nx2 As Double, ny2 As Double
    Dim ancLen As Double, symMark As String, dimGap As Double

    x0 = v.InsertX: y0 = v.InsertY
    supW = IIf(v.SupportWidth > 0#, v.SupportWidth, 200#)
    landW = IIf(v.Landing > 0#, v.Landing, 1500#)
    uLand = IIf(v.UpperLanding > 0#, v.UpperLanding, 1500#)
    downH = IIf(v.BeamDownstand > 0#, v.BeamDownstand, 250#)
    slabT = v.Slab
    n1 = v.Flight1Risers
    n2 = IIf(v.StairType = CSA_TYPE_THREE_FLIGHT, v.Flight2Risers + v.Flight3Risers, v.Flight2Risers)
    If n2 < 1 Then n2 = n1
    run1 = n1 * v.Tread
    run2 = n2 * v.Tread
    maxRun = IIf(run1 >= run2, run1, run2)
    midRise = n1 * v.Riser
    topRise = v.FloorHeight
    dimGap = 350#

    xW0 = x0
    xU0 = xW0 + supW
    xF0 = xU0 + uLand
    xF1 = xF0 + maxRun
    xR0 = xF1 + landW
    xR1 = xR0 + supW

    yBot = y0
    yMid = y0 + midRise
    yTop = y0 + topRise

    span1 = Sqr(run1 * run1 + midRise * midRise)
    cosA1 = run1 / span1
    soffitDy1 = slabT / cosA1
    ux1 = run1 / span1: uy1 = midRise / span1
    nx1 = -uy1: ny1 = ux1 ' upward-left normal to flight 1

    span2 = Sqr(run2 * run2 + (topRise - midRise) * (topRise - midRise))
    cosA2 = run2 / span2
    soffitDy2 = slabT / cosA2
    ux2 = -run2 / span2: uy2 = (topRise - midRise) / span2
    nx2 = uy2: ny2 = -ux2 ' upward-right normal to flight 2 (rising right->left)

    ' --- 1. Cut support walls/beams (left bottom, left top, right mid-landing) ---
    AddHatchedRect m, xW0, yBot - slabT - downH, xU0, yBot + 400#, CSA_LAYER_CONCRETE
    AddHatchedRect m, xW0, yTop - slabT - downH, xU0, yTop + 400#, CSA_LAYER_CONCRETE
    AddHatchedRect m, xR0, yBot - slabT - downH, xR1, yMid + 150#, CSA_LAYER_CONCRETE

    ' --- 2. Closed concrete polyline: Lower landing + Flight 1 + Mid-landing ---
    InitPoly p, CSA_LAYER_CONCRETE, True
    AddPolyPt p, xU0, yBot
    AddPolyPt p, xF0, yBot
    For i = 0 To n1 - 1
        AddPolyPt p, xF0 + i * v.Tread, yBot + (i + 1) * v.Riser
        AddPolyPt p, xF0 + (i + 1) * v.Tread, yBot + (i + 1) * v.Riser
    Next i
    AddPolyPt p, xR0, yMid
    AddPolyPt p, xR0, yMid - slabT
    ' Soffit intersection with mid-landing soffit (exact horizontal join)
    Dim xKnee1Top As Double, xKnee1Bot As Double
    xKnee1Top = xF0 + run1 + (soffitDy1 - slabT) * (run1 / midRise)
    If xKnee1Top > xR0 - 50# Then xKnee1Top = xF0 + run1
    xKnee1Bot = xF0 + (soffitDy1 - slabT) * (run1 / midRise)
    AddPolyPt p, xKnee1Top, yMid - slabT
    AddPolyPt p, xKnee1Bot, yBot - slabT
    AddPolyPt p, xU0, yBot - slabT
    CommitPoly m, p

    ' --- 3. Closed concrete polyline: Flight 2 (rising right->left) + Upper landing ---
    Dim xF2Start As Double
    xF2Start = xF0 + run2
    InitPoly p, CSA_LAYER_CONCRETE, True
    AddPolyPt p, xU0, yTop
    AddPolyPt p, xF0, yTop
    For i = n2 - 1 To 0 Step -1
        AddPolyPt p, xF0 + (n2 - 1 - i) * v.Tread, yMid + (i + 1) * v.Riser
        AddPolyPt p, xF0 + (n2 - i) * v.Tread, yMid + (i + 1) * v.Riser
        If i > 0 Then AddPolyPt p, xF0 + (n2 - i) * v.Tread, yMid + i * v.Riser
    Next i
    AddPolyPt p, xF2Start, yMid
    AddPolyPt p, xF2Start, yMid - slabT
    ' Soffit of Flight 2 going up-left with exact perpendicular thickness slabT
    Dim xKnee2Bot As Double, xKnee2Top As Double
    xKnee2Bot = xF2Start - (soffitDy2 - slabT) * (run2 / (topRise - midRise))
    xKnee2Top = xF0 - (soffitDy2 - slabT) * (run2 / (topRise - midRise))
    If xKnee2Top < xU0 + 50# Then xKnee2Top = xF0
    AddPolyPt p, xKnee2Bot, yMid - slabT
    AddPolyPt p, xKnee2Top, yTop - slabT
    AddPolyPt p, xU0, yTop - slabT
    CommitPoly m, p

    ' --- 4. Structural Reinforcement Detailing (2-layer longitudinal + dots + callouts) ---
    If v.PreviewRebar Then
        cover = IIf(v.CoverMm > 0#, v.CoverMm, 25#)
        If Not CSA_ParseBar(v.FlightBotBar, mainD, mainSp, cleanMain) Then mainD = 12#: mainSp = 150#: cleanMain = "12a150"
        If Not CSA_ParseBar(v.DistBar, distD, distSp, cleanDist) Then distD = 10#: distSp = 200#: cleanDist = "10a200"
        ancLen = IIf(v.AnchorFactor > 0#, v.AnchorFactor * mainD, 30# * mainD)
        markNo = IIf(v.StartBarMark > 0, v.StartBarMark, 1)

        ' Helper axes for Flight 1 (nosing inner line from (xF0, yBot) to (xF0+run1, yMid))
        Dim f1BotAx1X As Double, f1BotAx1Y As Double, f1BotAx2X As Double, f1BotAx2Y As Double
        Dim f1TopAx1X As Double, f1TopAx1Y As Double, f1TopAx2X As Double, f1TopAx2Y As Double
        f1BotAx1X = xKnee1Bot + cover * nx1: f1BotAx1Y = (yBot - slabT) + cover * ny1
        f1BotAx2X = xKnee1Top + cover * nx1: f1BotAx2Y = (yMid - slabT) + cover * ny1
        f1TopAx1X = xF0 - cover * nx1: f1TopAx1Y = yBot - cover * ny1
        f1TopAx2X = xF0 + run1 - cover * nx1: f1TopAx2Y = yMid - cover * ny1

        ' Bar 1: Lower landing + Flight 1 Bottom bar (with outer wall anchorage & mid-landing anchor)
        Dim b1KneeX As Double, b1TopX As Double, b1EndX As Double
        b1KneeX = AtY(f1BotAx1X, f1BotAx1Y, f1BotAx2X, f1BotAx2Y, yBot - slabT + cover)
        b1TopX = AtY(f1BotAx1X, f1BotAx1Y, f1BotAx2X, f1BotAx2Y, yMid - slabT + cover)
        b1EndX = b1TopX + ancLen
        If b1EndX > xR1 - cover Then b1EndX = xR1 - cover
        InitPoly p, CSA_LAYER_REBAR, False
        AddPolyPt p, xW0 + cover + 20#, yBot - slabT + cover
        AddPolyPt p, b1KneeX, yBot - slabT + cover
        AddPolyPt p, b1TopX, yMid - slabT + cover
        AddPolyPt p, b1EndX, yMid - slabT + cover
        AddHookPt p, b1TopX, yMid - slabT + cover, b1EndX, yMid - slabT + cover, mainD, 1#
        CommitPoly m, p

        ' Callout for Bar 1 (bottom flight longitudinal)
        Dim mid1X As Double, mid1Y As Double
        mid1X = (b1KneeX + b1TopX) * 0.5: mid1Y = (yBot + yMid) * 0.5 - slabT + cover
        AddBarCallout m, mid1X, mid1Y, mid1X + 260#, mid1Y - 420#, False, CStr(markNo), _
                      CSA_FormatBarNotation(v.FlightBotBar, v.BarSymbol), True
        markNo = markNo + 1

        ' Bar 2: Lower landing + Flight 1 Top bar (when 2 layers)
        If v.RebarLayers >= 2 Then
            Dim t1KneeX As Double, t1TopX As Double, t1EndX As Double
            t1KneeX = AtY(f1TopAx1X, f1TopAx1Y, f1TopAx2X, f1TopAx2Y, yBot - cover)
            t1TopX = AtY(f1TopAx1X, f1TopAx1Y, f1TopAx2X, f1TopAx2Y, yMid - cover)
            t1EndX = t1TopX + ancLen
            If t1EndX > xR1 - cover Then t1EndX = xR1 - cover
            InitPoly p, CSA_LAYER_REBAR, False
            AddPolyPt p, xW0 + cover, yBot - slabT + cover
            AddPolyPt p, xW0 + cover, yBot - cover
            AddPolyPt p, t1KneeX, yBot - cover
            AddPolyPt p, t1TopX, yMid - cover
            AddPolyPt p, t1EndX, yMid - cover
            AddPolyPt p, t1EndX, yMid - slabT + cover
            CommitPoly m, p

            Dim midT1X As Double, midT1Y As Double
            midT1X = (t1KneeX + t1TopX) * 0.45: midT1Y = yBot + (yMid - yBot) * 0.45 - cover
            AddBarCallout m, midT1X, midT1Y, midT1X - 240#, midT1Y + 340#, False, CStr(markNo), _
                          CSA_FormatBarNotation(v.FlightTopBar, v.BarSymbol), False
            markNo = markNo + 1
        End If

        ' Bar 3 & 4: Flight 2 Bottom & Top longitudinal bars (rising right -> left)
        Dim f2BotAx1X As Double, f2BotAx1Y As Double, f2BotAx2X As Double, f2BotAx2Y As Double
        Dim f2TopAx1X As Double, f2TopAx1Y As Double, f2TopAx2X As Double, f2TopAx2Y As Double
        f2BotAx1X = xKnee2Bot + cover * nx2: f2BotAx1Y = (yMid - slabT) + cover * ny2
        f2BotAx2X = xKnee2Top + cover * nx2: f2BotAx2Y = (yTop - slabT) + cover * ny2
        f2TopAx1X = xF2Start - cover * nx2: f2TopAx1Y = yMid - cover * ny2
        f2TopAx2X = xF0 - cover * nx2: f2TopAx2Y = yTop - cover * ny2

        Dim b2BotX As Double, b2TopX As Double
        b2BotX = AtY(f2BotAx1X, f2BotAx1Y, f2BotAx2X, f2BotAx2Y, yMid - slabT + cover + 10#)
        b2TopX = AtY(f2BotAx1X, f2BotAx1Y, f2BotAx2X, f2BotAx2Y, yTop - slabT + cover)
        InitPoly p, CSA_LAYER_REBAR, False
        AddPolyPt p, xR1 - cover - 20#, yMid - slabT + cover + 10#
        AddPolyPt p, b2BotX, yMid - slabT + cover + 10#
        AddPolyPt p, b2TopX, yTop - slabT + cover
        AddPolyPt p, xW0 + cover + 20#, yTop - slabT + cover
        CommitPoly m, p

        Dim mid2X As Double, mid2Y As Double
        mid2X = (b2BotX + b2TopX) * 0.5: mid2Y = (yMid + yTop) * 0.5 - slabT + cover
        AddBarCallout m, mid2X, mid2Y, mid2X - 240#, mid2Y - 340#, False, CStr(markNo), _
                      CSA_FormatBarNotation(v.FlightBotBar, v.BarSymbol), False
        markNo = markNo + 1

        If v.RebarLayers >= 2 Then
            Dim t2BotX As Double, t2TopX As Double
            t2BotX = AtY(f2TopAx1X, f2TopAx1Y, f2TopAx2X, f2TopAx2Y, yMid - cover - 10#)
            t2TopX = AtY(f2TopAx1X, f2TopAx1Y, f2TopAx2X, f2TopAx2Y, yTop - cover)
            InitPoly p, CSA_LAYER_REBAR, False
            AddPolyPt p, xR1 - cover, yMid - slabT + cover
            AddPolyPt p, xR1 - cover, yMid - cover - 10#
            AddPolyPt p, t2BotX, yMid - cover - 10#
            AddPolyPt p, t2TopX, yTop - cover
            AddPolyPt p, xW0 + cover, yTop - cover
            AddPolyPt p, xW0 + cover, yTop - slabT + cover
            CommitPoly m, p

            Dim midT2X As Double, midT2Y As Double
            midT2X = (t2BotX + t2TopX) * 0.5: midT2Y = (yMid + yTop) * 0.5 - cover
            AddBarCallout m, midT2X, midT2Y, midT2X + 260#, midT2Y + 340#, False, CStr(markNo), _
                          CSA_FormatBarNotation(v.FlightTopBar, v.BarSymbol), True
            markNo = markNo + 1
        End If

        ' Transverse distribution rebar dots (1.5 * d display diameter) along Flights & Landings
        Dim dotR As Double, dotOff As Double, sampleX As Double, sampleY As Double
        dotR = 0.75 * distD ' 1.5 * d / 2
        dotOff = cover + dotR
        AddDotLine m, xU0 + 100#, yBot - slabT + dotOff, b1KneeX - 60#, yBot - slabT + dotOff, distSp, dotR
        AddDotLine m, xKnee1Bot + dotOff * nx1 + 120# * ux1, (yBot - slabT) + dotOff * ny1 + 120# * uy1, _
                   xKnee1Top + dotOff * nx1 - 120# * ux1, (yMid - slabT) + dotOff * ny1 - 120# * uy1, distSp, dotR
        AddDotLine m, b1TopX + 80#, yMid - slabT + dotOff, xR0 - 80#, yMid - slabT + dotOff, distSp, dotR
        AddDotLine m, xKnee2Bot + dotOff * nx2 + 120# * ux2, (yMid - slabT) + dotOff * ny2 + 120# * uy2, _
                   xKnee2Top + dotOff * nx2 - 120# * ux2, (yTop - slabT) + dotOff * ny2 - 120# * uy2, distSp, dotR
        AddDotLine m, xU0 + 100#, yTop - slabT + dotOff, b2TopX - 60#, yTop - slabT + dotOff, distSp, dotR

        If v.RebarLayers >= 2 Then
            AddDotLine m, xU0 + 100#, yBot - dotOff, t1KneeX - 60#, yBot - dotOff, distSp, dotR
            AddDotLine m, xF0 - dotOff * nx1 + 120# * ux1, yBot - dotOff * ny1 + 120# * uy1, _
                       xF0 + run1 - dotOff * nx1 - 120# * ux1, yMid - dotOff * ny1 - 120# * uy1, distSp, dotR
            AddDotLine m, t1TopX + 80#, yMid - dotOff, xR0 - 80#, yMid - dotOff, distSp, dotR
            AddDotLine m, xU0 + 100#, yTop - dotOff, t2TopX - 60#, yTop - dotOff, distSp, dotR
        End If

        ' Callout for transverse distribution dots (Dot blank marker)
        sampleX = xKnee1Bot + dotOff * nx1 + (span1 * 0.58) * ux1
        sampleY = (yBot - slabT) + dotOff * ny1 + (span1 * 0.58) * uy1
        AddBarCallout m, sampleX, sampleY, sampleX + 320#, sampleY - 420#, True, CStr(markNo), _
                      CSA_FormatBarNotation(v.DistBar, v.BarSymbol), True
    End If

    ' --- 5. Elevation guides & Cao do blocks ---
    AddLevelGuide m, xW0 - 500#, xR1 + 500#, yBot, v.BottomElevation
    AddLevelGuide m, xW0 - 500#, xR1 + 500#, yMid, v.BottomElevation + midRise / 1000#
    AddLevelGuide m, xW0 - 500#, xR1 + 500#, yTop, v.TopElevation

    ' --- 6. Structural Dimensions (with 200 mm short feet) ---
    If v.DrawDimensions Then
        Dim dimBot1 As Double, dimBot2 As Double, dimRight1 As Double, dimRight2 As Double
        dimBot1 = yBot - slabT - downH - dimGap
        dimBot2 = dimBot1 - dimGap
        dimRight1 = xR1 + 650#
        dimRight2 = dimRight1 + dimGap

        AddSecDim m, "H", xU0, yBot - slabT, xF0, yBot - slabT, xF0, dimBot1, ""
        AddSecDim m, "H", xF0, yBot - slabT, xF1, yBot - slabT, xF0, dimBot1, _
                  CStr(n1) & " x " & TrimZero(v.Tread) & " = <>"
        AddSecDim m, "H", xF1, yMid - slabT, xR0, yMid - slabT, xF1, dimBot1, ""
        AddSecDim m, "H", xU0, yBot - slabT, xR0, yBot - slabT, xU0, dimBot2, ""

        AddSecDim m, "V", xR1, yBot, xR1, yMid, dimRight1, yMid, ""
        AddSecDim m, "V", xR1, yMid, xR1, yTop, dimRight1, yTop, ""
        AddSecDim m, "V", xR1, yBot, xR1, yTop, dimRight2, yTop, ""

        ' Slab thickness at lower landing + perpendicular waist thickness at 1/3 of Flight 1
        AddSecDim m, "V", xU0, yBot - slabT, xU0, yBot, xW0 - dimGap, yBot, ""
        Dim ptOneThirdX As Double, ptOneThirdY As Double, ptProjX As Double, ptProjY As Double
        ptOneThirdX = xF0 + run1 / 3#: ptOneThirdY = yBot + midRise / 3#
        ptProjX = ptOneThirdX - slabT * nx1: ptProjY = ptOneThirdY - slabT * ny1
        AddSecDim m, "A", ptProjX, ptProjY, ptOneThirdX, ptOneThirdY, _
                  (ptOneThirdX + ptProjX) * 0.5, (ptOneThirdY + ptProjY) * 0.5, ""
    End If

    ' --- 7. Section Title + MAT CAT + Daucat ---
    symMark = Trim$(v.SectionMark)
    If Len(symMark) = 0 Then symMark = "A"
    AddSectionCaption m, (xW0 + xR1) * 0.5, yBot - slabT - downH - 3# * dimGap - 200#, _
                      Trim$(v.StairName), symMark
End Sub

' =============================================================================
' MODE 2: PARAMETRIC SINGLE FLIGHT STRUCTURAL SECTION
' =============================================================================
Private Sub BuildParametricSingleSection(ByRef v As CSAStairInput, ByRef m As CSASectionModel)
    Dim x0 As Double, y0 As Double
    Dim supW As Double, landW As Double, uLand As Double, downH As Double
    Dim n1 As Long, run1 As Double, rise1 As Double, slabT As Double
    Dim span1 As Double, ux1 As Double, uy1 As Double, nx1 As Double, ny1 As Double, soffitDy As Double
    Dim xW0 As Double, xL0 As Double, xF0 As Double, xF1 As Double, xU1 As Double, xW1 As Double
    Dim xKneeBot As Double, xKneeTop As Double
    Dim p As CSASecPoly, i As Long, dimGap As Double, symMark As String
    Dim cover As Double, mainD As Double, mainSp As Double, distD As Double, distSp As Double
    Dim cleanMain As String, cleanDist As String, markNo As Long

    x0 = v.InsertX: y0 = v.InsertY
    supW = IIf(v.SupportWidth > 0#, v.SupportWidth, 200#)
    landW = IIf(v.Landing > 0#, v.Landing, 1200#)
    uLand = IIf(v.UpperLanding > 0#, v.UpperLanding, 1200#)
    downH = IIf(v.BeamDownstand > 0#, v.BeamDownstand, 250#)
    slabT = v.Slab
    n1 = v.Flight1Risers
    run1 = n1 * v.Tread
    rise1 = v.FloorHeight
    dimGap = 350#

    xW0 = x0
    xL0 = xW0 + supW
    xF0 = xL0 + landW
    xF1 = xF0 + run1
    xU1 = xF1 + uLand
    xW1 = xU1 + supW

    span1 = Sqr(run1 * run1 + rise1 * rise1)
    ux1 = run1 / span1: uy1 = rise1 / span1
    nx1 = -uy1: ny1 = ux1
    soffitDy = slabT / (run1 / span1)
    xKneeBot = xF0 + (soffitDy - slabT) * (run1 / rise1)
    xKneeTop = xF1 + (soffitDy - slabT) * (run1 / rise1)
    If xKneeTop > xU1 - 40# Then xKneeTop = xF1

    ' Supports (hatched)
    AddHatchedRect m, xW0, y0 - slabT - downH, xL0, y0 + 250#, CSA_LAYER_CONCRETE
    AddHatchedRect m, xU1, y0 + rise1 - slabT - downH, xW1, y0 + rise1 + 250#, CSA_LAYER_CONCRETE

    ' Closed concrete outline
    InitPoly p, CSA_LAYER_CONCRETE, True
    AddPolyPt p, xL0, y0
    AddPolyPt p, xF0, y0
    For i = 0 To n1 - 1
        AddPolyPt p, xF0 + i * v.Tread, y0 + (i + 1) * v.Riser
        AddPolyPt p, xF0 + (i + 1) * v.Tread, y0 + (i + 1) * v.Riser
    Next i
    AddPolyPt p, xU1, y0 + rise1
    AddPolyPt p, xU1, y0 + rise1 - slabT
    AddPolyPt p, xKneeTop, y0 + rise1 - slabT
    AddPolyPt p, xKneeBot, y0 - slabT
    AddPolyPt p, xL0, y0 - slabT
    CommitPoly m, p

    If v.PreviewRebar Then
        cover = IIf(v.CoverMm > 0#, v.CoverMm, 25#)
        If Not CSA_ParseBar(v.FlightBotBar, mainD, mainSp, cleanMain) Then mainD = 12#: mainSp = 150#: cleanMain = "12a150"
        If Not CSA_ParseBar(v.DistBar, distD, distSp, cleanDist) Then distD = 10#: distSp = 200#: cleanDist = "10a200"
        markNo = IIf(v.StartBarMark > 0, v.StartBarMark, 1)

        Dim fBot1X As Double, fBot1Y As Double, fBot2X As Double, fBot2Y As Double
        Dim fTop1X As Double, fTop1Y As Double, fTop2X As Double, fTop2Y As Double
        fBot1X = xKneeBot + cover * nx1: fBot1Y = (y0 - slabT) + cover * ny1
        fBot2X = xKneeTop + cover * nx1: fBot2Y = (y0 + rise1 - slabT) + cover * ny1
        fTop1X = xF0 - cover * nx1: fTop1Y = y0 - cover * ny1
        fTop2X = xF1 - cover * nx1: fTop2Y = y0 + rise1 - cover * ny1

        Dim bK1 As Double, bK2 As Double
        bK1 = AtY(fBot1X, fBot1Y, fBot2X, fBot2Y, y0 - slabT + cover)
        bK2 = AtY(fBot1X, fBot1Y, fBot2X, fBot2Y, y0 + rise1 - slabT + cover)
        InitPoly p, CSA_LAYER_REBAR, False
        AddPolyPt p, xW0 + cover + 20#, y0 - slabT + cover
        AddPolyPt p, bK1, y0 - slabT + cover
        AddPolyPt p, bK2, y0 + rise1 - slabT + cover
        AddPolyPt p, xW1 - cover - 20#, y0 + rise1 - slabT + cover
        CommitPoly m, p
        AddBarCallout m, (bK1 + bK2) * 0.5, y0 + rise1 * 0.5 - slabT + cover, _
                      (bK1 + bK2) * 0.5 + 260#, y0 + rise1 * 0.5 - slabT - 420#, False, _
                      CStr(markNo), CSA_FormatBarNotation(v.FlightBotBar, v.BarSymbol), True
        markNo = markNo + 1

        If v.RebarLayers >= 2 Then
            Dim tK1 As Double, tK2 As Double
            tK1 = AtY(fTop1X, fTop1Y, fTop2X, fTop2Y, y0 - cover)
            tK2 = AtY(fTop1X, fTop1Y, fTop2X, fTop2Y, y0 + rise1 - cover)
            InitPoly p, CSA_LAYER_REBAR, False
            AddPolyPt p, xW0 + cover, y0 - slabT + cover
            AddPolyPt p, xW0 + cover, y0 - cover
            AddPolyPt p, tK1, y0 - cover
            AddPolyPt p, tK2, y0 + rise1 - cover
            AddPolyPt p, xW1 - cover, y0 + rise1 - cover
            AddPolyPt p, xW1 - cover, y0 + rise1 - slabT + cover
            CommitPoly m, p
            AddBarCallout m, (tK1 + tK2) * 0.5, y0 + rise1 * 0.5 - cover, _
                          (tK1 + tK2) * 0.5 - 260#, y0 + rise1 * 0.5 + 360#, False, _
                          CStr(markNo), CSA_FormatBarNotation(v.FlightTopBar, v.BarSymbol), False
            markNo = markNo + 1
        End If

        Dim dotR As Double, dotOff As Double
        dotR = 0.75 * distD: dotOff = cover + dotR
        AddDotLine m, xL0 + 100#, y0 - slabT + dotOff, bK1 - 60#, y0 - slabT + dotOff, distSp, dotR
        AddDotLine m, xKneeBot + dotOff * nx1 + 120# * ux1, (y0 - slabT) + dotOff * ny1 + 120# * uy1, _
                   xKneeTop + dotOff * nx1 - 120# * ux1, (y0 + rise1 - slabT) + dotOff * ny1 - 120# * uy1, distSp, dotR
        AddDotLine m, bK2 + 80#, y0 + rise1 - slabT + dotOff, xU1 - 80#, y0 + rise1 - slabT + dotOff, distSp, dotR
        AddBarCallout m, xKneeBot + dotOff * nx1 + (span1 * 0.6) * ux1, _
                      (y0 - slabT) + dotOff * ny1 + (span1 * 0.6) * uy1, _
                      xKneeBot + (span1 * 0.6) * ux1 + 340#, (y0 - slabT) + (span1 * 0.6) * uy1 - 420#, _
                      True, CStr(markNo), CSA_FormatBarNotation(v.DistBar, v.BarSymbol), True
    End If

    AddLevelGuide m, xW0 - 500#, xW1 + 500#, y0, v.BottomElevation
    AddLevelGuide m, xW0 - 500#, xW1 + 500#, y0 + rise1, v.TopElevation

    If v.DrawDimensions Then
        AddSecDim m, "H", xL0, y0 + rise1, xF0, y0 + rise1, xL0, y0 + rise1 + 775#, ""
        AddSecDim m, "H", xF0, y0 + rise1, xF1, y0 + rise1, xF0, y0 + rise1 + 775#, _
                  CStr(n1) & " x " & TrimZero(v.Tread) & " = <>"
        AddSecDim m, "H", xF1, y0 + rise1, xU1, y0 + rise1, xF1, y0 + rise1 + 775#, ""
        AddSecDim m, "V", xW0, y0, xW0, y0 + rise1, xW0 - 3# * dimGap, y0 + rise1, ""
        Dim p1X As Double, p1Y As Double, q1X As Double, q1Y As Double
        p1X = xF0 + run1 / 3#: p1Y = y0 + rise1 / 3#
        q1X = p1X - slabT * nx1: q1Y = p1Y - slabT * ny1
        AddSecDim m, "A", q1X, q1Y, p1X, p1Y, (p1X + q1X) * 0.5, (p1Y + q1Y) * 0.5, ""
    End If

    symMark = Trim$(v.SectionMark)
    If Len(symMark) = 0 Then symMark = "A"
    AddSectionCaption m, (xW0 + xW1) * 0.5, y0 - slabT - downH - 3# * dimGap, Trim$(v.StairName), symMark
End Sub

' =============================================================================
' MODE 3: EXCEL 24-POINT STRUCTURAL SECTION (Cau Thang Tools v5.6 CONTRACT)
' =============================================================================
Private Sub BuildExcel24Section(ByRef v As CSAStairInput, ByRef m As CSASectionModel)
    Dim rx(0 To 23) As Double, ry(0 To 23) As Double
    Dim i As Long, minX As Double, maxX As Double, minY As Double, maxY As Double
    Dim p As CSASecPoly, gap As Double, symMark As String
    Dim runSpan As Double, stepCount As Long, stepText As String
    Dim cover As Double, fBotD As Double, fBotSp As Double, fTopD As Double, fTopSp As Double
    Dim lBotD As Double, lBotSp As Double, lTopD As Double, lTopSp As Double
    Dim distD As Double, distSp As Double, tmpClean As String
    Dim markNo As Long, ancMult As Double

    For i = 0 To 23
        rx(i) = v.InsertX + v.ExcelRawX(i)
        ry(i) = v.InsertY + v.ExcelRawY(i)
        If i = 0 Then
            minX = rx(0): maxX = rx(0): minY = ry(0): maxY = ry(0)
        Else
            If rx(i) < minX Then minX = rx(i)
            If rx(i) > maxX Then maxX = rx(i)
            If ry(i) < minY Then minY = ry(i)
            If ry(i) > maxY Then maxY = ry(i)
        End If
    Next i

    ' 1. Deduplicated closed concrete outline on 21-CSA-BD
    InitPoly p, CSA_LAYER_CONCRETE, True
    For i = 0 To 23
        If p.ptCount = 0 Then
            AddPolyPt p, rx(i), ry(i)
        ElseIf Dist2D(p.xs(p.ptCount - 1), p.ys(p.ptCount - 1), rx(i), ry(i)) > 0.001 Then
            AddPolyPt p, rx(i), ry(i)
        End If
    Next i
    If p.ptCount > 1 Then
        If Dist2D(p.xs(0), p.ys(0), p.xs(p.ptCount - 1), p.ys(p.ptCount - 1)) <= 0.001 Then
            p.ptCount = p.ptCount - 1
        End If
    End If
    CommitPoly m, p

    ' 2. Elevation guides (01-CSA-Grid) & Cao do blocks (11-CSA-Cao Do)
    AddLevelGuide m, rx(0) - 500#, rx(5) + 500#, ry(0), v.BottomElevation
    AddLevelGuide m, rx(0) - 500#, rx(5) + 500#, ry(4), v.TopElevation

    ' 3. 15 Concrete Details Dimensions (exact v5.6 contract from CSA_StairConcreteDetails.lsp)
    gap = 400#
    If v.DrawDimensions Then
        runSpan = rx(3) - rx(1)
        stepCount = IIf(v.ExcelFlightSteps > 0, v.ExcelFlightSteps, v.Flight1Risers)
        If stepCount > 0 And runSpan > 0# Then
            stepText = CStr(stepCount) & " x " & Format$(runSpan / CDbl(stepCount), "0.00") & " = <>"
        End If

        AddSecDim m, "H", rx(0), ry(0), rx(1), ry(1), minX, maxY + 775#, ""
        AddSecDim m, "H", rx(1), ry(1), rx(3), ry(3), minX, maxY + 775#, stepText
        AddSecDim m, "H", rx(3), ry(3), rx(5), ry(5), minX, maxY + 775#, ""
        AddSecDim m, "V", rx(0), ry(0), rx(4), ry(4), minX - 3# * gap, maxY, ""
        AddSecDim m, "V", rx(20), ry(20), rx(0), ry(0), minX - gap, minY, ""
        AddSecDim m, "V", rx(22), ry(22), rx(20), ry(20), minX - gap, minY, ""
        AddSecDim m, "H", rx(22), ry(22), rx(21), ry(21), minX, minY - gap, ""
        AddSecDim m, "H", rx(18), ry(18), rx(17), ry(17), minX, minY - gap, ""
        AddSecDim m, "V", rx(8), ry(8), rx(4), ry(4), maxX + gap, maxY, ""
        AddSecDim m, "V", rx(6), ry(6), rx(8), ry(8), maxX + gap, maxY, ""
        Dim upperY As Double
        upperY = IIf(ry(6) < ry(11), ry(6), ry(11)) - gap
        AddSecDim m, "H", rx(11), ry(11), rx(10), ry(10), maxX, upperY, ""
        AddSecDim m, "H", rx(7), ry(7), rx(6), ry(6), maxX, upperY, ""
        AddSecDim m, "V", rx(1), ry(1), rx(2), ry(2), rx(1) - gap, ry(2), ""
        AddSecDim m, "V", rx(3), ry(3), rx(4), ry(4), rx(3) - gap, ry(4), ""

        ' Perpendicular inclined slab thickness at 1/3 span from lower end
        Dim pX As Double, pY As Double, qX As Double, qY As Double
        pX = rx(2) + (rx(3) - rx(2)) / 3#: pY = ry(2) + (ry(3) - ry(2)) / 3#
        ProjectPoint pX, pY, rx(13), ry(13), rx(14), ry(14), qX, qY
        AddSecDim m, "A", qX, qY, pX, pY, (pX + qX) * 0.5, (pY + qY) * 0.5, ""
    End If

    ' 4. v5.6 Rebar Detailing on 24-point Excel section
    If v.PreviewRebar Then
        cover = IIf(v.CoverMm > 0#, v.CoverMm, 25#)
        ancMult = IIf(v.AnchorFactor > 0#, v.AnchorFactor, 30#)
        markNo = IIf(v.StartBarMark > 0, v.StartBarMark, 1)
        If Not CSA_ParseBar(v.FlightBotBar, fBotD, fBotSp, tmpClean) Then fBotD = 12#: fBotSp = 150#
        If Not CSA_ParseBar(v.FlightTopBar, fTopD, fTopSp, tmpClean) Then fTopD = 12#: fTopSp = 150#
        If Not CSA_ParseBar(v.LowerLandingBotBar, lBotD, lBotSp, tmpClean) Then lBotD = 12#: lBotSp = 150#
        If Not CSA_ParseBar(v.LowerLandingTopBar, lTopD, lTopSp, tmpClean) Then lTopD = 12#: lTopSp = 150#
        If Not CSA_ParseBar(v.DistBar, distD, distSp, tmpClean) Then distD = 10#: distSp = 200#

        ' Flight bottom & top axes (offset by cover from soffit 14->13 and top 2->3)
        Dim flSpan As Double, flUx As Double, flUy As Double, flNx As Double, flNy As Double
        flSpan = Dist2D(rx(2), ry(2), rx(3), ry(3))
        flUx = (rx(3) - rx(2)) / flSpan: flUy = (ry(3) - ry(2)) / flSpan
        flNx = -flUy: flNy = flUx ' left/upward normal

        Dim bot1X As Double, bot1Y As Double, bot2X As Double, bot2Y As Double
        Dim top1X As Double, top1Y As Double, top2X As Double, top2Y As Double
        bot1X = rx(14) + cover * flNx: bot1Y = ry(14) + cover * flNy
        bot2X = rx(13) + cover * flNx: bot2Y = ry(13) + cover * flNy
        top1X = rx(2) - cover * flNx: top1Y = ry(2) - cover * flNy
        top2X = rx(3) - cover * flNx: top2Y = ry(3) - cover * flNy

        Dim lowBotY As Double, lowTopY As Double, upBotY As Double, upTopY As Double
        lowBotY = ry(20) + cover: lowTopY = ry(0) - cover
        upBotY = ry(8) + cover: upTopY = ry(4) - cover

        Dim hasLowBeam As Boolean, hasUpBeam As Boolean
        hasLowBeam = ((rx(17) - rx(18)) > 0.5 And (ry(19) - ry(18)) > 0.5)
        hasUpBeam = ((rx(10) - rx(11)) > 0.5 And (ry(9) - ry(10)) > 0.5)

        ' --- Flight Bottom Longitudinal Bar (v5.6 bar 1 at upper beam: down at far cover face) ---
        Dim fbLowX As Double, fbUpX As Double, fbLowTipX As Double, fbUpTipY As Double
        fbLowX = AtY(bot1X, bot1Y, bot2X, bot2Y, lowBotY)
        InitPoly p, CSA_LAYER_REBAR, False
        If hasLowBeam Then
            Dim lbX As Double, lbLegY As Double
            lbX = rx(18) + cover
            lbLegY = AtX(bot1X, bot1Y, bot2X, bot2Y, lbX)
            Dim lbBotY As Double
            lbBotY = lbLegY - ancMult * fBotD
            If lbBotY < ry(18) + cover Then lbBotY = ry(18) + cover
            AddPolyPt p, lbX, lbBotY
            AddPolyPt p, lbX, lbLegY
        Else
            fbLowTipX = fbLowX - ancMult * fBotD
            If fbLowTipX < rx(0) + cover Then fbLowTipX = rx(0) + cover
            AddPolyPt p, fbLowTipX, lowBotY
            AddPolyPt p, fbLowX, lowBotY
        End If
        If hasUpBeam Then
            fbUpX = rx(10) - cover
            Dim ubLegY As Double
            ubLegY = AtX(bot1X, bot1Y, bot2X, bot2Y, fbUpX)
            fbUpTipY = ubLegY - ancMult * fBotD
            If fbUpTipY < ry(10) + cover Then fbUpTipY = ry(10) + cover
            AddPolyPt p, fbUpX, ubLegY
            AddPolyPt p, fbUpX, fbUpTipY
            AddHookPt p, fbUpX, ubLegY, fbUpX, fbUpTipY, fBotD, -1#
        Else
            fbUpX = AtY(bot1X, bot1Y, bot2X, bot2Y, upBotY)
            Dim fbUpTipX As Double
            fbUpTipX = fbUpX + ancMult * fBotD
            If fbUpTipX > rx(5) - cover Then fbUpTipX = rx(5) - cover
            AddPolyPt p, fbUpX, upBotY
            AddPolyPt p, fbUpTipX, upBotY
            AddHookPt p, fbUpX, upBotY, fbUpTipX, upBotY, fBotD, 1#
        End If
        CommitPoly m, p
        AddBarCallout m, (bot1X + bot2X) * 0.5, (bot1Y + bot2Y) * 0.5, _
                      (bot1X + bot2X) * 0.5 + 320#, (bot1Y + bot2Y) * 0.5 - 420#, False, _
                      CStr(markNo), CSA_FormatBarNotation(v.FlightBotBar, v.BarSymbol), True
        markNo = markNo + 1

        ' --- Flight Top Longitudinal Bar (v5.6 bar 2 at upper beam: landing top axis - 10 mm) ---
        If v.RebarLayers >= 2 Then
            Dim ftLowX As Double, ftUpX As Double, ftUpY As Double
            ftLowX = AtY(top1X, top1Y, top2X, top2Y, lowBotY + 10#)
            InitPoly p, CSA_LAYER_REBAR, False
            Dim ftLowTipX As Double
            ftLowTipX = ftLowX - ancMult * fTopD
            If ftLowTipX < rx(0) + cover Then ftLowTipX = rx(0) + cover
            AddPolyPt p, ftLowTipX, lowBotY + 10#
            AddPolyPt p, ftLowX, lowBotY + 10#
            If hasUpBeam Then
                ftUpY = upTopY - 10#
                ftUpX = AtY(top1X, top1Y, top2X, top2Y, ftUpY)
                Dim ftUpTipX As Double
                ftUpTipX = ftUpX + ancMult * fTopD
                If ftUpTipX > rx(5) - cover Then ftUpTipX = rx(5) - cover
                AddPolyPt p, ftUpX, ftUpY
                AddPolyPt p, ftUpTipX, ftUpY
                AddHookPt p, ftUpX, ftUpY, ftUpTipX, ftUpY, fTopD, -1#
            Else
                ftUpX = AtY(top1X, top1Y, top2X, top2Y, upBotY + 10#)
                Dim ftUpTip2 As Double
                ftUpTip2 = ftUpX + ancMult * fTopD
                If ftUpTip2 > rx(5) - cover Then ftUpTip2 = rx(5) - cover
                AddPolyPt p, ftUpX, upBotY + 10#
                AddPolyPt p, ftUpTip2, upBotY + 10#
                AddHookPt p, ftUpX, upBotY + 10#, ftUpTip2, upBotY + 10#, fTopD, 1#
            End If
            CommitPoly m, p
            AddBarCallout m, (top1X + top2X) * 0.45, (top1Y + top2Y) * 0.45, _
                          (top1X + top2X) * 0.45 - 260#, (top1Y + top2Y) * 0.45 + 360#, False, _
                          CStr(markNo), CSA_FormatBarNotation(v.FlightTopBar, v.BarSymbol), False
            markNo = markNo + 1
        End If

        ' --- Lower Landing Bars (outer top return + lower 20mm setback) ---
        If v.HasLowerLandingBars Then
            InitPoly p, CSA_LAYER_REBAR, False
            AddPolyPt p, rx(0) + cover + 20#, lowBotY
            AddPolyPt p, fbLowX, lowBotY
            CommitPoly m, p
            AddBarCallout m, (rx(0) + rx(1)) * 0.5, lowBotY, (rx(0) + rx(1)) * 0.5 + 220#, lowBotY - 360#, _
                          False, CStr(markNo), CSA_FormatBarNotation(v.LowerLandingBotBar, v.BarSymbol), True
            markNo = markNo + 1

            If v.RebarLayers >= 2 Then
                Dim ltKneeX As Double
                ltKneeX = AtY(bot1X + 10# * flNx, bot1Y + 10# * flNy, bot2X + 10# * flNx, bot2Y + 10# * flNy, lowTopY)
                InitPoly p, CSA_LAYER_REBAR, False
                AddPolyPt p, rx(0) + cover, lowBotY
                AddPolyPt p, rx(0) + cover, lowTopY
                AddPolyPt p, ltKneeX, lowTopY
                AddPolyPt p, ltKneeX + ancMult * lTopD * flUx, lowTopY + ancMult * lTopD * flUy
                CommitPoly m, p
                AddBarCallout m, (rx(0) + rx(1)) * 0.45, lowTopY, (rx(0) + rx(1)) * 0.45 - 200#, lowTopY + 340#, _
                              False, CStr(markNo), CSA_FormatBarNotation(v.LowerLandingTopBar, v.BarSymbol), False
                markNo = markNo + 1
            End If
        End If

        ' --- Upper Landing Bars (v5.6 bar 3 down at final riser cover face; bar 4 along flight top - 10mm) ---
        If v.HasUpperLandingBars Then
            InitPoly p, CSA_LAYER_REBAR, False
            AddPolyPt p, rx(5) - cover - 20#, upBotY
            If hasUpBeam Then
                Dim u4KneeX As Double
                u4KneeX = AtY(top1X - 10# * flNx, top1Y - 10# * flNy, top2X - 10# * flNx, top2Y - 10# * flNy, upBotY)
                AddPolyPt p, u4KneeX, upBotY
                AddPolyPt p, u4KneeX - ancMult * lBotD * flUx, upBotY - ancMult * lBotD * flUy
            Else
                AddPolyPt p, fbUpX, upBotY
                AddPolyPt p, fbUpX - ancMult * lBotD * flUx, upBotY - ancMult * lBotD * flUy
            End If
            CommitPoly m, p
            AddBarCallout m, (rx(4) + rx(5)) * 0.5, upBotY, (rx(4) + rx(5)) * 0.5 + 220#, upBotY - 360#, _
                          False, CStr(markNo), CSA_FormatBarNotation(v.LowerLandingBotBar, v.BarSymbol), True
            markNo = markNo + 1

            If v.RebarLayers >= 2 Then
                InitPoly p, CSA_LAYER_REBAR, False
                AddPolyPt p, rx(5) - cover, upBotY
                AddPolyPt p, rx(5) - cover, upTopY
                If hasUpBeam Then
                    Dim u3X As Double, u3TipY As Double
                    u3X = rx(4) + cover
                    u3TipY = upTopY - ancMult * lTopD
                    If u3TipY < ry(10) + cover Then u3TipY = ry(10) + cover
                    AddPolyPt p, u3X, upTopY
                    AddPolyPt p, u3X, u3TipY
                    AddHookPt p, u3X, upTopY, u3X, u3TipY, lTopD, 1#
                Else
                    AddPolyPt p, rx(4) + cover, upTopY
                End If
                CommitPoly m, p
                AddBarCallout m, (rx(4) + rx(5)) * 0.45, upTopY, (rx(4) + rx(5)) * 0.45 - 200#, upTopY + 340#, _
                              False, CStr(markNo), CSA_FormatBarNotation(v.LowerLandingTopBar, v.BarSymbol), False
                markNo = markNo + 1
            End If
        End If

        ' --- Transverse Distribution Dots (1.5 * d) ---
        Dim dotR As Double, dotOff As Double
        dotR = 0.75 * distD: dotOff = cover + dotR
        AddDotLine m, rx(14) + dotOff * flNx + 80# * flUx, ry(14) + dotOff * flNy + 80# * flUy, _
                   rx(13) + dotOff * flNx - 80# * flUx, ry(13) + dotOff * flNy - 80# * flUy, distSp, dotR
        If v.RebarLayers >= 2 Then
            AddDotLine m, rx(2) - dotOff * flNx + 80# * flUx, ry(2) - dotOff * flNy + 80# * flUy, _
                       rx(3) - dotOff * flNx - 80# * flUx, ry(3) - dotOff * flNy - 80# * flUy, distSp, dotR
        End If
        If v.HasLowerLandingDots Then
            AddDotLine m, rx(0) + cover + 80#, ry(20) + dotOff, rx(1) - 80#, ry(20) + dotOff, distSp, dotR
            If v.RebarLayers >= 2 Then AddDotLine m, rx(0) + cover + 80#, ry(0) - dotOff, rx(1) - 80#, ry(0) - dotOff, distSp, dotR
        End If
        If v.HasUpperLandingDots Then
            AddDotLine m, rx(4) + 80#, ry(8) + dotOff, rx(5) - cover - 80#, ry(8) + dotOff, distSp, dotR
            If v.RebarLayers >= 2 Then AddDotLine m, rx(4) + 80#, ry(4) - dotOff, rx(5) - cover - 80#, ry(4) - dotOff, distSp, dotR
        End If
        AddBarCallout m, rx(14) + dotOff * flNx + (flSpan * 0.58) * flUx, _
                      ry(14) + dotOff * flNy + (flSpan * 0.58) * flUy, _
                      rx(14) + (flSpan * 0.58) * flUx + 340#, ry(14) + (flSpan * 0.58) * flUy - 420#, _
                      True, CStr(markNo), CSA_FormatBarNotation(v.DistBar, v.BarSymbol), True
        markNo = markNo + 1

        ' --- Unsupported Neck Stirrup (d8a200 + 4d8 dots when neck > 100mm and no beam) ---
        If Not hasLowBeam And (ry(2) - ry(1)) > 100# Then
            AddNeckStirrup m, rx(1) + cover + 4#, ry(20) + cover + 4#, rx(15) - cover - 4#, ry(2) - cover - 4#, markNo, v.BarSymbol
            markNo = markNo + 2
        End If
        If Not hasUpBeam And (ry(4) - ry(3)) > 100# Then
            AddNeckStirrup m, rx(3) + cover + 4#, ry(13) + cover + 4#, rx(10) - cover - 4#, ry(4) - cover - 4#, markNo, v.BarSymbol
        End If
    End If

    ' 5. Centered Title + MAT CAT + Daucat
    symMark = Trim$(v.SectionMark)
    If Len(symMark) = 0 Then symMark = "A"
    AddSectionCaption m, (minX + maxX) * 0.5, minY - 3# * gap, Trim$(v.StairName), symMark
End Sub

' =============================================================================
' GEOMETRY & MODEL BUILDER HELPERS
' =============================================================================
Private Sub ResetSecModel(ByRef m As CSASectionModel)
    m.polyCount = 0: m.lineCount = 0: m.circleCount = 0
    m.dimCount = 0: m.levelCount = 0: m.noteCount = 0: m.textCount = 0
    m.cutSym.enabled = False
    Erase m.polys: Erase m.lines: Erase m.circles
    Erase m.dims: Erase m.levels: Erase m.notes: Erase m.texts
End Sub

Private Sub InitPoly(ByRef p As CSASecPoly, ByVal layerName As String, ByVal isClosed As Boolean)
    p.ptCount = 0
    p.layerName = layerName
    p.closed = isClosed
End Sub

Private Sub AddPolyPt(ByRef p As CSASecPoly, ByVal x As Double, ByVal y As Double)
    If p.ptCount > 127 Then Exit Sub
    p.xs(p.ptCount) = x
    p.ys(p.ptCount) = y
    p.ptCount = p.ptCount + 1
End Sub

Private Sub CommitPoly(ByRef m As CSASectionModel, ByRef p As CSASecPoly)
    If p.ptCount < 2 Then Exit Sub
    ReDim Preserve m.polys(0 To m.polyCount)
    m.polys(m.polyCount) = p
    m.polyCount = m.polyCount + 1
End Sub

Private Sub AddSecLine(ByRef m As CSASectionModel, ByVal x1 As Double, ByVal y1 As Double, _
                       ByVal x2 As Double, ByVal y2 As Double, ByVal layerName As String)
    ReDim Preserve m.lines(0 To m.lineCount)
    m.lines(m.lineCount).x1 = x1: m.lines(m.lineCount).y1 = y1
    m.lines(m.lineCount).x2 = x2: m.lines(m.lineCount).y2 = y2
    m.lines(m.lineCount).layerName = layerName
    m.lineCount = m.lineCount + 1
End Sub

Private Sub AddSecCircle(ByRef m As CSASectionModel, ByVal cx As Double, ByVal cy As Double, _
                         ByVal radius As Double, ByVal layerName As String, ByVal filled As Boolean)
    ReDim Preserve m.circles(0 To m.circleCount)
    m.circles(m.circleCount).cx = cx: m.circles(m.circleCount).cy = cy
    m.circles(m.circleCount).radius = radius
    m.circles(m.circleCount).layerName = layerName
    m.circles(m.circleCount).filled = filled
    m.circleCount = m.circleCount + 1
End Sub

Private Sub AddHatchedRect(ByRef m As CSASectionModel, ByVal x1 As Double, ByVal y1 As Double, _
                           ByVal x2 As Double, ByVal y2 As Double, ByVal layerName As String)
    Dim p As CSASecPoly, w As Double, h As Double, spacing As Double, d As Double
    Dim sx1 As Double, sy1 As Double, sx2 As Double, sy2 As Double
    InitPoly p, layerName, True
    AddPolyPt p, x1, y1: AddPolyPt p, x2, y1: AddPolyPt p, x2, y2: AddPolyPt p, x1, y2
    CommitPoly m, p
    w = x2 - x1: h = y2 - y1: spacing = 110#
    If w > 0# And h > 0# Then
        d = spacing
        Do While d < w + h
            sx1 = x1 + IIf(d <= h, 0#, d - h)
            sy1 = y1 + IIf(d <= h, d, h)
            sx2 = x1 + IIf(d <= w, d, w)
            sy2 = y1 + IIf(d <= w, 0#, d - w)
            AddSecLine m, sx1, sy1, sx2, sy2, CSA_LAYER_HATCH
            d = d + spacing
        Loop
    End If
End Sub

Private Sub AddHookPt(ByRef p As CSASecPoly, ByVal prevX As Double, ByVal prevY As Double, _
                      ByVal tipX As Double, ByVal tipY As Double, ByVal diamMm As Double, _
                      ByVal sideSign As Double)
    Dim span As Double, dx As Double, dy As Double, leg As Double
    span = Dist2D(prevX, prevY, tipX, tipY)
    If span < 0.001 Then Exit Sub
    dx = (tipX - prevX) / span: dy = (tipY - prevY) / span
    leg = 2# * diamMm
    AddPolyPt p, tipX + leg * (-COS_30 * dx - sideSign * SIN_30 * dy), _
                 tipY + leg * (-COS_30 * dy + sideSign * SIN_30 * dx)
End Sub

Private Sub AddDotLine(ByRef m As CSASectionModel, ByVal x1 As Double, ByVal y1 As Double, _
                       ByVal x2 As Double, ByVal y2 As Double, ByVal spacing As Double, _
                       ByVal dotRadius As Double)
    Dim span As Double, count As Long, i As Long, t As Double
    span = Dist2D(x1, y1, x2, y2)
    If span < 20# Or spacing <= 0# Then Exit Sub
    count = CLng(Int(span / spacing))
    If count < 1 Then count = 1
    For i = 0 To count
        t = CDbl(i) / CDbl(count)
        AddSecCircle m, x1 + t * (x2 - x1), y1 + t * (y2 - y1), dotRadius, CSA_LAYER_REBAR, True
    Next i
End Sub

Private Sub AddNeckStirrup(ByRef m As CSASectionModel, ByVal x1 As Double, ByVal y1 As Double, _
                           ByVal x2 As Double, ByVal y2 As Double, ByVal markNo As Long, _
                           ByVal barSym As String)
    Dim p As CSASecPoly, dotR As Double, pref As String
    If (x2 - x1) < 24# Or (y2 - y1) < 24# Then Exit Sub
    InitPoly p, CSA_LAYER_REBAR, True
    AddPolyPt p, x1, y1: AddPolyPt p, x2, y1: AddPolyPt p, x2, y2: AddPolyPt p, x1, y2
    CommitPoly m, p
    dotR = 6# ' 1.5 * 8 / 2
    AddSecCircle m, x1 + dotR, y1 + dotR, dotR, CSA_LAYER_REBAR, True
    AddSecCircle m, x2 - dotR, y1 + dotR, dotR, CSA_LAYER_REBAR, True
    AddSecCircle m, x2 - dotR, y2 - dotR, dotR, CSA_LAYER_REBAR, True
    AddSecCircle m, x1 + dotR, y2 - dotR, dotR, CSA_LAYER_REBAR, True
    pref = IIf(UCase$(Trim$(barSym)) = "T", "T", "%%C")
    AddBarCallout m, (x1 + x2) * 0.5, y1, (x1 + x2) * 0.5 + 200#, y1 - 260#, False, _
                  CStr(markNo), pref & "8a200", True
    AddBarCallout m, x1 + dotR, y1 + dotR, x1 + 200#, y1 - 440#, True, _
                  CStr(markNo + 1), "4" & pref & "8", True
End Sub

Private Sub AddBarCallout(ByRef m As CSASectionModel, ByVal tx As Double, ByVal ty As Double, _
                          ByVal lx As Double, ByVal ly As Double, ByVal isDot As Boolean, _
                          ByVal markText As String, ByVal barSpecText As String, _
                          ByVal extendRight As Boolean)
    Dim p As CSASecPoly, startY As Double, dirX As Double, tailLen As Double, dotRad As Double, halfTick As Double
    dotRad = 30#
    halfTick = 45#
    dirX = IIf(extendRight, 1#, -1#)
    tailLen = 520#

    ' Polyline callout trimmed to Dot blank circle perimeter (v5.6 rule)
    If isDot Then
        AddSecCircle m, tx, ty, dotRad, CSA_LAYER_NOTE, False
        startY = ty + IIf(ly >= ty, dotRad, -dotRad)
    Else
        AddSecLine m, tx - halfTick, ty - halfTick, tx + halfTick, ty + halfTick, CSA_LAYER_NOTE
        startY = ty
    End If

    InitPoly p, CSA_LAYER_NOTE, False
    AddPolyPt p, tx, startY
    AddPolyPt p, tx, ly
    AddPolyPt p, tx + dirX * tailLen, ly
    CommitPoly m, p

    ReDim Preserve m.notes(0 To m.noteCount)
    m.notes(m.noteCount).x = tx + dirX * (tailLen * 0.5)
    m.notes(m.noteCount).y = ly + 35#
    m.notes(m.noteCount).markText = markText
    m.notes(m.noteCount).barSpecText = barSpecText
    m.notes(m.noteCount).rightAligned = Not extendRight
    m.notes(m.noteCount).layerName = CSA_LAYER_NOTE
    m.noteCount = m.noteCount + 1
End Sub

Private Sub AddLevelGuide(ByRef m As CSASectionModel, ByVal xLeft As Double, ByVal xRight As Double, _
                          ByVal y As Double, ByVal elevM As Double)
    AddSecLine m, xLeft, y, xRight, y, CSA_LAYER_GRID
    ReDim Preserve m.levels(0 To m.levelCount)
    m.levels(m.levelCount).x = xRight
    m.levels(m.levelCount).y = y
    m.levels(m.levelCount).elevText = CSA_FormatElevation(elevM)
    m.levels(m.levelCount).layerName = CSA_LAYER_LEVEL
    m.levelCount = m.levelCount + 1
End Sub

Private Sub AddSecDim(ByRef m As CSASectionModel, ByVal kind As String, _
                      ByVal x1 As Double, ByVal y1 As Double, ByVal x2 As Double, ByVal y2 As Double, _
                      ByVal locX As Double, ByVal locY As Double, ByVal overrideText As String)
    Dim meas As Double
    If kind = "H" Then
        meas = Abs(x2 - x1)
    ElseIf kind = "V" Then
        meas = Abs(y2 - y1)
    Else
        meas = Dist2D(x1, y1, x2, y2)
    End If
    If meas < 0.01 Then Exit Sub
    ReDim Preserve m.dims(0 To m.dimCount)
    m.dims(m.dimCount).kind = kind
    m.dims(m.dimCount).x1 = x1: m.dims(m.dimCount).y1 = y1
    m.dims(m.dimCount).x2 = x2: m.dims(m.dimCount).y2 = y2
    m.dims(m.dimCount).locX = locX: m.dims(m.dimCount).locY = locY
    m.dims(m.dimCount).overrideText = overrideText
    m.dims(m.dimCount).layerName = CSA_LAYER_DIM
    m.dimCount = m.dimCount + 1

    ' Short 200mm extension feet (v5.5/v5.6 rule)
    AddShortFeet m, kind, x1, y1, x2, y2, locX, locY
End Sub

Private Sub AddShortFeet(ByRef m As CSASectionModel, ByVal kind As String, _
                         ByVal x1 As Double, ByVal y1 As Double, ByVal x2 As Double, ByVal y2 As Double, _
                         ByVal locX As Double, ByVal locY As Double)
    Dim ax As Double, ay As Double, nx As Double, ny As Double, span As Double
    Dim i As Long, px As Double, py As Double, amt As Double, fx As Double, fy As Double, footLen As Double
    If kind = "H" Then
        ax = 1#: ay = 0#
    ElseIf kind = "V" Then
        ax = 0#: ay = 1#
    Else
        span = Dist2D(x1, y1, x2, y2)
        If span < 0.001 Then Exit Sub
        ax = (x2 - x1) / span: ay = (y2 - y1) / span
    End If
    nx = -ay: ny = ax
    For i = 0 To 1
        px = IIf(i = 0, x1, x2): py = IIf(i = 0, y1, y2)
        amt = (locX - px) * nx + (locY - py) * ny
        If Abs(amt) > 0.5 Then
            fx = px + amt * nx: fy = py + amt * ny
            footLen = IIf(Abs(amt) < FOOT_LIMIT, Abs(amt), FOOT_LIMIT)
            Dim sgnAmt As Double
            sgnAmt = IIf(amt >= 0#, 1#, -1#)
            AddSecLine m, fx, fy, fx - sgnAmt * footLen * nx, fy - sgnAmt * footLen * ny, CSA_LAYER_DIM
        End If
    Next i
End Sub

Private Sub AddSectionCaption(ByRef m As CSASectionModel, ByVal cx As Double, ByVal baseY As Double, _
                              ByVal titleText As String, ByVal symMark As String)
    ReDim Preserve m.texts(0 To m.textCount)
    m.texts(m.textCount).x = cx: m.texts(m.textCount).y = baseY
    m.texts(m.textCount).height = 200#
    m.texts(m.textCount).caption = titleText
    m.texts(m.textCount).layerName = CSA_LAYER_TEXT
    m.texts(m.textCount).centered = True
    m.textCount = m.textCount + 1

    ReDim Preserve m.texts(0 To m.textCount)
    m.texts(m.textCount).x = cx - 180#: m.texts(m.textCount).y = baseY - 320#
    m.texts(m.textCount).height = 140#
    m.texts(m.textCount).caption = "MAT CAT"
    m.texts(m.textCount).layerName = CSA_LAYER_TEXT
    m.texts(m.textCount).centered = True
    m.textCount = m.textCount + 1

    m.cutSym.x = cx + 220#: m.cutSym.y = baseY - 260#
    m.cutSym.mark = symMark
    m.cutSym.layerName = CSA_LAYER_SYMBOL
    m.cutSym.enabled = True
End Sub

Private Function Dist2D(ByVal x1 As Double, ByVal y1 As Double, ByVal x2 As Double, ByVal y2 As Double) As Double
    Dist2D = Sqr((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
End Function

Private Function AtY(ByVal x1 As Double, ByVal y1 As Double, ByVal x2 As Double, ByVal y2 As Double, _
                     ByVal targetY As Double) As Double
    If Abs(y2 - y1) < 0.000001 Then
        AtY = x1
    Else
        AtY = x1 + (targetY - y1) * (x2 - x1) / (y2 - y1)
    End If
End Function

Private Function AtX(ByVal x1 As Double, ByVal y1 As Double, ByVal x2 As Double, ByVal y2 As Double, _
                     ByVal targetX As Double) As Double
    If Abs(x2 - x1) < 0.000001 Then
        AtX = y1
    Else
        AtX = y1 + (targetX - x1) * (y2 - y1) / (x2 - x1)
    End If
End Function

Private Sub ProjectPoint(ByVal px As Double, ByVal py As Double, _
                         ByVal ax As Double, ByVal ay As Double, ByVal bx As Double, ByVal by As Double, _
                         ByRef qx As Double, ByRef qy As Double)
    Dim dx As Double, dy As Double, denom As Double, fac As Double
    dx = bx - ax: dy = by - ay
    denom = dx * dx + dy * dy
    If denom < 0.000000001 Then qx = ax: qy = ay: Exit Sub
    fac = ((px - ax) * dx + (py - ay) * dy) / denom
    qx = ax + fac * dx: qy = ay + fac * dy
End Sub

Private Function TrimZero(ByVal num As Double) As String
    Dim s As String
    s = Format$(num, "0.##")
    If Right$(s, 1) = "." Then s = Left$(s, Len(s) - 1)
    TrimZero = s
End Function
