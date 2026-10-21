Attribute VB_Name = "modCSAStairLayers"
Option Explicit

Public Sub CSA_EnsureLayer(ByVal layerName As String, ByVal colorIndex As Integer)
    Dim lyr As Object
    On Error Resume Next
    Set lyr = ThisDrawing.Layers.Item(layerName)
    On Error GoTo 0
    If lyr Is Nothing Then
        If layerName <> CSA_LAYER_PREVIEW Then
            Err.Raise vbObjectError + 410, "CSA Stair", "Missing CSA layer: " & layerName
        End If
        Set lyr = ThisDrawing.Layers.Add(layerName)
        lyr.color = colorIndex
        lyr.Plottable = False
    End If
    If lyr.Lock Or lyr.Freeze Or Not lyr.LayerOn Then
        Err.Raise vbObjectError + 411, "CSA Stair", "Layer off, frozen or locked: " & layerName
    End If
End Sub

Public Sub CSA_EnsureLayers()
    CSA_EnsureLayer CSA_LAYER_PREVIEW, 4
    ' Preview needs only one temporary layer. Existing CSA definitions stay intact.
End Sub

Public Sub CSA_MarkPreview(ByVal ent As Object)
    Dim app As Object, codes(0 To 1) As Integer, values(0 To 1) As Variant
    If ent.Layer <> CSA_LAYER_PREVIEW Then Exit Sub
    On Error Resume Next
    Set app = ThisDrawing.RegisteredApplications.Item(CSA_PREVIEW_APP)
    On Error GoTo 0
    If app Is Nothing Then Set app = ThisDrawing.RegisteredApplications.Add(CSA_PREVIEW_APP)
    codes(0) = 1001: values(0) = CSA_PREVIEW_APP
    codes(1) = 1000: values(1) = "v1"
    ent.SetXData codes, values
End Sub

Private Function CSA_IsPreview(ByVal ent As Object) As Boolean
    Dim codes As Variant, values As Variant
    If ent.Layer <> CSA_LAYER_PREVIEW Then Exit Function
    ent.GetXData CSA_PREVIEW_APP, codes, values
    If IsArray(codes) Then CSA_IsPreview = True
End Function

Public Sub CSA_ClearPreview()
    Dim toDelete As Collection
    Dim ent As Object
    Dim item As Variant
    Set toDelete = New Collection

    For Each ent In ThisDrawing.ModelSpace
        If CSA_IsPreview(ent) Then toDelete.Add ent
    Next ent

    For Each item In toDelete
        item.Delete
    Next item
    ThisDrawing.Regen acActiveViewport
End Sub

Public Sub CSA_CleanPreviewCommand()
    CSA_ClearPreview
    MsgBox "CSA preview cleared.", vbInformation, "CSA Stair Drawing"
End Sub
