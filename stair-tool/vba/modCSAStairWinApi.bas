Attribute VB_Name = "modCSAStairWinApi"
Option Explicit

' Pointer/handle arguments use LongPtr; Win32 LONG/int values remain Long.
' The fallback declarations allow parsing in older VBA, but Host rejects x86.
#If VBA7 Then
    Private Declare PtrSafe Function GetDC Lib "user32" (ByVal hwnd As LongPtr) As LongPtr
    Private Declare PtrSafe Function ReleaseDC Lib "user32" (ByVal hwnd As LongPtr, ByVal hdc As LongPtr) As Long
    Private Declare PtrSafe Function GetDeviceCaps Lib "gdi32" (ByVal hdc As LongPtr, ByVal index As Long) As Long
#Else
    Private Declare Function GetDC Lib "user32" (ByVal hwnd As Long) As Long
    Private Declare Function ReleaseDC Lib "user32" (ByVal hwnd As Long, ByVal hdc As Long) As Long
    Private Declare Function GetDeviceCaps Lib "gdi32" (ByVal hdc As Long, ByVal index As Long) As Long
#End If

Private Const LOGPIXELSX As Long = 88

Public Function CSA_SystemDpiX() As Double
    ' System DPI baseline only; this is not per-monitor DPI awareness.
#If VBA7 Then
    Dim hdc As LongPtr
#Else
    Dim hdc As Long
#End If
    Dim dpi As Long, errorNumber As Long, errorText As String
    On Error GoTo Failed
    hdc = GetDC(0)
    If hdc = 0 Then Err.Raise vbObjectError + 470, , "Cannot acquire screen DC."
    dpi = GetDeviceCaps(hdc, LOGPIXELSX)
    ReleaseDC 0, hdc
    hdc = 0
    If dpi <= 0 Then Err.Raise vbObjectError + 471, , "Invalid system DPI."
    CSA_SystemDpiX = CDbl(dpi)
    Exit Function
Failed:
    errorNumber = Err.Number: errorText = Err.Description
    If hdc <> 0 Then ReleaseDC 0, hdc
    Err.Raise errorNumber, "CSA Windows API", errorText
End Function

Public Function CSA_PixelsToFormPoints(ByVal pixels As Double) As Double
    ' MSForms uses points: 72 points per inch. AutoCAD model units stay in mm.
    CSA_PixelsToFormPoints = pixels * 72# / CSA_SystemDpiX()
End Function
