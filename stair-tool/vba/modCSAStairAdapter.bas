Attribute VB_Name = "modCSAStairAdapter"
Option Explicit

' Native CSA resources from csa-profile.json; no dependency on Excel or UDTs.
' Existing definitions are never recreated or restyled.

Public Function CSA_MissingStandards() As String
    Dim names As Variant, name As Variant, obj As Object, missing As String
    names = Array("06-GB-Slab-bor", "21-GB-BD", "04-GB-Dim", "10-GB-Text", _
                  "11-GB-Cao Do", "12-GB-Ky Hieu", "18-GB-Reinf", "20-GB-GC")
    For Each name In names
        Set obj = Nothing
        On Error Resume Next
        Set obj = ThisDrawing.Layers.Item(CStr(name))
        On Error GoTo 0
        If obj Is Nothing Then missing = missing & vbCrLf & "Layer: " & CStr(name)
    Next name
    names = Array("Cao do", "Daucat", "So hieu thep", "CSA_Sohieu-KCthep")
    For Each name In names
        Set obj = Nothing
        On Error Resume Next
        Set obj = ThisDrawing.Blocks.Item(CStr(name))
        On Error GoTo 0
        If obj Is Nothing Then missing = missing & vbCrLf & "Block: " & CStr(name)
    Next name
    names = Array("01-GB-Arial", "02-GB-VNI-Helve")
    For Each name In names
        Set obj = Nothing
        On Error Resume Next
        Set obj = ThisDrawing.TextStyles.Item(CStr(name))
        On Error GoTo 0
        If obj Is Nothing Then missing = missing & vbCrLf & "TextStyle: " & CStr(name)
    Next name
    CSA_MissingStandards = missing
End Function

Private Sub RequireWritableLayer(ByVal name As String)
    Dim layer As Object
    Set layer = ThisDrawing.Layers.Item(name)
    If layer.Lock Or layer.Freeze Or Not layer.LayerOn Then
        Err.Raise vbObjectError + 420, "CSA Adapter", "Layer off/frozen/locked: " & name
    End If
End Sub

Private Sub ApplyLayer(ByVal ent As Object, ByVal name As String)
    ent.Layer = name
    ent.color = 256
    ent.Linetype = "ByLayer"
    ent.Lineweight = -1
End Sub

Public Function CSA_InsertTaggedBlock(ByVal name As String, ByVal layer As String, _
    ByVal point As Variant, ByVal scale As Double, ByVal tags As Variant, _
    ByVal texts As Variant) As Object
    Dim definition As Object, obj As Object, attributes As Variant, att As Variant
    Dim expected As Object, i As Long, key As String
    Dim errorNumber As Long, errorText As String
    On Error GoTo Failed
    If scale <= 0# Then Err.Raise vbObjectError + 421, , "Block scale must be positive."
    Set definition = ThisDrawing.Blocks.Item(name)
    RequireWritableLayer layer
    If UBound(tags) - LBound(tags) <> UBound(texts) - LBound(texts) Then
        Err.Raise vbObjectError + 422, , "Tag and value counts differ."
    End If
    Set expected = CreateObject("Scripting.Dictionary")
    expected.CompareMode = 1
    For i = LBound(tags) To UBound(tags)
        expected.Add CStr(tags(i)), CStr(texts(i - LBound(tags) + LBound(texts)))
    Next i
    Set obj = ThisDrawing.ModelSpace.InsertBlock(point, name, scale, scale, scale, 0#)
    ApplyLayer obj, layer
    If obj.HasAttributes Then
        attributes = obj.GetAttributes
        For Each att In attributes
            key = CStr(att.TagString)
            If expected.Exists(key) Then
                att.TextString = expected(key)
                expected.Remove key
            End If
        Next att
    End If
    If expected.Count <> 0 Then
        Err.Raise vbObjectError + 423, "CSA Adapter", "Missing editable tags in block: " & name
    End If
    obj.Update
    Set CSA_InsertTaggedBlock = obj
    Exit Function
Failed:
    errorNumber = Err.Number: errorText = Err.Description
    On Error Resume Next
    If Not obj Is Nothing Then obj.Delete
    On Error GoTo 0
    Err.Raise errorNumber, "CSA Adapter", errorText
End Function

Public Function CSA_InsertElevation(ByVal point As Variant, ByVal value As String, _
                                    Optional ByVal scale As Double = 0.35) As Object
    Set CSA_InsertElevation = CSA_InsertTaggedBlock("Cao do", "11-GB-Cao Do", _
        point, scale, Array("%%P0.000"), Array(value))
End Function

Public Function CSA_InsertSectionSymbol(ByVal point As Variant, ByVal value As String, _
                                        Optional ByVal scale As Double = 1#) As Object
    Set CSA_InsertSectionSymbol = CSA_InsertTaggedBlock("Daucat", "12-GB-Ky Hieu", _
        point, scale, Array("A"), Array(value))
End Function

Public Function CSA_InsertBarNote(ByVal point As Variant, ByVal mark As String, _
    ByVal diameterSpacing As String, Optional ByVal scale As Double = 1#) As Object
    Set CSA_InsertBarNote = CSA_InsertTaggedBlock("CSA_Sohieu-KCthep", "20-GB-GC", _
        point, scale, Array("SH", "DK-KC"), Array(mark, diameterSpacing))
End Function

Public Function CSA_InsertBarMark(ByVal point As Variant, ByVal mark As String, _
                                  Optional ByVal scale As Double = 1#) As Object
    Set CSA_InsertBarMark = CSA_InsertTaggedBlock("So hieu thep", "20-GB-GC", _
        point, scale, Array("A"), Array(mark))
End Function

Public Function CSA_AddAlignedDimension(ByVal first As Variant, ByVal last As Variant, _
    ByVal location As Variant, ByVal styleName As String) As Object
    Dim style As Object, obj As Object, errorNumber As Long, errorText As String
    On Error GoTo Failed
    Set style = ThisDrawing.DimStyles.Item(styleName)
    RequireWritableLayer "04-GB-Dim"
    Set obj = ThisDrawing.ModelSpace.AddDimAligned(first, last, location)
    obj.StyleName = style.Name
    ApplyLayer obj, "04-GB-Dim"
    obj.Update
    Set CSA_AddAlignedDimension = obj
    Exit Function
Failed:
    errorNumber = Err.Number: errorText = Err.Description
    On Error Resume Next
    If Not obj Is Nothing Then obj.Delete
    On Error GoTo 0
    Err.Raise errorNumber, "CSA Adapter", errorText
End Function
