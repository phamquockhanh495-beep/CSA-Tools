Attribute VB_Name = "modCSAStairSectionDraw"
Option Explicit

' ActiveX renderer for CSASectionModel (concrete, hatch, dimensions, elevations,
' rebar longitudinal bars, transverse rebar dots, polyline callouts & CSA blocks).

Private Const PI_HALF As Double = 1.5707963267949

Public Sub CSA_DrawSectionModel(ByRef v As CSAStairInput, ByVal isPreview As Boolean)
    Dim m As CSASectionModel
    Dim doc As Object, space As Object
    Dim i As Long, targetLayer As String, allowCreate As Boolean
    Dim hasCaoDo As Boolean, hasDaucat As Boolean, hasBarNote As Boolean, hasDimStyle As Boolean

    If Not CSA_HostReady() Then Exit Sub
    Set doc = CSA_CadDocument()
    Set space = doc.ModelSpace
    allowCreate = v.CreateLayers

    CSA_BuildSectionModel v, m

    If isPreview Then
        CSA_EnsureLayer CSA_LAYER_PREVIEW, 4, True
    Else
        PrepareFinalSectionLayers m, allowCreate
    End If

    hasCaoDo = SecBlockExists(doc, "Cao do")
    hasDaucat = SecBlockExists(doc, "Daucat")
    hasBarNote = SecBlockExists(doc, "CSA_Sohieu-KCthep")
    hasDimStyle = SecDimStyleExists(doc, v.DimStyleName)

    ' 1. Polylines (concrete outlines, rebar longitudinal bars, neck stirrups, callout leaders)
    For i = 0 To m.polyCount - 1
        targetLayer = IIf(isPreview, CSA_LAYER_PREVIEW, m.polys(i).layerName)
        DrawSecPoly space, m.polys(i), targetLayer, isPreview
    Next i

    ' 2. Lines (hatch strokes, elevation guides, 200mm short dim feet, arch ticks)
    For i = 0 To m.lineCount - 1
        targetLayer = IIf(isPreview, CSA_LAYER_PREVIEW, m.lines(i).layerName)
        DrawSecLine space, m.lines(i), targetLayer, isPreview
    Next i

    ' 3. Circles (transverse rebar dots & Dot blank hollow circles)
    For i = 0 To m.circleCount - 1
        targetLayer = IIf(isPreview, CSA_LAYER_PREVIEW, m.circles(i).layerName)
        DrawSecCircle space, m.circles(i), targetLayer, isPreview
    Next i

    ' 4. Elevation blocks (Cao do scale 0.25 or vector triangle fallback)
    For i = 0 To m.levelCount - 1
        targetLayer = IIf(isPreview, CSA_LAYER_PREVIEW, m.levels(i).layerName)
        DrawSecLevel space, m.levels(i), targetLayer, isPreview, hasCaoDo
    Next i

    ' 5. Rebar notes (CSA_Sohieu-KCthep scale 1.0 or clean circle+text fallback)
    For i = 0 To m.noteCount - 1
        targetLayer = IIf(isPreview, CSA_LAYER_PREVIEW, m.notes(i).layerName)
        DrawSecBarNote space, m.notes(i), targetLayer, isPreview, hasBarNote
    Next i

    ' 6. Section title & MAT CAT texts
    For i = 0 To m.textCount - 1
        targetLayer = IIf(isPreview, CSA_LAYER_PREVIEW, m.texts(i).layerName)
        DrawSecText space, m.texts(i), targetLayer, isPreview
    Next i

    ' 7. Section symbol (Daucat scale 0.01 or vector fallback)
    If m.cutSym.enabled Then
        targetLayer = IIf(isPreview, CSA_LAYER_PREVIEW, m.cutSym.layerName)
        DrawSecCutSym space, m.cutSym, targetLayer, isPreview, hasDaucat
    End If

    ' 8. Native AutoCAD dimensions (suppressed native ext lines; 200mm short feet already drawn)
    For i = 0 To m.dimCount - 1
        targetLayer = IIf(isPreview, CSA_LAYER_PREVIEW, m.dims(i).layerName)
        DrawSecDim space, m.dims(i), targetLayer, isPreview, v.DimStyleName, hasDimStyle
    Next i
End Sub

