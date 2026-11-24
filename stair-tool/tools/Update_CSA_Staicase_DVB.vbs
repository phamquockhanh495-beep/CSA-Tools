Option Explicit

' 1-Click AutoCAD VBA Updater for CSA_Staicase.dvb (AutoCAD 2018-2027 x64)
' Double-click this file while AutoCAD is open (with CSA_Staicase.dvb loaded,
' or placed in the same folder as this script).
' Uses AutoCAD's own VBE7 engine so references (FM20.DLL), frmCSAStair and
' binary DVB integrity are preserved 100%.

Dim fso, scriptDir, acad, vbe, proj, dvbPath
Dim files, fileObj, fileName, ext, modName, comp
Dim updatedCount, addedCount, skippedCount, summary

Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)

On Error Resume Next
Set acad = GetObject(, "AutoCAD.Application")
On Error GoTo 0
If acad Is Nothing Then
    MsgBox "AutoCAD is not running." & vbCrLf & _
           "Please open AutoCAD (and load CSA_Staicase.dvb with VBALOAD/APPLOAD), then run this script again.", _
           vbExclamation, "CSA Stair DVB Updater"
    WScript.Quit 1
End If

On Error Resume Next
Set vbe = acad.VBE
On Error GoTo 0
If vbe Is Nothing Then
    MsgBox "Cannot access AutoCAD VBE. Make sure the Autodesk VBA Enabler is installed and run VBAIDE once.", _
           vbExclamation, "CSA Stair DVB Updater"
    WScript.Quit 1
End If

Set proj = FindStairProject(vbe)
If proj Is Nothing Then
    dvbPath = fso.BuildPath(scriptDir, "CSA_Staicase.dvb")
    If Not fso.FileExists(dvbPath) Then
        dvbPath = InputBox("CSA_Staicase.dvb is not loaded in AutoCAD." & vbCrLf & _
                           "Enter the full path to CSA_Staicase.dvb (or cancel and load it first via VBALOAD):", _
                           "CSA Stair DVB Updater", dvbPath)
        If Len(Trim(dvbPath)) = 0 Then WScript.Quit 0
    End If
    If Not fso.FileExists(dvbPath) Then
        MsgBox "File not found: " & dvbPath, vbExclamation, "CSA Stair DVB Updater"
        WScript.Quit 1
    End If
    On Error Resume Next
    acad.LoadDVB dvbPath
    If Err.Number <> 0 Then
        MsgBox "Failed to load DVB (" & Err.Number & "): " & Err.Description, vbExclamation, "CSA Stair DVB Updater"
        WScript.Quit 1
    End If
    On Error GoTo 0
    Set proj = FindStairProject(vbe)
End If

If proj Is Nothing Then
    MsgBox "Could not locate project CSA_Staicase / CSA_Staircase in AutoCAD VBE." & vbCrLf & _
           "Please open VBAIDE, verify CSA_Staicase.dvb is loaded, and try again.", _
           vbExclamation, "CSA Stair DVB Updater"
    WScript.Quit 1
End If

updatedCount = 0
addedCount = 0
skippedCount = 0

Set files = fso.GetFolder(scriptDir).Files
For Each fileObj In files
    fileName = fileObj.Name
    ext = LCase(fso.GetExtensionName(fileName))
    If (ext = "bas" Or ext = "cls") And LCase(fileName) <> "frmcsastair.code.bas" Then
        modName = ReadVbName(fileObj.Path)
        If Len(modName) > 0 Then
            Set comp = FindComponent(proj, modName)
            If Not comp Is Nothing Then
                ' Only replace Standard Module (1) or Class Module (2); never remove UserForm (3) or ThisDrawing (100).
                If comp.Type = 1 Or comp.Type = 2 Then
                    proj.VBComponents.Remove comp
                    proj.VBComponents.Import fileObj.Path
                    updatedCount = updatedCount + 1
                Else
                    skippedCount = skippedCount + 1
                End If
            Else
                proj.VBComponents.Import fileObj.Path
                addedCount = addedCount + 1
            End If
        End If
    End If
Next

' Open VBAIDE so user can compile and press Ctrl+S to save the binary .dvb cleanly.
On Error Resume Next
acad.ActiveDocument.SendCommand "_VBAIDE " & vbCr
On Error GoTo 0

summary = "Updated CSA_Staicase.dvb in AutoCAD successfully!" & vbCrLf & vbCrLf & _
          "  - Project: " & proj.Name & vbCrLf & _
          "  - Replaced modules/classes: " & updatedCount & vbCrLf & _
          "  - Added new modules/classes: " & addedCount & vbCrLf & _
          "  - Preserved form/document: frmCSAStair, ThisDrawing" & vbCrLf & vbCrLf & _
          "Next step in VBAIDE:" & vbCrLf & _
          "  1. Debug -> Compile" & vbCrLf & _
          "  2. Press Ctrl+S (File -> Save) to save CSA_Staicase.dvb" & vbCrLf & _
          "  3. Run CSA_STAIRDRAW in AutoCAD."

MsgBox summary, vbInformation, "CSA Stair DVB Updater"

Function FindStairProject(vbeObj)
    Dim p, fName, pName
    Set FindStairProject = Nothing
    On Error Resume Next
    For Each p In vbeObj.VBProjects
        pName = LCase(p.Name)
        fName = LCase(p.FileName)
        If pName = "csa_staicase" Or pName = "csa_staircase" Or _
           InStr(fName, "csa_staicase.dvb") > 0 Or InStr(fName, "csa_staircase.dvb") > 0 Then
            Set FindStairProject = p
            Exit Function
        End If
    Next
    On Error GoTo 0
End Function

Function FindComponent(projObj, targetName)
    Dim c
    Set FindComponent = Nothing
    On Error Resume Next
    For Each c In projObj.VBComponents
        If StrComp(c.Name, targetName, vbTextCompare) = 0 Then
            Set FindComponent = c
            Exit Function
        End If
    Next
    On Error GoTo 0
End Function

Function ReadVbName(filePath)
    Dim ts, lineText, q1, q2
    ReadVbName = ""
    Set ts = fso.OpenTextFile(filePath, 1, False)
    Do While Not ts.AtEndOfStream
        lineText = Trim(ts.ReadLine)
        If LCase(Left(lineText, 18)) = "attribute vb_name " Or LCase(Left(lineText, 18)) = "attribute vb_name=" Then
            q1 = InStr(lineText, """")
            If q1 > 0 Then
                q2 = InStr(q1 + 1, lineText, """")
                If q2 > q1 Then ReadVbName = Mid(lineText, q1 + 1, q2 - q1 - 1)
            End If
            Exit Do
        End If
    Loop
    ts.Close
End Function
