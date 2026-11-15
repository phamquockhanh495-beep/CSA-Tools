Attribute VB_Name = "modCSAStairHost"
Option Explicit

' Shared source target: full AutoCAD for Windows x64, releases 2018-2026.
' No external AutoCAD.Application ProgID: always use the hosting VBA session.
Public Const CSA_PRIMARY_CAD_YEAR As Long = 2022
Public Const CSA_AC_ACTIVE_VIEWPORT As Long = 0
Public Const CSA_AC_ALL_VIEWPORTS As Long = 1

Public Function CSA_AcadReleaseYear(ByVal acadVersion As String) As Long
    Dim prefix As String, ch As String, parts As Variant, i As Long
    acadVersion = Trim$(acadVersion)
    For i = 1 To Len(acadVersion)
        ch = Mid$(acadVersion, i, 1)
        If (ch >= "0" And ch <= "9") Or ch = "." Then
            prefix = prefix & ch
        Else
            Exit For
        End If
    Next i
    If Len(prefix) = 0 Then Exit Function
    parts = Split(prefix, ".")
    If UBound(parts) < 1 Then Exit Function
    Select Case CStr(parts(0)) & "." & CStr(parts(1))
        Case "22.0": CSA_AcadReleaseYear = 2018
        Case "23.0": CSA_AcadReleaseYear = 2019
        Case "23.1": CSA_AcadReleaseYear = 2020
        Case "24.0": CSA_AcadReleaseYear = 2021
        Case "24.1": CSA_AcadReleaseYear = 2022
        Case "24.2": CSA_AcadReleaseYear = 2023
        Case "24.3": CSA_AcadReleaseYear = 2024
        Case "25.0": CSA_AcadReleaseYear = 2025
        Case "25.1": CSA_AcadReleaseYear = 2026
    End Select
End Function

Public Function CSA_Is64BitVba() As Boolean
#If VBA7 And Win64 Then
    CSA_Is64BitVba = True
#Else
    CSA_Is64BitVba = False
#End If
End Function

Public Function CSA_HostProblem(ByVal document As Object) As String
    Dim release As Long, space As Object, value As Variant
    On Error GoTo Failed
    If Not CSA_Is64BitVba() Then
        CSA_HostProblem = "Requires Windows x64 AutoCAD with VBA7. Install the matching VBA Enabler."
        Exit Function
    End If
    If document Is Nothing Then
        CSA_HostProblem = "No AutoCAD drawing is available."
        Exit Function
    End If
    value = document.GetVariable("ACADVER")
    release = CSA_AcadReleaseYear(CStr(value))
    If release = 0 Then
        CSA_HostProblem = "Unsupported ACADVER: " & CStr(value) & ". Target range is AutoCAD 2018-2026."
        Exit Function
    End If
    Set space = document.ModelSpace
    value = document.Layers.Count
    value = document.Blocks.Count
    value = document.DimStyles.Count
    Exit Function
Failed:
    CSA_HostProblem = "AutoCAD ActiveX access failed (" & CStr(Err.Number) & "): " & Err.Description
End Function

Public Function CSA_CadDocument() As Object
    Dim document As Object, issue As String
    Set document = ThisDrawing
    issue = CSA_HostProblem(document)
    If Len(issue) > 0 Then Err.Raise vbObjectError + 460, "CSA Host", issue
    Set CSA_CadDocument = document
End Function

Public Sub CSA_RequireSupportedHost()
    Dim document As Object
    Set document = CSA_CadDocument()
End Sub

Public Function CSA_HostReady() As Boolean
    Dim document As Object
    On Error GoTo Failed
    Set document = CSA_CadDocument()
    CSA_HostReady = True
    Exit Function
Failed:
    MsgBox Err.Description, vbExclamation, "CSA AutoCAD compatibility"
End Function

Public Function CSA_Point3D(ByVal x As Double, ByVal y As Double, _
                            Optional ByVal z As Double = 0#) As Variant
    ' ActiveX point arguments require SAFEARRAY(Double), not Array(Variant).
    Dim point(0 To 2) As Double
    point(0) = x: point(1) = y: point(2) = z
    CSA_Point3D = point
End Function

Public Function CSA_HostDescription(ByVal document As Object) As String
    Dim issue As String, version As String
    issue = CSA_HostProblem(document)
    If Len(issue) > 0 Then
        CSA_HostDescription = issue
        Exit Function
    End If
    version = CStr(document.GetVariable("ACADVER"))
    CSA_HostDescription = "AutoCAD " & CStr(CSA_AcadReleaseYear(version)) & _
        " / ACADVER " & version & vbCrLf & "Windows x64 / VBA7" & vbCrLf & _
        "Host API accessible; native drawing/UI tests still required."
End Function

Public Sub CSA_CheckCompatibility()
    Dim document As Object
    On Error GoTo Failed
    Set document = ThisDrawing
    Debug.Print CSA_HostDescription(document)
    MsgBox CSA_HostDescription(document), vbInformation, "CSA compatibility report"
    Exit Sub
Failed:
    MsgBox Err.Description, vbExclamation, "CSA compatibility report"
End Sub
