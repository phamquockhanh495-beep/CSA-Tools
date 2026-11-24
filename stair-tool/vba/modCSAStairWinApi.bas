Attribute VB_Name = "modCSAStairWinApi"
Option Explicit

' Pointer/handle arguments use LongPtr; Win32 LONG/int values remain Long.
' The fallback declarations allow parsing in older VBA, but Host rejects x86.

Private Type CSA_Rect
    Left As Long
    Top As Long
    Right As Long
    Bottom As Long
End Type

Private Type CSA_Guid
    Data1 As Long
    Data2 As Integer
    Data3 As Integer
    Data4(0 To 7) As Byte
End Type

#If VBA7 Then
    Private Type CSA_PictDescBmp
        cbSizeOfStruct As Long
        picType As Long
        hBitmap As LongPtr
        hPal As LongPtr
    End Type

    Private Type CSA_OpenFileNameW
        lStructSize As Long
        hwndOwner As LongPtr
        hInstance As LongPtr
        lpstrFilter As LongPtr
        lpstrCustomFilter As LongPtr
        nMaxCustFilter As Long
        nFilterIndex As Long
        lpstrFile As LongPtr
        nMaxFile As Long
        lpstrFileTitle As LongPtr
        nMaxFileTitle As Long
        lpstrInitialDir As LongPtr
        lpstrTitle As LongPtr
        Flags As Long
        nFileOffset As Integer
        nFileExtension As Integer
        lpstrDefExt As LongPtr
        lCustData As LongPtr
        lpfnHook As LongPtr
        lpTemplateName As LongPtr
        pvReserved As LongPtr
        dwReserved As Long
        FlagsEx As Long
    End Type

    Public Type CSA_GdiCanvas
        memDC As LongPtr
        hBitmap As LongPtr
        oldBitmap As LongPtr
        widthPx As Long
        heightPx As Long
    End Type

    Private Declare PtrSafe Function GetDC Lib "user32" (ByVal hwnd As LongPtr) As LongPtr
    Private Declare PtrSafe Function ReleaseDC Lib "user32" (ByVal hwnd As LongPtr, ByVal hdc As LongPtr) As Long
    Private Declare PtrSafe Function GetDeviceCaps Lib "gdi32" (ByVal hdc As LongPtr, ByVal index As Long) As Long
    Private Declare PtrSafe Function CreateCompatibleDC Lib "gdi32" (ByVal hdc As LongPtr) As LongPtr
    Private Declare PtrSafe Function DeleteDC Lib "gdi32" (ByVal hdc As LongPtr) As Long
    Private Declare PtrSafe Function CreateCompatibleBitmap Lib "gdi32" (ByVal hdc As LongPtr, ByVal nWidth As Long, ByVal nHeight As Long) As LongPtr
    Private Declare PtrSafe Function SelectObject Lib "gdi32" (ByVal hdc As LongPtr, ByVal hObject As LongPtr) As LongPtr
    Private Declare PtrSafe Function DeleteObject Lib "gdi32" (ByVal hObject As LongPtr) As Long
    Private Declare PtrSafe Function GetStockObject Lib "gdi32" (ByVal nIndex As Long) As LongPtr
    Private Declare PtrSafe Function CreatePen Lib "gdi32" (ByVal nPenStyle As Long, ByVal nWidth As Long, ByVal crColor As Long) As LongPtr
    Private Declare PtrSafe Function CreateSolidBrush Lib "gdi32" (ByVal crColor As Long) As LongPtr
    Private Declare PtrSafe Function CreateFontW Lib "gdi32" ( _
        ByVal nHeight As Long, ByVal nWidth As Long, ByVal nEscapement As Long, _
        ByVal nOrientation As Long, ByVal fnWeight As Long, ByVal fdwItalic As Long, _
        ByVal fdwUnderline As Long, ByVal fdwStrikeOut As Long, ByVal fdwCharSet As Long, _
        ByVal fdwOutputPrecision As Long, ByVal fdwClipPrecision As Long, _
        ByVal fdwQuality As Long, ByVal fdwPitchAndFamily As Long, _
        ByVal lpszFace As LongPtr) As LongPtr
    Private Declare PtrSafe Function SetBkMode Lib "gdi32" (ByVal hdc As LongPtr, ByVal iBkMode As Long) As Long
    Private Declare PtrSafe Function SetTextColor Lib "gdi32" (ByVal hdc As LongPtr, ByVal crColor As Long) As Long
    Private Declare PtrSafe Function SetTextAlign Lib "gdi32" (ByVal hdc As LongPtr, ByVal fMode As Long) As Long
    Private Declare PtrSafe Function FillRect Lib "user32" (ByVal hdc As LongPtr, ByRef lpRect As CSA_Rect, ByVal hBrush As LongPtr) As Long
    Private Declare PtrSafe Function Rectangle Lib "gdi32" (ByVal hdc As LongPtr, ByVal nLeftRect As Long, ByVal nTopRect As Long, ByVal nRightRect As Long, ByVal nBottomRect As Long) As Long
    Private Declare PtrSafe Function MoveToEx Lib "gdi32" (ByVal hdc As LongPtr, ByVal x As Long, ByVal y As Long, ByVal lpPoint As LongPtr) As Long
    Private Declare PtrSafe Function LineTo Lib "gdi32" (ByVal hdc As LongPtr, ByVal nXEnd As Long, ByVal nYEnd As Long) As Long
    Private Declare PtrSafe Function Ellipse Lib "gdi32" (ByVal hdc As LongPtr, ByVal nLeftRect As Long, ByVal nTopRect As Long, ByVal nRightRect As Long, ByVal nBottomRect As Long) As Long
    Private Declare PtrSafe Function TextOutW Lib "gdi32" (ByVal hdc As LongPtr, ByVal nXStart As Long, ByVal nYStart As Long, ByVal lpString As LongPtr, ByVal cbString As Long) As Long
    Private Declare PtrSafe Function GetOpenFileNameW Lib "comdlg32" (ByRef pOpenfilename As CSA_OpenFileNameW) As Long
    Private Declare PtrSafe Function OleCreatePictureIndirect Lib "oleaut32" (ByRef lpPictDesc As CSA_PictDescBmp, ByRef riid As CSA_Guid, ByVal fOwn As Long, ByRef lplpvObj As Object) As Long