Private Sub PrepareFinalSectionLayers(ByRef m As CSASectionModel, ByVal allowCreate As Boolean)
    Dim i As Long
    CSA_EnsureLayer CSA_LAYER_CONCRETE, CSA_DefaultLayerColor(CSA_LAYER_CONCRETE), allowCreate
    For i = 0 To m.polyCount - 1
        CSA_EnsureLayer m.polys(i).layerName, CSA_DefaultLayerColor(m.polys(i).layerName), allowCreate
    Next i
    For i = 0 To m.lineCount - 1
        CSA_EnsureLayer m.lines(i).layerName, CSA_DefaultLayerColor(m.lines(i).layerName), allowCreate
    Next i
    For i = 0 To m.circleCount - 1
        CSA_EnsureLayer m.circles(i).layerName, CSA_DefaultLayerColor(m.circles(i).layerName), allowCreate
    Next i
    For i = 0 To m.levelCount - 1
        CSA_EnsureLayer m.levels(i).layerName, CSA_DefaultLayerColor(m.levels(i).layerName), allowCreate
    Next i
    For i = 0 To m.noteCount - 1
        CSA_EnsureLayer m.notes(i).layerName, CSA_DefaultLayerColor(m.notes(i).layerName), allowCreate
    Next i
    For i = 0 To m.textCount - 1
        CSA_EnsureLayer m.texts(i).layerName, CSA_DefaultLayerColor(m.texts(i).layerName), allowCreate
    Next i
    If m.cutSym.enabled Then
        CSA_EnsureLayer m.cutSym.layerName, CSA_DefaultLayerColor(m.cutSym.layerName), allowCreate
    End If
    For i = 0 To m.dimCount - 1
        CSA_EnsureLayer m.dims(i).layerName, CSA_DefaultLayerColor(m.dims(i).layerName), allowCreate
    Next i
End Sub

Private Sub DrawSecPoly(ByVal space As Object, ByRef p As CSASecPoly, _
                        ByVal layerName As String, ByVal isPreview As Boolean)
    Dim coords() As Double, i As Long, ent As Object
    If p.ptCount < 2 Then Exit Sub
    ReDim coords(0 To p.ptCount * 2 - 1)
    For i = 0 To p.ptCount - 1
        coords(i * 2) = p.xs(i)
        coords(i * 2 + 1) = p.ys(i)
    Next i
    Set ent = space.AddLightWeightPolyline(coords)
    ent.Closed = p.closed
    ApplySecByLayer ent, layerName, isPreview
End Sub

