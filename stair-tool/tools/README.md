# Xuất tiêu chuẩn CSA từ DWG

1. Tải **file raw** `CSA_ExportStandards.lsp`, không lưu trang HTML GitHub thành LSP.
2. Mở `CSA Drawing Data.Rev12.dwg` trong AutoCAD trên Windows.
3. Gõ `APPLOAD`, chọn file LSP, rồi đóng hộp thoại.
4. Gõ `CSA_EXPORT_STANDARDS`.
5. Chọn nơi lưu báo cáo có quyền ghi, ví dụ Desktop, giữ tên `CSA_Standards.csv`.
6. Chờ thông báo `CSA export complete`. Chương trình tạo **6 file có hậu tố**, không tạo chính file `CSA_Standards.csv`.
7. Upload cả 6 file lên thư mục `stair-tool/standards-export` trên GitHub và báo lại.

| File | Nội dung |
|---|---|
| `_layers.csv` | Tên layer, ACI, TrueColor, nét, lineweight và trạng thái |
| `_blocks.csv` | Tên block, điểm gốc, xref, số entity và ATTDEF |
| `_attributes.csv` | Tag, prompt, giá trị mặc định, cờ và vị trí ATTDEF |
| `_textstyles.csv` | Tên style, font, bigfont, chiều cao và width factor |
| `_tables_dxf.csv` | Dữ liệu DXF chi tiết: LAYER, LTYPE, STYLE, DIMSTYLE, BLOCK |
| `_drawing.csv` | Phiên bản AutoCAD, đơn vị và các style đang dùng |

Lệnh chỉ đọc bản vẽ và ghi báo cáo; không đổi layer, block, style, biến hệ thống hoặc lưu DWG. Không cần VBA Enabler hoặc Excel. Nếu báo cáo đã tồn tại, lệnh hỏi trước khi ghi đè. Nếu hủy/lỗi, chỉ các báo cáo đang ghi có thể chưa đầy đủ; chạy lại để xuất đủ bộ.

AutoCAD 2021+ dùng engine Unicode (`LISPSYS` > 0) sẽ xuất UTF-8 BOM. Với engine cũ, báo cáo dùng encoding mặc định của máy. Tiện ích không tự đổi `LISPSYS`.

Lineweight là mã DXF theo 1/100 mm, với giá trị âm là các chế độ kế thừa. Block ẩn/anonymous và xref được giữ trong danh mục; không tự lọc để tránh bỏ mất tài nguyên. ATTDEF là định nghĩa thuộc tính, không phải giá trị ATTRIB đã điền trên từng block reference. Báo cáo không xuất nội dung nhị phân block, trạng thái động/visibility hay dữ liệu bên trong file xref ngoài chưa được nạp.

Đã kiểm tra cấu trúc mã nguồn trên Linux. Việc thực thi cần xác nhận trong AutoCAD.
