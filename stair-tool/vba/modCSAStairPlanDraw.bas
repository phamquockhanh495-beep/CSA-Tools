Attribute VB_Name = "modCSAStairPlanDraw"
Option Explicit

' ActiveX renderer for CSA Plan View geometry computed by modCSAStairPlanGeom.
' Uses native CSA layers (06-CSA-Slab-bor, 05-CSA-Hatch, 22-CSA-NC, 12-CSA-Ky hieu,
' 10-CSA-Text, 04-CSA-Dim) on final draw, or CSA-PREVIEW (tagged with XData) on preview.

Public Sub CSA_DrawPlanModel(ByRef v As CSAStairInput, ByVal isPreview As Boolean)
    Dim m As CSAPlanModel
    Dim doc As Object, space As Object
    Dim i As Long, targetLayer As String, allowCreate As Boolean
    Dim hasDaucat As Boolean, hasDimStyle As Boolean

    If Not CSA_HostReady() Then Exit Sub
    Set doc = CSA_CadDocument()
    Set space = doc.ModelSpace
    allowCreate = v.CreateLayers

    CSA_BuildPlanModel v, m

    If isPreview Then
        CSA_EnsureLayer CSA_LAYER_PREVIEW, 4, True
    Else
        PrepareFinalPlanLayers m, allowCreate
    End If

    hasDaucat = BlockExists(doc, "Daucat")
    hasDimStyle = DimStyleExists(doc, v.DimStyleName)

    ' 1. Closed rectangles (outlines & supports)
    For i = 0 To m.rectCount - 1
        targetLayer = IIf(isPreview, CSA_LAYER_PREVIEW, m.rects(i).layerName)
        DrawRectEntity space, m.rects(i), targetLayer, isPreview
    Next i

    ' 2. Lines (step treads, hatch strokes, break line, arrows, cut line)
    For i = 0 To m.lineCount - 1
        targetLayer = IIf(isPreview, CSA_LAYER_PREVIEW, m.lines(i).layerName)
        DrawLineEntity space, m.lines(i), targetLayer, isPreview
    Next i

    ' 3. Circles (walking path start markers)
    For i = 0 To m.circleCount - 1
        targetLayer = IIf(isPreview, CSA_LAYER_PREVIEW, m.circles(i).layerName)
        DrawCircleEntity space, m.circles(i), targetLayer, isPreview
    Next i

    ' 4. Section cut symbols (native Daucat block when available, vector fallback otherwise)
    For i = 0 To m.cutSymCount - 1
        targetLayer = IIf(isPreview, CSA_LAYER_PREVIEW, m.cutSyms(i).layerName)
        DrawCutSymbolEntity space, m.cutSyms(i), targetLayer, isPreview, hasDaucat
    Next i

    ' 5. Texts (UP/DN, Plan title)
    For i = 0 To m.textCount - 1
        targetLayer = IIf(isPreview, CSA_LAYER_PREVIEW, m.texts(i).layerName)
        DrawTextEntity space, m.texts(i), targetLayer, isPreview
    Next i

    ' 6. Dimensions (native AddDimRotated using selected DimStyle)
    For i = 0 To m.dimCount - 1
        targetLayer = IIf(isPreview, CSA_LAYER_PREVIEW, m.dims(i).layerName)
        DrawDimEntity space, m.dims(i), targetLayer, isPreview, v.DimStyleName, hasDimStyle
    Next i
End Sub

Private Sub PrepareFinalPlanLayers(ByRef m As CSAPlanModel, ByVal allowCreate As Boolean)
    Dim i As Long
    CSA_EnsureLayer CSA_LAYER_PLAN, CSA_DefaultLayerColor(CSA_LAYER_PLAN), allowCreate
    For i = 0 To m.rectCount - 1
        CSA_EnsureLayer m.rects(i).layerName, CSA_DefaultLayerColor(m.rects(i).layerName), allowCreate
    Next i
    For i = 0 To m.lineCount - 1
        CSA_EnsureLayer m.lines(i).layerName, CSA_DefaultLayerColor(m.lines(i).layerName), allowCreate
    Next i
    For i = 0 To m.circleCount - 1
        CSA_EnsureLayer m.circles(i).layerName, CSA_DefaultLayerColor(m.circles(i).layerName), allowCreate
    Next i
    For i = 0 To m.textCount - 1
        CSA_EnsureLayer m.texts(i).layerName, CSA_DefaultLayerColor(m.texts(i).layerName), allowCreate
    Next i
    For i = 0 To m.cutSymCount - 1
        CSA_EnsureLayer m.cutSyms(i).layerName, CSA_DefaultLayerColor(m.cutSyms(i).layerName), allowCreate
    Next i
    For i = 0 To m.dimCount - 1
        CSA_EnsureLayer m.dims(i).layerName, CSA_DefaultLayerColor(m.dims(i).layerName), allowCreate
    Next i
