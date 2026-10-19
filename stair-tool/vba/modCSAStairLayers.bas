Attribute VB_Name = "modCSAStairLayers"
Option Explicit

Public Sub CSA_EnsureLayer(ByVal layerName As String, ByVal colorIndex As Integer)
    Dim lyr As Object
    On Error Resume Next
    Set lyr = ThisDrawing.Layers.Item(layerName)
    On Error GoTo 0
    If lyr Is Nothing Then
        Set lyr = ThisDrawing.Layers.Add(layerName)
    End If
    lyr.color = colorIndex
End Sub

Public Sub CSA_EnsureLayers()
    CSA_EnsureLayer CSA_LAYER_PREVIEW, 4
    CSA_EnsureLayer CSA_LAYER_CONCRETE, 7
    CSA_EnsureLayer CSA_LAYER_REBAR, 1
    CSA_EnsureLayer CSA_LAYER_DIM, 3
    CSA_EnsureLayer CSA_LAYER_TEXT, 2
End Sub

Public Sub CSA_ClearPreview()
    Dim toDelete As Collection
    Dim ent As Object
    Dim item As Variant
    Set toDelete = New Collection

    For Each ent In ThisDrawing.ModelSpace
        On Error Resume Next
        If UCase$(ent.Layer) = UCase$(CSA_LAYER_PREVIEW) Then toDelete.Add ent
        On Error GoTo 0
    Next ent

    For Each item In toDelete
        On Error Resume Next
        item.Delete
        On Error GoTo 0
    Next item
    ThisDrawing.Regen acActiveViewport
End Sub

Public Sub CSA_CleanPreviewCommand()
    CSA_ClearPreview
    MsgBox "CSA preview cleared.", vbInformation, "CSA Stair Drawing"
End Sub
