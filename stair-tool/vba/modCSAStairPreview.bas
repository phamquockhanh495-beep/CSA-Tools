Attribute VB_Name = "modCSAStairPreview"
Option Explicit

Public Sub CSA_RenderPreview(ByRef v As CSAStairInput)
    Dim message As String
    If Not CSA_ValidateInput(v, message) Then
        MsgBox message, vbExclamation, "CSA Stair Drawing"
        Exit Sub
    End If
    CSA_InitRenderState
    CSA_RenderLayer = CSA_LAYER_PREVIEW
    CSA_EnsureLayers
    CSA_ClearPreview
    CSA_BuildSectionPreview v
    CSA_BuildPlanPreview v
    ThisDrawing.Regen acActiveViewport
    ThisDrawing.Application.ZoomExtents
End Sub

Public Sub CSA_DrawSectionFinal(ByRef v As CSAStairInput)
    Dim message As String
    If Not CSA_ValidateInput(v, message) Then
        MsgBox message, vbExclamation, "CSA Stair Drawing"
        Exit Sub
    End If
    CSA_InitRenderState
    CSA_RenderLayer = CSA_LAYER_CONCRETE
    CSA_EnsureLayer CSA_LAYER_CONCRETE, 90
    CSA_ClearPreview
    CSA_BuildSectionPreview v
    ThisDrawing.Regen acActiveViewport
End Sub

Public Sub CSA_DrawPlanFinal(ByRef v As CSAStairInput)
    Dim message As String
    If Not CSA_ValidateInput(v, message) Then
        MsgBox message, vbExclamation, "CSA Stair Drawing"
        Exit Sub
    End If
    CSA_InitRenderState
    CSA_RenderLayer = CSA_LAYER_PLAN
    CSA_EnsureLayer CSA_LAYER_PLAN, 150
    CSA_ClearPreview
    CSA_BuildPlanPreview v
    ThisDrawing.Regen acActiveViewport
End Sub
