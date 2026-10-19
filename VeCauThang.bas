Attribute VB_Name = "VeCauThang"
Option Explicit

'==============================================================
' MODULE: VeCauThang
' Mô tả: Đọc tọa độ đường bao bê tông cầu thang từ sheet Excel
'         và vẽ vào AutoCAD (outline + cao độ + dim cơ bản)
'
' Cách dùng:
'   1. Đảm bảo AutoCAD đang mở và có 1 drawing active
'   2. Điền đúng các ô cấu hình trong sheet (xem bên dưới)
'   3. Chạy macro: VeBeTongCauThang
'
' Cấu hình trong sheet (sheet chứa data tọa độ):
'   - Ô chứa cột X đường bao  : xem hằng số COL_X, ROW_START bên dưới
'   - Ô chứa cột Y đường bao  : COL_Y
'   - Số điểm (STT cuối cùng) : tự đọc cho đến khi gặp ô trống
'
' Tọa độ chèn vào AutoCAD:
'   - Ô INS_X_CELL: tọa độ X điểm chèn (đơn vị mm trong AutoCAD)
'   - Ô INS_Y_CELL: tọa độ Y điểm chèn
'
' Cao độ (để vẽ ký hiệu cao độ):
'   - Ô ELEV_BOT_CELL: cao độ chiếu nghỉ dưới (vd: 186.080)
'   - Ô ELEV_TOP_CELL: cao độ chiếu nghỉ trên (vd: 187.850)
'==============================================================

' ---- CẤU HÌNH - THAY ĐỔI TẠI ĐÂY ----
' Vị trí cột tọa độ đường bao chính (cột BZ, CA trong ảnh)
Private Const SHEET_NAME    As String = ""        ' Để trống = sheet hiện tại
Private Const COL_X         As Long = 58          ' Cột BZ = 58 (A=1, B=2, ... Z=26, AA=27,...)
Private Const COL_Y         As Long = 59          ' Cột CA = 59
Private Const COL_STT       As Long = 57          ' Cột BY = 57 (cột STT)
Private Const ROW_START     As Long = 2           ' Hàng bắt đầu dữ liệu (hàng có STT=1)

' Ô cấu hình chèn & cao độ (ô người dùng nhập tay - đặt ở vùng input quen thuộc)
Private Const INS_X_CELL    As String = "B2"      ' Tọa độ X chèn vào AutoCAD (mm)
Private Const INS_Y_CELL    As String = "B3"      ' Tọa độ Y chèn vào AutoCAD (mm)
Private Const ELEV_BOT_CELL As String = "B4"      ' Cao độ chiếu nghỉ dưới (m), vd: 186.080
Private Const ELEV_TOP_CELL As String = "B5"      ' Cao độ chiếu nghỉ trên (m), vd: 187.850
Private Const INS_SHEET     As String = "INPUT"   ' Sheet chứa các ô config trên

' Tên các layer sẽ tạo trong AutoCAD
Private Const LYR_BT        As String = "00-BT"       ' Bê tông (outline)
Private Const LYR_DIM       As String = "04-GB-Dim"   ' Kích thước
Private Const LYR_CAODO     As String = "11-GB-Cao Do" ' Cao độ

' Kích thước ký hiệu (đơn vị mm, scale với bản vẽ)
Private Const SYM_SIZE      As Double = 100       ' Kích thước tam giác cao độ
Private Const TXT_H         As Double = 150       ' Chiều cao chữ số cao độ
Private Const DIM_OFFSET    As Double = 400       ' Khoảng cách dim ra ngoài outline

' ---- KẾT THÚC CẤU HÌNH ----