Private Sub DrawSecLine(ByVal space As Object, ByRef seg As CSASecLine, _
                        ByVal layerName As String, ByVal isPreview As Boolean)
    Dim ent As Object
    Set ent = space.AddLine(CSA_Point3D(seg.x1, seg.y1, 0#), CSA_Point3D(seg.x2, seg.y2, 0#))
    ApplySecByLayer ent, layerName, isPreview
End Sub

Private Sub DrawSecCircle(ByVal space As Object, ByRef c As CSASecCircle, _
                          ByVal layerName As String, ByVal isPreview As Boolean)
    Dim ent As Object
    Set ent = space.AddCircle(CSA_Point3D(c.cx, c.cy, 0#), c.radius)
    ApplySecByLayer ent, layerName, isPreview
    ' Solid visual accent for transverse rebar dots (small inner ring)
    If c.filled And c.radius > 2# Then
        Set ent = space.AddCircle(CSA_Point3D(c.cx, c.cy, 0#), c.radius * 0.45)
        ApplySecByLayer ent, layerName, isPreview
    End If
End Sub

Private Sub DrawSecLevel(ByVal space As Object, ByRef lv As CSASecLevel, _
                         ByVal layerName As String, ByVal isPreview As Boolean, _
                         ByVal hasCaoDo As Boolean)
    Dim ent As Object, pt As Variant
    pt = CSA_Point3D(lv.x, lv.y, 0#)
    If hasCaoDo And Not isPreview Then
        On Error GoTo FallbackLevel
        Set ent = CSA_InsertElevation(pt, lv.elevText, 0.25)
        Exit Sub
    End If
FallbackLevel:
    On Error GoTo 0
    Set ent = space.AddLine(CSA_Point3D(lv.x, lv.y, 0#), CSA_Point3D(lv.x - 90#, lv.y + 110#, 0#))
    ApplySecByLayer ent, layerName, isPreview
    Set ent = space.AddLine(CSA_Point3D(lv.x, lv.y, 0#), CSA_Point3D(lv.x + 90#, lv.y + 110#, 0#))
    ApplySecByLayer ent, layerName, isPreview
    Set ent = space.AddLine(CSA_Point3D(lv.x - 90#, lv.y + 110#, 0#), CSA_Point3D(lv.x + 90#, lv.y + 110#, 0#))
    ApplySecByLayer ent, layerName, isPreview
    Set ent = space.AddText(lv.elevText, CSA_Point3D(lv.x - 80#, lv.y + 140#, 0#), 110#)
    ApplySecByLayer ent, layerName, isPreview
End Sub

Private Sub DrawSecBarNote(ByVal space As Object, ByRef bn As CSASecBarNote, _
                           ByVal layerName As String, ByVal isPreview As Boolean, _
                           ByVal hasBarNote As Boolean)
    Dim ent As Object, pt As Variant, circX As Double
    pt = CSA_Point3D(bn.x, bn.y, 0#)
    If hasBarNote And Not isPreview Then
        On Error GoTo FallbackNote
        Set ent = CSA_InsertBarNote(pt, bn.markText, bn.barSpecText, 1#)
        Exit Sub
    End If
FallbackNote:
    On Error GoTo 0
    circX = bn.x + IIf(bn.rightAligned, -200#, 220#)
    Set ent = space.AddCircle(CSA_Point3D(circX, bn.y + 45#, 0#), 65#)
    ApplySecByLayer ent, layerName, isPreview
    Set ent = space.AddText(bn.markText, CSA_Point3D(circX - 25#, bn.y + 10#, 0#), 80#)
    ApplySecByLayer ent, layerName, isPreview
    Set ent = space.AddText(bn.barSpecText, CSA_Point3D(bn.x - 160#, bn.y + 10#, 0#), 80#)
    ApplySecByLayer ent, layerName, isPreview
End Sub

Private Sub DrawSecText(ByVal space As Object, ByRef t As CSASecText, _
                        ByVal layerName As String, ByVal isPreview As Boolean)
    Dim ent As Object, pt As Variant
    pt = CSA_Point3D(t.x, t.y, 0#)
    Set ent = space.AddText(t.caption, pt, t.height)
    If t.centered Then
        On Error Resume Next
        ent.Alignment = 1 ' acAlignmentCenter
        ent.TextAlignmentPoint = pt
        On Error GoTo 0
    End If
    ApplySecByLayer ent, layerName, isPreview
End Sub

Private Sub DrawSecCutSym(ByVal space As Object, ByRef sym As CSASecCutSym, _
                          ByVal layerName As String, ByVal isPreview As Boolean, _
                          ByVal hasDaucat As Boolean)
    Dim ent As Object, pt As Variant
    pt = CSA_Point3D(sym.x, sym.y, 0#)
    If hasDaucat And Not isPreview Then
        On Error GoTo FallbackCut
        Set ent = CSA_InsertSectionSymbol(pt, sym.mark, 0.01)
        Exit Sub
    End If
FallbackCut:
    On Error GoTo 0
    Set ent = space.AddCircle(pt, 95#)
    ApplySecByLayer ent, layerName, isPreview
    Set ent = space.AddText(sym.mark, CSA_Point3D(sym.x - 35#, sym.y - 45#, 0#), 100#)
    ApplySecByLayer ent, layerName, isPreview
End Sub

Private Sub DrawSecDim(ByVal space As Object, ByRef d As CSASecDim, _
                       ByVal layerName As String, ByVal isPreview As Boolean, _
                       ByVal styleName As String, ByVal hasDimStyle As Boolean)
    Dim ent As Object
    If d.kind = "A" Then
        Set ent = space.AddDimAligned(CSA_Point3D(d.x1, d.y1, 0#), _
                                      CSA_Point3D(d.x2, d.y2, 0#), _
                                      CSA_Point3D(d.locX, d.locY, 0#))
    Else
        Set ent = space.AddDimRotated(CSA_Point3D(d.x1, d.y1, 0#), _
                                      CSA_Point3D(d.x2, d.y2, 0#), _
                                      CSA_Point3D(d.locX, d.locY, 0#), _
                                      IIf(d.kind = "H", 0#, PI_HALF))
    End If
    If hasDimStyle Then
        On Error Resume Next
        ent.StyleName = styleName
        On Error GoTo 0
    End If
    If Len(d.overrideText) > 0 Then
        On Error Resume Next
        ent.TextOverride = d.overrideText
        On Error GoTo 0
    End If
    On Error Resume Next
    ent.ExtLine1Suppress = True
    ent.ExtLine2Suppress = True
    On Error GoTo 0
    ApplySecByLayer ent, layerName, isPreview
    ent.Update
End Sub

Private Sub ApplySecByLayer(ByVal ent As Object, ByVal layerName As String, ByVal isPreview As Boolean)
    ent.Layer = layerName
    ent.color = 256
    ent.Linetype = "ByLayer"
    ent.Lineweight = -1
    If isPreview Then CSA_MarkPreview ent
End Sub

Private Function SecBlockExists(ByVal doc As Object, ByVal blockName As String) As Boolean
    Dim obj As Object
    On Error Resume Next
    Set obj = doc.Blocks.Item(blockName)
    SecBlockExists = Not (obj Is Nothing)
    On Error GoTo 0
End Function

Private Function SecDimStyleExists(ByVal doc As Object, ByVal styleName As String) As Boolean
    Dim obj As Object
    If Len(Trim$(styleName)) = 0 Then Exit Function
    On Error Resume Next
    Set obj = doc.DimStyles.Item(styleName)
    SecDimStyleExists = Not (obj Is Nothing)
    On Error GoTo 0
End Function
