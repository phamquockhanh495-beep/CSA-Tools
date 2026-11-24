Attribute VB_Name = "frmCSAStair"
Option Explicit

' Paste this code into a blank UserForm named "frmCSAStair" in AutoCAD VBAIDE.
' All controls, mockup layout, manual Plan inputs and 2D GDI previews are built
' dynamically by clsCSAStairFormController (no manual control dragging or .frx).

Private mController As clsCSAStairFormController

Private Sub UserForm_Initialize()
    Set mController = New clsCSAStairFormController
    mController.Attach Me
    ' Uncomment only after importing the existing CSA theme and button class:
    ' ApplyCSAThemeEx Me, "Stair Drawing", "CSA TOOLS  |  STAIR DRAWING"
End Sub

Private Sub UserForm_Activate()
    If Not mController Is Nothing Then mController.RefreshPreview
End Sub

Private Sub UserForm_Terminate()
    If Not mController Is Nothing Then mController.Detach
    Set mController = Nothing
End Sub