'==============================================================
' MAIN: Vẽ bê tông cầu thang
'==============================================================
Sub VeBeTongCauThang()
    ' 1. Kết nối AutoCAD
    Dim acApp As Object
    Dim acDoc As Object
    Dim acMS  As Object

    On Error Resume Next
    Set acApp = GetObject(, "AutoCAD.Application")
    On Error GoTo 0

    If acApp Is Nothing Then
        MsgBox "Không tìm thấy AutoCAD đang chạy." & vbLf & _
               "Vui lòng mở AutoCAD và có 1 drawing active trước.", _
               vbExclamation, "VeCauThang"
        Exit Sub
    End If

    Set acDoc = acApp.ActiveDocument
    Set acMS = acDoc.ModelSpace

    ' 2. Đọc tọa độ đường bao từ sheet
    Dim wsData As Object
    If SHEET_NAME = "" Then
        Set wsData = ActiveSheet
    Else
        On Error Resume Next
        Set wsData = ThisWorkbook.Sheets(SHEET_NAME)
        On Error GoTo 0
        If wsData Is Nothing Then
            MsgBox "Không tìm thấy sheet: " & SHEET_NAME, vbCritical, "VeCauThang"
            Exit Sub
        End If
    End If

    ' Đọc điểm cho đến khi STT trống
    Dim ptS()  As Double
    Dim nPts   As Long
    nPts = 0
    ReDim ptS(0 To 999)

    Dim r As Long
    r = ROW_START
    Do While wsData.Cells(r, COL_STT).Value <> ""
        Dim px As Double, py As Double
        px = Val(wsData.Cells(r, COL_X).Value)
        py = Val(wsData.Cells(r, COL_Y).Value)
        ptS(nPts * 2) = px
        ptS(nPts * 2 + 1) = py
        nPts = nPts + 1
        r = r + 1
        If r > ROW_START + 500 Then Exit Do  ' an toàn
    Loop

    If nPts < 3 Then
        MsgBox "Không đủ điểm tọa độ. Kiểm tra lại cột STT/X/Y và ROW_START.", _
               vbExclamation, "VeCauThang"
        Exit Sub
    End If

    ' 3. Đọc cấu hình chèn & cao độ
    Dim wsIn As Worksheet
    On Error Resume Next
    Set wsIn = ThisWorkbook.Sheets(INS_SHEET)
    On Error GoTo 0
    If wsIn Is Nothing Then Set wsIn = ActiveSheet  ' fallback

    Dim insX As Double, insY As Double
    Dim elevBot As Double, elevTop As Double
    insX = Val(wsIn.Range(INS_X_CELL).Value)
    insY = Val(wsIn.Range(INS_Y_CELL).Value)
    elevBot = Val(wsIn.Range(ELEV_BOT_CELL).Value)
    elevTop = Val(wsIn.Range(ELEV_TOP_CELL).Value)

    ' 4. Tịnh tiến tọa độ theo điểm chèn
    ReDim Preserve ptS(0 To nPts * 2 - 1)
    Dim i As Long
    For i = 0 To nPts - 1
        ptS(i * 2) = ptS(i * 2) + insX
        ptS(i * 2 + 1) = ptS(i * 2 + 1) + insY
    Next i

    ' 5. Tạo các layer cần thiết
    TaoLayer acDoc, LYR_BT, 7, 50       ' trắng, đường đôi
    TaoLayer acDoc, LYR_DIM, 4, 25      ' xanh lá
    TaoLayer acDoc, LYR_CAODO, 1, 25    ' đỏ

    ' 6. Vẽ polyline đường bao bê tông
    Dim plBT As Object
    Set plBT = acMS.AddLightWeightPolyline(ptS)
    plBT.Closed = True
    plBT.Layer = LYR_BT
    plBT.ConstantWidth = 0
    plBT.Update

    ' 7. Vẽ cao độ
    '    Tìm Y lớn nhất (chiếu nghỉ trên) và Y nhỏ nhất vùng chiếu nghỉ dưới
    '    Lấy từ điểm đầu (STT1): X=0, Y=0 => cao độ bot
    '    Và điểm có Y lớn nhất => cao độ top
    Dim yMin As Double, yMax As Double
    Dim xAtYMax As Double, xAtYMin As Double
    yMin = ptS(1): yMax = ptS(1)
    xAtYMax = ptS(0): xAtYMin = ptS(0)
    For i = 0 To nPts - 1
        If ptS(i * 2 + 1) < yMin Then
            yMin = ptS(i * 2 + 1): xAtYMin = ptS(i * 2)
        End If
        If ptS(i * 2 + 1) > yMax Then
            yMax = ptS(i * 2 + 1): xAtYMax = ptS(i * 2)
        End If
    Next i

    ' Cao độ dưới: tại X=insX, Y=insY (điểm gốc đường bao = sàn tầng dưới)
    VeCaoDo acMS, insX, insY, elevBot

    ' Cao độ trên: tại điểm có Y cao nhất (chiếu nghỉ trên)
    VeCaoDo acMS, xAtYMax, yMax, elevTop

    ' 8. Kích thước tổng thể (tùy chọn - bỏ comment nếu muốn)
    ' Tự động lấy Xmin, Xmax từ tập điểm
    Dim xMin As Double, xMax As Double
    xMin = ptS(0): xMax = ptS(0)
    For i = 0 To nPts - 1
        If ptS(i * 2) < xMin Then xMin = ptS(i * 2)
        If ptS(i * 2) > xMax Then xMax = ptS(i * 2)
    Next i

    ' Dim chiều dài tổng (phía trên)
    VeDimLinear acMS, xMin, yMax + DIM_OFFSET, _
                       xMax, yMax + DIM_OFFSET, _
                       yMax + DIM_OFFSET

    ' Dim chiều cao tổng (bên trái)
    VeDimLinear acMS, xMin - DIM_OFFSET, insY, _
                       xMin - DIM_OFFSET, yMax, _
                       xMin - DIM_OFFSET

    ' 9. Zoom extents
    acApp.ZoomExtents

    MsgBox "Vẽ bê tông cầu thang hoàn thành!" & vbLf & _
           "Số điểm: " & nPts, vbInformation, "VeCauThang"