End Sub

Private Sub DrawRectEntity(ByVal space As Object, ByRef r As CSAPlanRect, _
                           ByVal layerName As String, ByVal isPreview As Boolean)
    Dim coords(0 To 7) As Double, pl As Object
    coords(0) = r.x1: coords(1) = r.y1
    coords(2) = r.x2: coords(3) = r.y1
    coords(4) = r.x2: coords(5) = r.y2
    coords(6) = r.x1: coords(7) = r.y2
    Set pl = space.AddLightWeightPolyline(coords)
    pl.Closed = True
    ApplyByLayer pl, layerName, isPreview
End Sub

Private Sub DrawLineEntity(ByVal space As Object, ByRef seg As CSAPlanLine, _
                           ByVal layerName As String, ByVal isPreview As Boolean)
    Dim ent As Object
    Set ent = space.AddLine(CSA_Point3D(seg.x1, seg.y1, 0#), CSA_Point3D(seg.x2, seg.y2, 0#))
    ApplyByLayer ent, layerName, isPreview
End Sub

Private Sub DrawCircleEntity(ByVal space As Object, ByRef c As CSAPlanCircle, _
                             ByVal layerName As String, ByVal isPreview As Boolean)
    Dim ent As Object
    Set ent = space.AddCircle(CSA_Point3D(c.cx, c.cy, 0#), c.radius)
    ApplyByLayer ent, layerName, isPreview
End Sub

Private Sub DrawTextEntity(ByVal space As Object, ByRef t As CSAPlanText, _
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
    ApplyByLayer ent, layerName, isPreview
End Sub

Private Sub DrawCutSymbolEntity(ByVal space As Object, ByRef sym As CSAPlanCutSym, _
                                ByVal layerName As String, ByVal isPreview As Boolean, _
                                ByVal hasDaucat As Boolean)
    Dim ent As Object, pt As Variant
    pt = CSA_Point3D(sym.x, sym.y, 0#)
    If hasDaucat And Not isPreview Then
        On Error GoTo FallbackVector
        Set ent = CSA_InsertSectionSymbol(pt, sym.mark, 0.01)
        Exit Sub
    End If
FallbackVector:
    On Error GoTo 0
    ' Clean vector section arrow + mark fallback (for preview or blank DWGs without Daucat block)
    Set ent = space.AddLine(CSA_Point3D(sym.x, sym.y, 0#), CSA_Point3D(sym.x, sym.y + 180#, 0#))
    ApplyByLayer ent, layerName, isPreview
    Set ent = space.AddLine(CSA_Point3D(sym.x, sym.y + 180#, 0#), CSA_Point3D(sym.x - 55#, sym.y + 100#, 0#))
    ApplyByLayer ent, layerName, isPreview
    Set ent = space.AddLine(CSA_Point3D(sym.x, sym.y + 180#, 0#), CSA_Point3D(sym.x + 55#, sym.y + 100#, 0#))
    ApplyByLayer ent, layerName, isPreview
    Set ent = space.AddText(sym.mark, CSA_Point3D(sym.x - 45#, sym.y + 210#, 0#), 120#)
    ApplyByLayer ent, layerName, isPreview
End Sub

Private Sub DrawDimEntity(ByVal space As Object, ByRef d As CSAPlanDim, _
                          ByVal layerName As String, ByVal isPreview As Boolean, _
                          ByVal styleName As String, ByVal hasDimStyle As Boolean)
    Dim ent As Object
    Set ent = space.AddDimRotated(CSA_Point3D(d.x1, d.y1, 0#), _
                                  CSA_Point3D(d.x2, d.y2, 0#), _
                                  CSA_Point3D(d.locX, d.locY, 0#), _
                                  d.angleRad)
    If hasDimStyle Then
        On Error Resume Next
        ent.StyleName = styleName
        On Error GoTo 0
    End If
    ApplyByLayer ent, layerName, isPreview
    ent.Update
End Sub

Private Sub ApplyByLayer(ByVal ent As Object, ByVal layerName As String, ByVal isPreview As Boolean)
    ent.Layer = layerName
    ent.color = 256
    ent.Linetype = "ByLayer"
    ent.Lineweight = -1
    If isPreview Then CSA_MarkPreview ent
End Sub

Private Function BlockExists(ByVal doc As Object, ByVal blockName As String) As Boolean
    Dim obj As Object
    On Error Resume Next
    Set obj = doc.Blocks.Item(blockName)
    BlockExists = Not (obj Is Nothing)
    On Error GoTo 0
End Function

Private Function DimStyleExists(ByVal doc As Object, ByVal styleName As String) As Boolean
    Dim obj As Object
    If Len(Trim$(styleName)) = 0 Then Exit Function
    On Error Resume Next
    Set obj = doc.DimStyles.Item(styleName)
    DimStyleExists = Not (obj Is Nothing)
    On Error GoTo 0
End Function
