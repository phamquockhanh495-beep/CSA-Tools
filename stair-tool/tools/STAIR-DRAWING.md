# CSA Stair Drawing — giao diện và mặt cắt từ Excel

## Bản chạy một file

Tải `CSA_StairDrawing.lsp` tại thư mục này. File đã gộp toàn bộ helper cần thiết, không cần tải Lisp/DCL khác hoặc import VBA. Đây là giao diện DCL chạy trong AutoCAD Windows, chưa phải file `.dvb` hoặc UserForm đã đóng gói.

1. Mở **bản sao** `CSA Drawing Data.Rev12.dwg` (file mẫu ở nhánh `main`), vào tab Model. Đơn vị `INSUNITS=4` (mm).
2. Mở `CSA_Stair Drawing Tools.xlsm` trong Excel, kiểm tra sheet `Cau Thang Tools` đã tính ra tọa độ. Chờ Excel tính xong.
3. `APPLOAD` file **`CSA_StairDrawing.lsp`**.
4. Gõ **`CSA_STAIR_DRAWING`**.
5. Bấm **Load / Reload Excel**, chọn đúng file `.xlsm` đang mở. Trạng thái báo số dòng và số đỉnh sau khi loại các điểm trùng liên tiếp.
6. Chọn DimStyle **GB 25**, kiểm tra tên cầu thang, mã mặt cắt và hai cao độ. Với dữ liệu trong repository: cao độ dưới **+0.050 m**, trên **+2.250 m**.
7. Bấm **Preview**, chọn điểm chèn trong vùng trống. Hộp thoại đóng để bạn có thể zoom/pan kiểm tra hình thật.
8. Gõ lại **`CSA_STAIR_DRAWING`** để mở giao diện với dữ liệu đã nạp. Bấm **Draw Section**, chọn điểm chèn bản vẽ chính thức.
9. Preview được xóa sau khi xuất thành công. Để chỉ xóa preview, mở lại giao diện và bấm **Clear Preview**.

Sau khi thay đổi Excel phải bấm **Load / Reload Excel**; không có đồng bộ nền. Nút Close chỉ đóng giao diện, không tự xóa preview để người dùng kiểm tra ngoài viewport. Khi đổi DWG, dữ liệu Excel đã nạp vẫn có thể dùng, nhưng tài nguyên và đơn vị của DWG đích được kiểm tra lại trước mỗi lần vẽ.

## Scale đã chốt từ hình người dùng

| Block | Scale X/Y/Z |
|---|---:|
| `Cao do` | **0.25** |
| `Daucat` | **0.0075** |
| `So hieu thep` | **0.35** |
| `CSA_Sohieu-KCthep` | **1.0**, giữ nguyên như mẫu không có ghi chú đổi scale |

Các mặc định này áp dụng cho template và mẫu GB 25 đã chốt; không tự nhân theo mẫu số tỷ lệ của DimStyle khác. `CSA_STAIR_TEST` trong cùng file cũng dùng các scale cố định này để có thể kiểm tra lại bộ ký hiệu.

## Giao diện hiện thực hiện được

- Chọn Excel bằng hộp thoại file, không phải gõ đường dẫn.
- Chọn DimStyle từ danh sách của DWG đích.
- Tên cầu thang, mã mặt cắt và cao độ có thể chỉnh trên giao diện.
- Đọc đường bao bê tông từ Excel; loại điểm liên tiếp trùng nhau và điểm đóng cuối trùng đầu.
- Preview bằng polyline kín, kèm tùy chọn kích thước tổng thể, cao độ và ký hiệu mặt cắt.
- Xuất cùng đường bao sang `21-GB-BD`; kích thước sang `04-GB-Dim`; chữ sang `10-GB-Text`; cao độ sang `11-GB-Cao Do`; ký hiệu sang `12-GB-Ky Hieu`.
- Các đối tượng gốc của preview nằm trên `CSA-PREVIEW` và được đánh dấu riêng. Block vẫn giữ layer/thuộc tính của các entity nội bộ theo định nghĩa CSA.
- Chỉ tạo `CSA-PREVIEW` nếu thiếu, đặt non-plot cho layer vừa tạo. Giữ nguyên các layer, block và style có sẵn.
- Mỗi lần xuất chính thức tạo một nhóm hình mới tại điểm chèn, không tự sửa hoặc xóa bản vẽ chính thức cũ. Dùng UNDO nếu cần hoàn tác lần xuất.