End Sub


'==============================================================
' Vẽ ký hiệu cao độ kiểu tam giác + đường ngang + text
' Ký hiệu hướng sang phải, text phía trên
'==============================================================
Sub VeCaoDo(acMS As Object, x As Double, y As Double, elev As Double)
    Const SZ As Double = SYM_SIZE

    ' Tam giác (filled polyline closed)
    Dim tri(5) As Double
    tri(0) = x:       tri(1) = y          ' đỉnh (điểm đặt)
    tri(2) = x + SZ:  tri(3) = y + SZ / 2
    tri(4) = x + SZ;  tri(5) = y - SZ / 2
    Dim plTri As Object
    Set plTri = acMS.AddLightWeightPolyline(tri)
    plTri.Closed = True
    plTri.Layer = LYR_CAODO
    plTri.Update

    ' Đường ngang từ đỉnh sang phải
    Dim ptS(2) As Double, ptE(2) As Double
    ptS(0) = x:           ptS(1) = y: ptS(2) = 0
    ptE(0) = x + SZ * 5:  ptE(1) = y: ptE(2) = 0
    Dim ln As Object
    Set ln = acMS.AddLine(ptS, ptE)
    ln.Layer = LYR_CAODO
    ln.Update

    ' Text cao độ, vd: "+187.850"
    Dim elevStr As String
    If elev >= 0 Then
        elevStr = "+" & Format(elev, "0.000")
    Else
        elevStr = Format(elev, "0.000")
    End If

    Dim txtPt(2) As Double
    txtPt(0) = x + SZ * 2.5: txtPt(1) = y + TXT_H * 0.8: txtPt(2) = 0
    Dim txtObj As Object
    Set txtObj = acMS.AddText(elevStr, txtPt, TXT_H)
    txtObj.Layer = LYR_CAODO
    ' Căn giữa theo chiều ngang
    txtObj.Alignment = 4  ' acAlignmentMiddleCenter
    Dim algPt(2) As Double
    algPt(0) = txtPt(0): algPt(1) = txtPt(1): algPt(2) = 0
    txtObj.TextAlignmentPoint = algPt
    txtObj.Update
End Sub


