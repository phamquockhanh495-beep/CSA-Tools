VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "clsCSAStairFieldWatcher"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Explicit

Private WithEvents mBox As MSForms.TextBox
Private mOwner As clsCSAStairFormController
Private mKey As String

Public Sub Bind(ByVal ctrlBox As MSForms.TextBox, _
                ByVal owner As clsCSAStairFormController, _
                ByVal fieldKey As String)
    Set mBox = ctrlBox
    Set mOwner = owner
    mKey = fieldKey
End Sub

Public Sub Unbind()
    Set mBox = Nothing
    Set mOwner = Nothing
End Sub

Private Sub mBox_Change()
    If Not mOwner Is Nothing Then mOwner.OnFieldChanged mKey
End Sub