## Hợp đồng dữ liệu đang dùng

Nguồn duy nhất ở vòng này là sheet **`Cau Thang Tools`**. Không tự nối dữ liệu khác nghĩa trong `3-SIDES`.

| Vùng | Ý nghĩa |
|---|---|
| `BY2:BY500` | STT, dừng khi gặp ô trống |
| `BZ2:BZ500`, `CA2:CA500` | Tọa độ X/Y theo mm |
| `D22` | Chênh cao sàn, mm |
| `M30` | Cao độ sàn dưới, m |
| `AD33` | Tên cầu thang |

Trong workbook hiện tại, tọa độ đầu là mốc sàn dưới; điểm có Y lớn nhất là mốc sàn trên. Chênh cao phải khớp `D22`. Nếu file khác thay đổi ý nghĩa này, tiện ích báo lỗi thay vì tự đoán. Khi nhập cao độ trên giao diện, chênh lệch cũng phải khớp hình học trong sai số 0.5 mm.

**Kích thước tổng thể** là kích thước bao gồm cả phần dầm/gối trong đường bao: mẫu gốc có bề ngang 6500 và tổng cao bao 2600 mm. Tổng cao bao 2600 không phải chênh cao sàn 2200 mm. Đợt tiếp theo sẽ bổ sung chuỗi kích thước cấu tạo và bậc theo dữ liệu đã chuẩn hóa.

Excel được **kết nối vào phiên đang chạy**. Tiện ích không tạo/đóng Excel, không ghi ô, không tự bật macro hay tính lại workbook. Nếu có nhiều phiên Excel, hãy mở workbook trong phiên mà AutoCAD kết nối được; thông báo sẽ chỉ rõ nếu không tìm thấy file đang mở. Ô Excel lỗi, dữ liệu không hợp lệ hoặc đường bao suy biến sẽ bị từ chối trước khi thay dữ liệu đã nạp.

## Kiểm tra nghiệm thu vòng này

Gửi ảnh gồm giao diện sau Load Excel và mặt cắt sau Preview/Draw Section. Kiểm tra:

1. Đường bao khớp hình trong workbook, giữ đúng gối/dầm và chiều dày.
2. Cao độ hiển thị ba số lẻ, đúng vị trí và scale 0.25.
3. Ký hiệu mặt cắt dùng scale 0.0075; kích thước dùng GB 25.
4. Preview lặp lại không chồng hình; Clear Preview giữ nguyên hình chính thức và các đối tượng khác trên cùng layer.
5. Khi Excel đang có lỗi hoặc tài nguyên CSA thiếu/khóa, có thông báo và không xuất hình dở dang mới.

Nút **Plan (next phase)** được vô hiệu hóa: bảng tọa độ đang có là đường bao mặt cắt, chưa chứa dữ liệu mặt bằng 2 vế/3 vế. Cũng chưa dựng cốt thép thật hoặc thống kê; không lấy các thanh mẫu ở tiện ích kiểm tra để thay cho thiết kế. Bản này không chứng minh toàn bộ cầu thang 2/3 vế đã được triển khai.

## Kiểm tra mã nguồn

Đã kiểm tra tên layer/tag với CSV gốc và thực thi các helper xử lý tọa độ/định dạng bằng evaluator giới hạn cho hàm thuần. Bộ kiểm tra dùng chính 24 dòng tọa độ được lưu trong workbook. Chưa thực thi COM Excel, DCL hoặc dựng entity trong AutoCAD từ môi trường Linux.

Nguồn UI ở `../ui/CSA_StairDrawing.core.lsp`; bản một file được tạo bằng `python3 stair-tool/tools/build_stair_bundle.py`. Không sửa trực tiếp file gộp. Chạy `python3 -m unittest discover -s stair-tool/tests -v` để kiểm tra.
