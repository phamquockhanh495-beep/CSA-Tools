Attribute VB_Name = "modCSAStairTypes"
Option Explicit

Public Const CSA_LAYER_PREVIEW As String = "CSA-PREVIEW"
Public Const CSA_LAYER_CONCRETE As String = "CSA-CONCRETE"
Public Const CSA_LAYER_REBAR As String = "CSA-REBAR"
Public Const CSA_LAYER_DIM As String = "CSA-DIM"
Public Const CSA_LAYER_TEXT As String = "CSA-TEXT"

Public Const CSA_VIEW_SECTION As String = "SECTION"
Public Const CSA_VIEW_PLAN As String = "PLAN"
Public CSA_RenderLayer As String

Public Sub CSA_InitRenderState()
    CSA_RenderLayer = CSA_LAYER_PREVIEW
End Sub

Public Type CSAStairInput
    StairName As String
    StairType As String
    FloorHeight As Double
    Width As Double
    Riser As Double
    Tread As Double
    Landing As Double
    Slab As Double
    InsertX As Double
    InsertY As Double
    Flight1Risers As Long
    Flight2Risers As Long
    DrawDimensions As Boolean
    PreviewRebar As Boolean
End Type

Public Type CSAFlight
    StartX As Double
    StartY As Double
    StartZ As Double
    Angle As Double
    RiserCount As Long
    Riser As Double
    Tread As Double
    Width As Double
    RunLength As Double
End Type

Public Type CSAPoint
    X As Double
    Y As Double
    Z As Double
End Type

Public Function CSA_DefaultInput() As CSAStairInput
    Dim v As CSAStairInput
    v.StairName = "ST-01"
    v.StairType = "2 FLIGHTS - U"
    v.FloorHeight = 3600#
    v.Width = 1200#
    v.Riser = 150#
    v.Tread = 300#
    v.Landing = 1500#
    v.Slab = 200#
    v.InsertX = 0#
    v.InsertY = 0#
    v.Flight1Risers = 12
    v.Flight2Risers = 12
    v.DrawDimensions = True
    v.PreviewRebar = False
    CSA_DefaultInput = v
End Function
