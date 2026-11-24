Attribute VB_Name = "modCSAStairTypes"
Option Explicit

' Native CSA layer names (migrated from GB -> CSA per CSA Drawing Data standard).
Public Const CSA_LAYER_PREVIEW As String = "CSA-PREVIEW"
Public Const CSA_LAYER_GRID As String = "01-CSA-Grid"
Public Const CSA_LAYER_DIM As String = "04-CSA-Dim"
Public Const CSA_LAYER_HATCH As String = "05-CSA-Hatch"
Public Const CSA_LAYER_PLAN As String = "06-CSA-Slab-bor"
Public Const CSA_LAYER_BEAM As String = "09-CSA-Beam"
Public Const CSA_LAYER_TEXT As String = "10-CSA-Text"
Public Const CSA_LAYER_LEVEL As String = "11-CSA-Cao Do"
Public Const CSA_LAYER_SYMBOL As String = "12-CSA-Ky hieu"
Public Const CSA_LAYER_REBAR As String = "18-CSA-Reinf"
Public Const CSA_LAYER_TIE As String = "19-CSA-Tie"
Public Const CSA_LAYER_NOTE As String = "20-CSA-GC"
Public Const CSA_LAYER_CONCRETE As String = "21-CSA-BD"
Public Const CSA_LAYER_CUT As String = "22-CSA-NC"
Public Const CSA_PREVIEW_APP As String = "CSA_STAIR_PREVIEW"

Public Const CSA_VIEW_SECTION As String = "SECTION"
Public Const CSA_VIEW_PLAN As String = "PLAN"

Public Const CSA_TYPE_TWO_FLIGHT As String = "Two Flight (With Landing)"
Public Const CSA_TYPE_THREE_FLIGHT As String = "Three Flight"
Public Const CSA_TYPE_SINGLE_FLIGHT As String = "Single Flight"

Public CSA_RenderLayer As String

Public Type CSAStairInput
    StairName As String
    StairType As String
    FloorHeight As Double
    BottomElevation As Double
    TopElevation As Double
    Width As Double
    Riser As Double
    Tread As Double
    Landing As Double
    UpperLanding As Double
    WellGap As Double
    SupportWidth As Double
    Slab As Double
    ScaleText As String
    DimStyleName As String
    SectionMark As String
    StartDirection As String
    InsertX As Double
    InsertY As Double
    Flight1Risers As Long
    Flight2Risers As Long
    Flight3Risers As Long
    DrawDimensions As Boolean
    PreviewRebar As Boolean
    CreateLayers As Boolean
    OpenExcel As Boolean
    ExcelPath As String
    ' Rebar & structural section detailing parameters
    CoverMm As Double
    LowerLandingBotBar As String
    LowerLandingTopBar As String
    FlightBotBar As String
    FlightTopBar As String
    DistBar As String
    RebarLayers As Long
    AnchorFactor As Double
    StartBarMark As Long
    BarSymbol As String
    BeamDownstand As Double
    ' Optional 24-point Excel contract payload (Cau Thang Tools)
    HasExcelCoords As Boolean
    ExcelPointCount As Long
    ExcelRawX(0 To 23) As Double
    ExcelRawY(0 To 23) As Double
    ExcelLowerSteps As Long
    ExcelFlightSteps As Long
    HasUpperLandingBars As Boolean
    HasLowerLandingBars As Boolean
    HasUpperLandingDots As Boolean
    HasLowerLandingDots As Boolean
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

Public Sub CSA_InitRenderState()
    CSA_RenderLayer = CSA_LAYER_PREVIEW
End Sub

Public Function CSA_DefaultInput() As CSAStairInput
    Dim v As CSAStairInput
    v.StairName = "ST-01"
    v.StairType = CSA_TYPE_TWO_FLIGHT
    v.BottomElevation = 0#
    v.TopElevation = 3.6
    v.FloorHeight = 3600#
    v.Width = 1200#
    v.Riser = 150#
    v.Tread = 300#
    v.Landing = 1500#
    v.UpperLanding = 1500#
    v.WellGap = 200#
    v.SupportWidth = 200#
    v.Slab = 200#
    v.ScaleText = "1:50"
    v.DimStyleName = "GB 25"
    v.SectionMark = "A"
    v.StartDirection = "UP"
    v.InsertX = 0#
    v.InsertY = 0#
    v.Flight1Risers = 12
    v.Flight2Risers = 12
    v.Flight3Risers = 0
    v.DrawDimensions = True
    v.PreviewRebar = True
    v.CreateLayers = True
    v.OpenExcel = False
    v.ExcelPath = ""
    v.CoverMm = 25#
    v.LowerLandingBotBar = "12a150"
    v.LowerLandingTopBar = "12a150"
    v.FlightBotBar = "12a150"
    v.FlightTopBar = "12a150"
    v.DistBar = "10a200"
    v.RebarLayers = 2
    v.AnchorFactor = 30#
    v.StartBarMark = 1
    v.BarSymbol = "%%C"
    v.BeamDownstand = 250#
    v.HasExcelCoords = False
    v.ExcelPointCount = 0
    v.ExcelLowerSteps = 0
    v.ExcelFlightSteps = 12
    v.HasUpperLandingBars = True
    v.HasLowerLandingBars = True
    v.HasUpperLandingDots = True
    v.HasLowerLandingDots = True
    CSA_DefaultInput = v
End Function

Public Function CSA_TotalRisers(ByRef v As CSAStairInput) As Long
    Select Case v.StairType
        Case CSA_TYPE_SINGLE_FLIGHT
            CSA_TotalRisers = v.Flight1Risers
        Case CSA_TYPE_THREE_FLIGHT
            CSA_TotalRisers = v.Flight1Risers + v.Flight2Risers + v.Flight3Risers
        Case Else
            CSA_TotalRisers = v.Flight1Risers + v.Flight2Risers
    End Select
End Function

Public Sub CSA_DistributeRisers(ByRef v As CSAStairInput)
    Dim total As Long
    If v.Riser <= 0# Or v.FloorHeight <= 0# Then Exit Sub
    total = CLng(Int(v.FloorHeight / v.Riser + 0.5))
    If total < 1 Then total = 1
    Select Case v.StairType
        Case CSA_TYPE_SINGLE_FLIGHT
            v.Flight1Risers = total
            v.Flight2Risers = 0
            v.Flight3Risers = 0
        Case CSA_TYPE_THREE_FLIGHT
            v.Flight1Risers = CLng(Int(total / 3#))
            If v.Flight1Risers < 1 Then v.Flight1Risers = 1
            v.Flight2Risers = CLng(Int((total - v.Flight1Risers) / 2#))
            If v.Flight2Risers < 1 Then v.Flight2Risers = 1
            v.Flight3Risers = total - v.Flight1Risers - v.Flight2Risers
            If v.Flight3Risers < 1 Then v.Flight3Risers = 1
        Case Else
            v.Flight1Risers = CLng(Int(total / 2#))
            If v.Flight1Risers < 1 Then v.Flight1Risers = 1
            v.Flight2Risers = total - v.Flight1Risers
            If v.Flight2Risers < 1 Then v.Flight2Risers = 1
            v.Flight3Risers = 0
    End Select
End Sub