'==============================================================
' Vẽ Dim Linear (aligned) giữa 2 điểm
' dimLinePt: tọa độ đường dim (theo X nếu dim ngang, theo Y nếu dim dọc)
'==============================================================
Sub VeDimLinear(acMS As Object, _
                x1 As Double, y1 As Double, _
                x2 As Double, y2 As Double, _
                dimLinePt As Double)
    Dim pt1(2) As Double, pt2(2) As Double, ptD(2) As Double
    pt1(0) = x1: pt1(1) = y1: pt1(2) = 0
    pt2(0) = x2: pt2(1) = y2: pt2(2) = 0
    ptD(0) = (x1 + x2) / 2: ptD(1) = dimLinePt: ptD(2) = 0

    Dim dimObj As Object
    Set dimObj = acMS.AddDimAligned(pt1, pt2, ptD)
    dimObj.Layer = LYR_DIM
    dimObj.Update
End Sub


'==============================================================
' Tạo layer trong AutoCAD nếu chưa tồn tại
' mauSac: ACI color (1=đỏ, 2=vàng, 3=xanh lá, 4=cyan, 7=trắng)
' lw: lineweight * 100 (vd: 50 = 0.50mm, 25 = 0.25mm)
'==============================================================
Sub TaoLayer(acDoc As Object, tenLayer As String, mauSac As Integer, lw As Long)
    Dim layers As Object
    Set layers = acDoc.layers

    Dim lyr As Object
    On Error Resume Next
    Set lyr = layers.Item(tenLayer)
    On Error GoTo 0

    If lyr Is Nothing Then
        Set lyr = layers.Add(tenLayer)
    End If

    lyr.Color = mauSac

    ' Lineweight: dùng hằng số acLnWt (acLnWt025=25, acLnWt050=50, ...)
    On Error Resume Next
    lyr.Lineweight = lw  ' AutoCAD nhận giá trị 25, 50, 70, 100...
    On Error GoTo 0
End Sub


'==============================================================
' Tạo sheet INPUT nếu chưa có (chạy 1 lần khi setup)
'==============================================================
Sub TaoSheetInput()
    Dim ws As Worksheet
    On Error Resume Next
    Set ws = ThisWorkbook.Sheets(INS_SHEET)
    On Error GoTo 0

    If ws Is Nothing Then
        Set ws = ThisWorkbook.Sheets.Add(Before:=ThisWorkbook.Sheets(1))
        ws.Name = INS_SHEET
    End If

    ws.Activate

    ' Tiêu đề
    ws.Range("A1").Value = "CẤU HÌNH VẼ CẦU THANG"
    ws.Range("A1").Font.Bold = True
    ws.Range("A1").Font.Size = 12

    ' Các ô input
    ws.Range("A2").Value = "Tọa độ X chèn vào AutoCAD (mm):"
    ws.Range("B2").Value = 0

    ws.Range("A3").Value = "Tọa độ Y chèn vào AutoCAD (mm):"
    ws.Range("B3").Value = 0

    ws.Range("A4").Value = "Cao độ chiếu nghỉ dưới (m) - vd: 186.080:"
    ws.Range("B4").Value = 186.08

    ws.Range("A5").Value = "Cao độ chiếu nghỉ trên (m) - vd: 187.850:"
    ws.Range("B5").Value = 187.85

    ws.Range("A7").Value = "→ Sau khi điền xong, chạy macro: VeBeTongCauThang"
    ws.Range("A7").Font.Color = RGB(200, 0, 0)
    ws.Range("A7").Font.Bold = True

    ' Thêm nút bấm
    Dim btn As Object
    On Error Resume Next
    ws.Buttons.Delete  ' xóa nút cũ nếu có
    On Error GoTo 0

    Set btn = ws.Buttons.Add(200, 120, 160, 30)
    btn.Caption = "🔺 Vẽ Bê Tông Cầu Thang"
    btn.OnAction = "VeBeTongCauThang"

    ws.Columns("A").AutoFit

    MsgBox "Đã tạo sheet INPUT thành công!" & vbLf & _
           "Điền cao độ và tọa độ chèn, rồi nhấn nút vẽ.", _
           vbInformation, "VeCauThang"
End Sub
