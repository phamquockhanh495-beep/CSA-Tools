# Kiểm tra hiển thị tiêu chuẩn CSA

Chỉ cần tải `CSA_StairStandardsTest.lsp`, không cần import VBA, file DCL riêng hoặc Excel. Lisp tự tạo hộp chọn DimStyle tạm trong thư mục temp và xóa sau khi đóng hộp thoại.

1. Mở **bản sao** `CSA Drawing Data.Rev12.dwg`, chuyển sang tab **Model**.
2. `APPLOAD` file `CSA_StairStandardsTest.lsp`.
3. Gõ `CSA_STAIR_CHECK`. Xem kết quả bằng **F2**. Lệnh kiểm tra tài nguyên không vẽ gì.
4. Gõ `CSA_STAIR_TEST`, chọn DimStyle trong danh sách, bắt đầu với **GB 25**.
5. Chọn một điểm trong vùng trống; đơn vị phải là mm (`INSUNITS=4`).
6. Nhập hệ số chèn block, thử **1** trước. Đây là hệ số hình học block, không tự suy ra từ mẫu số tỷ lệ bản vẽ.
7. Chụp ảnh toàn bộ vùng mẫu và các chỗ sai tỷ lệ/font. Thử lại với `GB 50` nếu cần so sánh.
8. `CSA_STAIR_TEST_CLEAR` xóa riêng các đối tượng mẫu được đánh dấu. Các lần chạy được giữ lại để so sánh cho đến khi bạn xóa. Có thể dùng `UNDO` để hoàn tác từng lần dựng mẫu.

## Kết quả cần kiểm tra

| Mẫu | Kết quả mong đợi |
|---|---|
| Đường bao 3000 x 200 | Layer `21-GB-BD`, nét/màu theo layer |
| Đường thép mẫu | Layer `18-GB-Reinf`, giữ thuộc tính gốc |
| Dimension | Giá trị **3000**, dùng DimStyle vừa chọn |
| Block `Cao do` | Tag `%%P0.000` hiển thị **+3.600** |
| Block `Daucat` | Tag `A` hiển thị **1-1** |
| Block `So hieu thep` | Tag `A` hiển thị **1** |
| Block `CSA_Sohieu-KCthep` | `SH` = **2**, `DK-KC` = **12a150** |
| Dòng chữ | Kiểm tra kích thước, font và căn chỉnh |

Vui lòng gửi ảnh kèm tên DimStyle, hệ số block, phiên bản AutoCAD và thông báo lỗi nếu có. Chữ mẫu dùng ASCII để không trộn Unicode với bảng mã VNI; chưa kiểm tra toàn bộ chữ tiếng Việt. Kiểm tra font bằng mắt vì khả năng tìm thấy file trên search path không chứng minh font đã được AutoCAD dùng đúng.

## Giới hạn và hành vi

- Đây là kiểm tra tài nguyên, **chưa phải bản vẽ cầu thang hoặc thiết kế cốt thép**.
- Không tự tạo, sửa màu/nét, mở khóa hay thay thế layer, block, DimStyle và TextStyle CSA. Không đổi style hiện hành hoặc tự zoom bản vẽ.
- Thiếu tài nguyên hoặc layer dùng trong mẫu đang tắt/đóng băng/khóa: báo tên rồi dừng. Giữ nguyên trạng thái bản vẽ.
- Chỉ thêm các đối tượng mẫu, đăng ký app XData và đánh dấu chúng bằng `CSA_STAIR_STANDARDS_TEST`. Lệnh xóa dựa trên dấu này, không dựa trên tên layer; hình khác dùng cùng layer được giữ lại.
- Block có thể chứa entity ở layer nội bộ khác; Lisp không ghi đè các layer/màu bên trong block. Báo lại nếu có phần ký hiệu bị ẩn.
- Bản kiểm tra dùng AutoCAD Windows có Visual LISP/ActiveX. Chưa xác nhận thực thi trong AutoCAD tại môi trường Linux hiện tại.

## Thay đổi trong mã VBA

Các hằng số layer đã ánh xạ sang danh mục gốc trong `standards/csa-profile.json`. Lệnh preview chỉ chuẩn bị `CSA-PREVIEW`; không còn tạo các layer `CSA-CONCRETE`, `CSA-REBAR`, `CSA-DIM`, `CSA-TEXT`. Nếu layer cuối cùng thiếu thì báo lỗi thay vì tạo bằng thuộc tính mặc định. Màu chỉ được đặt lúc tạo layer preview mới, không ghi đè layer có sẵn.

Preview mới được đánh dấu `CSA_STAIR_PREVIEW`. Cleanup chỉ xóa preview có dấu này. Preview từ phiên bản cũ chưa có dấu sẽ được giữ lại; kiểm tra và xóa thủ công nếu cần, không xóa toàn bộ layer bằng tiện ích.

Bản nhiều module cũng đã sửa thứ tự khai báo `Public Type` (trước các thủ tục) và truyền `CSAFlight` bằng `ByRef`. Đây là các vấn đề mã nguồn có thể gây lỗi biên dịch ở bản trước; việc bỏ UDT không phải yêu cầu chung của AutoCAD VBA. Lời gọi theme được để dạng chú thích cho đến khi import đủ theme/class.

Engine hình học cầu thang cũ vẫn là nguyên mẫu chưa được xác nhận; vòng này chỉ xác nhận tiêu chuẩn trình bày. CSV/JSON không chứa hình học nhị phân của block, nên bản vẽ đang kiểm tra cần có sẵn các định nghĩa trong DWG mẫu.
