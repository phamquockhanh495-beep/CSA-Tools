Attribute VB_Name = "modCSAStairPreview"
Option Explicit

Public Sub CSA_RenderPreview(ByRef v As CSAStairInput)
    Dim message As String
    If Not CSA_HostReady() Then Exit Sub
    If Not CSA_ValidateInput(v, message) Then
        MsgBox message, vbExclamation, "CSA Stair Drawing"
        Exit Sub
    End If
    CSA_InitRenderState
    CSA_RenderLayer = CSA_LAYER_PREVIEW
    CSA_EnsureLayers
    CSA_ClearPreview
    CSA_BuildSectionPreview v
    ' Draw full Plan View preview offset above Section preview to avoid overlap
    Dim planInput As CSAStairInput
    planInput = v
    planInput.InsertY = v.InsertY + v.FloorHeight + 1600#
    CSA_DrawPlanModel planInput, True
    ThisDrawing.Regen CSA_AC_ACTIVE_VIEWPORT
    ThisDrawing.Application.ZoomExtents
End Sub

Public Sub CSA_DrawSectionFinal(ByRef v As CSAStairInput)
    Dim message As String
    If Not CSA_HostReady() Then Exit Sub
    If Not CSA_ValidateInput(v, message) Then
        MsgBox message, vbExclamation, "CSA Stair Drawing"
        Exit Sub
    End If
    CSA_InitRenderState
    CSA_RenderLayer = CSA_LAYER_CONCRETE
    CSA_EnsureLayer CSA_LAYER_CONCRETE, CSA_DefaultLayerColor(CSA_LAYER_CONCRETE), v.CreateLayers
    CSA_ClearPreview
    CSA_BuildSectionPreview v
    ThisDrawing.Regen CSA_AC_ACTIVE_VIEWPORT
End Sub

Public Sub CSA_DrawPlanFinal(ByRef v As CSAStairInput)
    Dim message As String
    If Not CSA_HostReady() Then Exit Sub
    If Not CSA_ValidateInput(v, message) Then
        MsgBox message, vbExclamation, "CSA Stair Drawing"
        Exit Sub
    End If
    CSA_InitRenderState
    CSA_RenderLayer = CSA_LAYER_PLAN
    CSA_EnsureLayer CSA_LAYER_PLAN, CSA_DefaultLayerColor(CSA_LAYER_PLAN), v.CreateLayers
    CSA_ClearPreview
    CSA_DrawPlanModel v, False
    ThisDrawing.Regen CSA_AC_ACTIVE_VIEWPORT
End Sub