#Else
    Private Type CSA_PictDescBmp
        cbSizeOfStruct As Long
        picType As Long
        hBitmap As Long
        hPal As Long
    End Type

    Private Type CSA_OpenFileNameW
        lStructSize As Long
        hwndOwner As Long
        hInstance As Long
        lpstrFilter As Long
        lpstrCustomFilter As Long
        nMaxCustFilter As Long
        nFilterIndex As Long
        lpstrFile As Long
        nMaxFile As Long
        lpstrFileTitle As Long
        nMaxFileTitle As Long
        lpstrInitialDir As Long
        lpstrTitle As Long
        Flags As Long
        nFileOffset As Integer
        nFileExtension As Integer
        lpstrDefExt As Long
        lCustData As Long
        lpfnHook As Long
        lpTemplateName As Long
        pvReserved As Long
        dwReserved As Long
        FlagsEx As Long
    End Type

    Public Type CSA_GdiCanvas
        memDC As Long
        hBitmap As Long
        oldBitmap As Long
        widthPx As Long
        heightPx As Long
    End Type

    Private Declare Function GetDC Lib "user32" (ByVal hwnd As Long) As Long
    Private Declare Function ReleaseDC Lib "user32" (ByVal hwnd As Long, ByVal hdc As Long) As Long
    Private Declare Function GetDeviceCaps Lib "gdi32" (ByVal hdc As Long, ByVal index As Long) As Long
    Private Declare Function CreateCompatibleDC Lib "gdi32" (ByVal hdc As Long) As Long
    Private Declare Function DeleteDC Lib "gdi32" (ByVal hdc As Long) As Long
    Private Declare Function CreateCompatibleBitmap Lib "gdi32" (ByVal hdc As Long, ByVal nWidth As Long, ByVal nHeight As Long) As Long
    Private Declare Function SelectObject Lib "gdi32" (ByVal hdc As Long, ByVal hObject As Long) As Long
    Private Declare Function DeleteObject Lib "gdi32" (ByVal hObject As Long) As Long
    Private Declare Function GetStockObject Lib "gdi32" (ByVal nIndex As Long) As Long
    Private Declare Function CreatePen Lib "gdi32" (ByVal nPenStyle As Long, ByVal nWidth As Long, ByVal crColor As Long) As Long
    Private Declare Function CreateSolidBrush Lib "gdi32" (ByVal crColor As Long) As Long
    Private Declare Function CreateFontW Lib "gdi32" ( _
        ByVal nHeight As Long, ByVal nWidth As Long, ByVal nEscapement As Long, _
        ByVal nOrientation As Long, ByVal fnWeight As Long, ByVal fdwItalic As Long, _
        ByVal fdwUnderline As Long, ByVal fdwStrikeOut As Long, ByVal fdwCharSet As Long, _
        ByVal fdwOutputPrecision As Long, ByVal fdwClipPrecision As Long, _
        ByVal fdwQuality As Long, ByVal fdwPitchAndFamily As Long, _
        ByVal lpszFace As Long) As Long
    Private Declare Function SetBkMode Lib "gdi32" (ByVal hdc As Long, ByVal iBkMode As Long) As Long
    Private Declare Function SetTextColor Lib "gdi32" (ByVal hdc As Long, ByVal crColor As Long) As Long
    Private Declare Function SetTextAlign Lib "gdi32" (ByVal hdc As Long, ByVal fMode As Long) As Long
    Private Declare Function FillRect Lib "user32" (ByVal hdc As Long, ByRef lpRect As CSA_Rect, ByVal hBrush As Long) As Long
    Private Declare Function Rectangle Lib "gdi32" (ByVal hdc As Long, ByVal nLeftRect As Long, ByVal nTopRect As Long, ByVal nRightRect As Long, ByVal nBottomRect As Long) As Long
    Private Declare Function MoveToEx Lib "gdi32" (ByVal hdc As Long, ByVal x As Long, ByVal y As Long, ByVal lpPoint As Long) As Long
    Private Declare Function LineTo Lib "gdi32" (ByVal hdc As Long, ByVal nXEnd As Long, ByVal nYEnd As Long) As Long
    Private Declare Function Ellipse Lib "gdi32" (ByVal hdc As Long, ByVal nLeftRect As Long, ByVal nTopRect As Long, ByVal nRightRect As Long, ByVal nBottomRect As Long) As Long
    Private Declare Function TextOutW Lib "gdi32" (ByVal hdc As Long, ByVal nXStart As Long, ByVal nYStart As Long, ByVal lpString As Long, ByVal cbString As Long) As Long
    Private Declare Function GetOpenFileNameW Lib "comdlg32" (ByRef pOpenfilename As CSA_OpenFileNameW) As Long
    Private Declare Function OleCreatePictureIndirect Lib "oleaut32" (ByRef lpPictDesc As CSA_PictDescBmp, ByRef riid As CSA_Guid, ByVal fOwn As Long, ByRef lplpvObj As Object) As Long
