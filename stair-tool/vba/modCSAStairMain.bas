Attribute VB_Name = "modCSAStairMain"
Option Explicit

Public gCSAStair As CSAStairInput

Public Sub CSA_StairTools()
    gCSAStair = CSA_DefaultInput()
    Load frmCSAStair
    frmCSAStair.Show
End Sub

Public Sub CSA_STAIRDRAW()
    CSA_StairTools
End Sub

Public Sub CSA_STAIRPREVIEW()
    If Len(gCSAStair.StairName) = 0 Then gCSAStair = CSA_DefaultInput()
    CSA_RenderPreview gCSAStair
End Sub

Public Sub CSA_StairPreviewCommand()
    If Len(gCSAStair.StairName) = 0 Then gCSAStair = CSA_DefaultInput()
    CSA_RenderPreview gCSAStair
End Sub