#End If

Private Const LOGPIXELSX As Long = 88
Private Const NULL_BRUSH As Long = 5
Private Const TRANSPARENT_BK As Long = 1
Private Const PICTYPE_BITMAP As Long = 1
Private Const CLEARTYPE_QUALITY As Long = 5
Private Const DEFAULT_CHARSET As Long = 1

Private Const OFN_HIDEREADONLY As Long = &H4&
Private Const OFN_NOCHANGEDIR As Long = &H8&
Private Const OFN_PATHMUSTEXIST As Long = &H800&
Private Const OFN_FILEMUSTEXIST As Long = &H1000&

Public Const CSA_PEN_SOLID As Long = 0
Public Const CSA_PEN_DASH As Long = 1
Public Const CSA_PEN_DOT As Long = 2
Public Const CSA_PEN_DASHDOT As Long = 3

Public Const CSA_ALIGN_LEFT As Long = 0
Public Const CSA_ALIGN_RIGHT As Long = 2
Public Const CSA_ALIGN_CENTER As Long = 6

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

Public Function CSA_FormPointsToPixels(ByVal points As Double) As Long
    Dim px As Long
    px = CLng(points * CSA_SystemDpiX() / 72#)
    If px < 1 Then px = 1
    CSA_FormPointsToPixels = px
End Function

Public Function CSA_PickExcelFile(Optional ByVal initialDir As String = "", _
                                  Optional ByVal title As String = "Select Excel Workbook") As String
    Dim ofn As CSA_OpenFileNameW
    Dim filter As String, fileBuf As String, dirBuf As String, titleBuf As String
    Dim pos As Long

    filter = "Excel Workbooks (*.xlsm;*.xlsx;*.xls)" & vbNullChar & _
             "*.xlsm;*.xlsx;*.xls" & vbNullChar & _
             "All Files (*.*)" & vbNullChar & "*.*" & vbNullChar & vbNullChar
    fileBuf = String$(1024, vbNullChar)
    titleBuf = title & vbNullChar

    ofn.lStructSize = LenB(ofn)
    ofn.lpstrFilter = StrPtr(filter)
    ofn.nFilterIndex = 1
    ofn.lpstrFile = StrPtr(fileBuf)
    ofn.nMaxFile = Len(fileBuf)
    ofn.lpstrTitle = StrPtr(titleBuf)
    If Len(Trim$(initialDir)) > 0 Then
        dirBuf = Trim$(initialDir) & vbNullChar
        ofn.lpstrInitialDir = StrPtr(dirBuf)
    End If
    ofn.Flags = OFN_FILEMUSTEXIST Or OFN_PATHMUSTEXIST Or OFN_NOCHANGEDIR Or OFN_HIDEREADONLY

    If GetOpenFileNameW(ofn) <> 0 Then
        pos = InStr(1, fileBuf, vbNullChar)
        If pos > 1 Then
            CSA_PickExcelFile = Left$(fileBuf, pos - 1)
        Else
            CSA_PickExcelFile = Trim$(fileBuf)
        End If
    End If
End Function

Public Function CSA_BeginCanvas(ByVal widthPx As Long, ByVal heightPx As Long, _
                                ByRef canvas As CSA_GdiCanvas) As Boolean
#If VBA7 Then
    Dim screenDC As LongPtr
#Else
    Dim screenDC As Long
#End If
    Dim errorNumber As Long, errorText As String
    On Error GoTo Failed
    If widthPx < 16 Then widthPx = 16
    If heightPx < 16 Then heightPx = 16
    screenDC = GetDC(0)
    If screenDC = 0 Then Err.Raise vbObjectError + 472, , "Cannot acquire screen DC for preview."
    canvas.memDC = CreateCompatibleDC(screenDC)
    If canvas.memDC = 0 Then Err.Raise vbObjectError + 473, , "Cannot create compatible DC."
    canvas.hBitmap = CreateCompatibleBitmap(screenDC, widthPx, heightPx)
    If canvas.hBitmap = 0 Then Err.Raise vbObjectError + 474, , "Cannot create compatible bitmap."
    ReleaseDC 0, screenDC
    screenDC = 0
    canvas.oldBitmap = SelectObject(canvas.memDC, canvas.hBitmap)
    canvas.widthPx = widthPx
    canvas.heightPx = heightPx
    SetBkMode canvas.memDC, TRANSPARENT_BK
    CSA_BeginCanvas = True
    Exit Function
Failed:
    errorNumber = Err.Number: errorText = Err.Description
    If screenDC <> 0 Then ReleaseDC 0, screenDC
    CSA_DiscardCanvas canvas
    Err.Raise errorNumber, "CSA Windows API", errorText
End Function

Public Sub CSA_DiscardCanvas(ByRef canvas As CSA_GdiCanvas)
    On Error Resume Next
    If canvas.memDC <> 0 And canvas.oldBitmap <> 0 Then
        SelectObject canvas.memDC, canvas.oldBitmap
        canvas.oldBitmap = 0
    End If
    If canvas.hBitmap <> 0 Then
        DeleteObject canvas.hBitmap
        canvas.hBitmap = 0
    End If
    If canvas.memDC <> 0 Then
        DeleteDC canvas.memDC
        canvas.memDC = 0
    End If
    canvas.widthPx = 0
    canvas.heightPx = 0
End Sub

Public Function CSA_EndCanvasToPicture(ByRef canvas As CSA_GdiCanvas) As Object
    Dim desc As CSA_PictDescBmp
    Dim iid As CSA_Guid
    Dim pic As Object
    Dim hr As Long
#If VBA7 Then
    Dim bmp As LongPtr
#Else
    Dim bmp As Long
#End If
    If canvas.memDC = 0 Or canvas.hBitmap = 0 Then Exit Function
    If canvas.oldBitmap <> 0 Then
        SelectObject canvas.memDC, canvas.oldBitmap
        canvas.oldBitmap = 0
    End If
    bmp = canvas.hBitmap
    canvas.hBitmap = 0
    DeleteDC canvas.memDC
    canvas.memDC = 0

    desc.cbSizeOfStruct = LenB(desc)
    desc.picType = PICTYPE_BITMAP
    desc.hBitmap = bmp
    desc.hPal = 0

    ' IID_IPictureDisp = {7BF80981-BF32-101A-8BBB-00AA00300CAB}
    iid.Data1 = &H7BF80981
    iid.Data2 = &HBF32
    iid.Data3 = &H101A
    iid.Data4(0) = &H8B: iid.Data4(1) = &HBB: iid.Data4(2) = &H0: iid.Data4(3) = &HAA
    iid.Data4(4) = &H0: iid.Data4(5) = &H30: iid.Data4(6) = &HC: iid.Data4(7) = &HAB

    hr = OleCreatePictureIndirect(desc, iid, 1, pic)
    If hr <> 0 Or pic Is Nothing Then
        If bmp <> 0 Then DeleteObject bmp
        Err.Raise vbObjectError + 475, "CSA Windows API", "OleCreatePictureIndirect failed (HRESULT " & CStr(hr) & ")."
    End If
    Set CSA_EndCanvasToPicture = pic
End Function

Public Sub CSA_CanvasFillRect(ByRef canvas As CSA_GdiCanvas, _
                              ByVal x1 As Long, ByVal y1 As Long, _
                              ByVal x2 As Long, ByVal y2 As Long, _
                              ByVal fillColor As Long)
#If VBA7 Then
    Dim br As LongPtr
#Else
    Dim br As Long
#End If
    Dim rc As CSA_Rect
    If canvas.memDC = 0 Then Exit Sub
    rc.Left = x1: rc.Top = y1: rc.Right = x2: rc.Bottom = y2
    br = CreateSolidBrush(fillColor)
    If br <> 0 Then
        FillRect canvas.memDC, rc, br
        DeleteObject br
    End If
End Sub

Public Sub CSA_CanvasRect(ByRef canvas As CSA_GdiCanvas, _
                          ByVal x1 As Long, ByVal y1 As Long, _
                          ByVal x2 As Long, ByVal y2 As Long, _
                          ByVal lineColor As Long, _
                          Optional ByVal lineWidth As Long = 1, _
                          Optional ByVal fillColor As Long = -1)
#If VBA7 Then
    Dim pen As LongPtr, oldPen As LongPtr
    Dim br As LongPtr, oldBr As LongPtr
#Else
    Dim pen As Long, oldPen As Long
    Dim br As Long, oldBr As Long
#End If
    Dim ownsBrush As Boolean
    If canvas.memDC = 0 Then Exit Sub
    pen = CreatePen(CSA_PEN_SOLID, lineWidth, lineColor)
    If fillColor >= 0 Then
        br = CreateSolidBrush(fillColor)
        ownsBrush = True
    Else
        br = GetStockObject(NULL_BRUSH)
    End If
    If pen <> 0 Then oldPen = SelectObject(canvas.memDC, pen)
    If br <> 0 Then oldBr = SelectObject(canvas.memDC, br)
    Rectangle canvas.memDC, x1, y1, x2, y2
    If oldBr <> 0 Then SelectObject canvas.memDC, oldBr
    If oldPen <> 0 Then SelectObject canvas.memDC, oldPen
    If ownsBrush And br <> 0 Then DeleteObject br
    If pen <> 0 Then DeleteObject pen
End Sub

Public Sub CSA_CanvasLine(ByRef canvas As CSA_GdiCanvas, _
                          ByVal x1 As Long, ByVal y1 As Long, _
                          ByVal x2 As Long, ByVal y2 As Long, _
                          ByVal lineColor As Long, _
                          Optional ByVal lineWidth As Long = 1, _
                          Optional ByVal penStyle As Long = CSA_PEN_SOLID)
#If VBA7 Then
    Dim pen As LongPtr, oldPen As LongPtr
#Else
    Dim pen As Long, oldPen As Long
#End If
    If canvas.memDC = 0 Then Exit Sub
    ' Win32 dashed/dotted pens require width = 1.
    If penStyle <> CSA_PEN_SOLID Then lineWidth = 1
    pen = CreatePen(penStyle, lineWidth, lineColor)
    If pen <> 0 Then oldPen = SelectObject(canvas.memDC, pen)
    MoveToEx canvas.memDC, x1, y1, 0
    LineTo canvas.memDC, x2, y2
    If oldPen <> 0 Then SelectObject canvas.memDC, oldPen
    If pen <> 0 Then DeleteObject pen
End Sub

Public Sub CSA_CanvasCircle(ByRef canvas As CSA_GdiCanvas, _
                            ByVal cx As Long, ByVal cy As Long, ByVal radius As Long, _
                            ByVal lineColor As Long, Optional ByVal fillColor As Long = -1)
#If VBA7 Then
    Dim pen As LongPtr, oldPen As LongPtr
    Dim br As LongPtr, oldBr As LongPtr
#Else
    Dim pen As Long, oldPen As Long
    Dim br As Long, oldBr As Long
#End If
    Dim ownsBrush As Boolean
    If canvas.memDC = 0 Or radius <= 0 Then Exit Sub
    pen = CreatePen(CSA_PEN_SOLID, 1, lineColor)
    If fillColor >= 0 Then
        br = CreateSolidBrush(fillColor)
        ownsBrush = True
    Else
        br = GetStockObject(NULL_BRUSH)
    End If
    If pen <> 0 Then oldPen = SelectObject(canvas.memDC, pen)
    If br <> 0 Then oldBr = SelectObject(canvas.memDC, br)
    Ellipse canvas.memDC, cx - radius, cy - radius, cx + radius, cy + radius
    If oldBr <> 0 Then SelectObject canvas.memDC, oldBr
    If oldPen <> 0 Then SelectObject canvas.memDC, oldPen
    If ownsBrush And br <> 0 Then DeleteObject br
    If pen <> 0 Then DeleteObject pen
End Sub

Public Sub CSA_CanvasText(ByRef canvas As CSA_GdiCanvas, _
                          ByVal x As Long, ByVal y As Long, ByVal text As String, _
                          ByVal textColor As Long, Optional ByVal fontHeightPx As Long = 13, _
                          Optional ByVal bold As Boolean = False, _
                          Optional ByVal alignMode As Long = CSA_ALIGN_LEFT, _
                          Optional ByVal angleTenthsDeg As Long = 0)
#If VBA7 Then
    Dim fnt As LongPtr, oldFnt As LongPtr
#Else
    Dim fnt As Long, oldFnt As Long
#End If
    Dim faceName As String, weight As Long
    If canvas.memDC = 0 Or Len(text) = 0 Then Exit Sub
    faceName = "Segoe UI"
    weight = IIf(bold, 700, 400)
    fnt = CreateFontW(-fontHeightPx, 0, angleTenthsDeg, angleTenthsDeg, weight, _
                      0, 0, 0, DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, StrPtr(faceName))
    If fnt <> 0 Then oldFnt = SelectObject(canvas.memDC, fnt)
    SetBkMode canvas.memDC, TRANSPARENT_BK
    SetTextColor canvas.memDC, textColor
    SetTextAlign canvas.memDC, alignMode
    TextOutW canvas.memDC, x, y, StrPtr(text), Len(text)
    If oldFnt <> 0 Then SelectObject canvas.memDC, oldFnt
    If fnt <> 0 Then DeleteObject fnt
End Sub
