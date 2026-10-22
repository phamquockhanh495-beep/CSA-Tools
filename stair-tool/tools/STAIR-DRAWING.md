# CSA Stair Drawing — giao diện và mặt cắt từ Excel

## Bản chạy một file

Tải `CSA_StairDrawing.lsp` tại thư mục này. File đã gộp toàn bộ helper cần thiết, không cần tải Lisp/DCL khác hoặc import VBA. Đây là giao diện DCL chạy trong AutoCAD Windows, chưa phải file `.dvb` hoặc UserForm đã đóng gói.

1. Mở **bản sao** `CSA Drawing Data.Rev12.dwg` (file mẫu ở nhánh `main`), vào tab Model. Đơn vị `INSUNITS=4` (mm).
2. Mở `CSA_Stair Drawing Tools.xlsm` trong Excel, kiểm tra sheet `Cau Thang Tools` đã tính ra tọa độ. Chờ Excel tính xong.
3. `APPLOAD` file **`CSA_StairDrawing.lsp`**.
4. Gõ **`CSA_STAIR_DRAWING`**.
5. Bấm **Load / Reload Excel**, chọn đúng file `.xlsm` đang mở. Trạng thái báo số dòng và số đỉnh sau khi loại các điểm trùng liên tiếp.
6. Chọn DimStyle **GB 25**, kiểm tra tên cầu thang, mã mặt cắt và hai cao độ. Với dữ liệu trong repository: cao độ dưới **+0.050 m**, trên **+2.250 m**. Bật **Concrete details**; thử **Title height = 200 mm**, **Dimension spacing = 400 mm**.
7. Bấm **Preview**, chọn điểm chèn trong vùng trống. Hộp thoại đóng để bạn có thể zoom/pan kiểm tra hình thật.
8. Gõ lại **`CSA_STAIR_DRAWING`** để mở giao diện với dữ liệu đã nạp. Bấm **Draw Section**, chọn điểm chèn bản vẽ chính thức.
9. Preview được xóa sau khi xuất thành công. Để chỉ xóa preview, mở lại giao diện và bấm **Clear Preview**.

Sau khi thay đổi Excel phải bấm **Load / Reload Excel**; không có đồng bộ nền. Nút Close chỉ đóng giao diện, không tự xóa preview để người dùng kiểm tra ngoài viewport. Khi đổi DWG, dữ liệu Excel đã nạp vẫn có thể dùng, nhưng tài nguyên và đơn vị của DWG đích được kiểm tra lại trước mỗi lần vẽ.

## Scale đã chốt từ hình người dùng

| Block | Scale X/Y/Z |
|---|---:|
| `Cao do` | **0.25** |
| `Daucat` | **0.01** |
| `So hieu thep` | **0.35** |
| `CSA_Sohieu-KCthep` | **1.0**, giữ nguyên như mẫu không có ghi chú đổi scale |

Các mặc định này áp dụng cho template và mẫu GB 25 đã chốt; không tự nhân theo mẫu số tỷ lệ của DimStyle khác. `CSA_STAIR_TEST` trong cùng file cũng dùng các scale cố định này để có thể kiểm tra lại bộ ký hiệu.

### Sửa lỗi scale trong bản concrete-details v2

Ảnh người dùng cho thấy `Daucat` khai báo Inches, Unit factor 25.4 và scale tham chiếu khoảng 0.0003, dù giá trị truyền cho InsertBlock là 0.0075. Bản mới đọc lại `XScaleFactor` sau khi chèn, dùng `ScaleEntity` để đưa scale tham chiếu về đúng mức đã chốt và kiểm tra cả ba trục. Phép biến đổi đi cùng các attribute; không đổi `INSUNITS`, định nghĩa block hoặc các block cũ.

Khi kiểm tra lại, **Properties của block Daucat mới phải có Scale X/Y/Z = 0.01**, vẫn có thể giữ Block Unit = Inches và Unit factor = 25.4. Nếu khác, gửi ảnh Properties mới; phần COM này cần xác nhận trong AutoCAD, không thể chứng minh bằng kiểm tra trên Linux.

## Giao diện hiện thực hiện được

- Chọn Excel bằng hộp thoại file, không phải gõ đường dẫn.
- Chọn DimStyle từ danh sách của DWG đích.
- Tên cầu thang, mã mặt cắt, cao độ, chiều cao tên và khoảng cách các hàng dim có thể chỉnh trên giao diện.
- Đọc đường bao bê tông từ Excel; loại điểm liên tiếp trùng nhau và điểm đóng cuối trùng đầu.
- Preview bằng polyline kín, kèm tùy chọn kích thước tổng thể, **dimension cấu tạo bê tông**, cao độ và ký hiệu mặt cắt.
- Tên cầu thang căn giữa dưới đường bao, tách khỏi chiều cao chữ DimStyle; bên dưới là cụm **MAT CAT + block Daucat**. Các thành phần được căn theo bounding box sau khi block đã được hiệu chỉnh scale.
- Xuất cùng đường bao sang `21-GB-BD`; kích thước sang `04-GB-Dim`; chữ sang `10-GB-Text`; cao độ sang `11-GB-Cao Do`; ký hiệu sang `12-GB-Ky Hieu`.
- Các đối tượng gốc của preview nằm trên `CSA-PREVIEW` và được đánh dấu riêng. Block vẫn giữ layer/thuộc tính của các entity nội bộ theo định nghĩa CSA.
- Chỉ tạo `CSA-PREVIEW` nếu thiếu, đặt non-plot cho layer vừa tạo. Giữ nguyên các layer, block và style có sẵn.
- Mỗi lần xuất chính thức tạo một nhóm hình mới tại điểm chèn, không tự sửa hoặc xóa bản vẽ chính thức cũ. Dùng UNDO nếu cần hoàn tác lần xuất.

## Hợp đồng dữ liệu bê tông đang dùng

Nguồn duy nhất ở vòng này là sheet **`Cau Thang Tools`**. Không tự nối dữ liệu khác nghĩa trong `3-SIDES`.

| Vùng | Ý nghĩa |
|---|---|
| `BY2:BY500` | STT, dừng khi gặp ô trống |
| `BZ2:BZ500`, `CA2:CA500` | Tọa độ X/Y theo mm |
| `D22` | Chênh cao sàn, mm |
| `M30` | Cao độ sàn dưới, m |
| `AD33` | Tên cầu thang |
| `H19`, `Z19`, `BA19` | Chiều dài chiếu nghỉ dưới, hình chiếu vế xiên, chiếu tới |
| `D31`, `D33` | Chiều dày bản dưới và phần dầm nhô dưới bản |
| `BU21`, `BU22` | Chiều dày bản trên và phần dầm nhô dưới bản |
| `AO27` | Chiều dày bản xiên đo vuông góc |

Trong workbook hiện tại, tọa độ đầu là mốc sàn dưới; điểm có Y lớn nhất là mốc sàn trên. Chênh cao phải khớp `D22`. Nếu file khác thay đổi ý nghĩa này, tiện ích báo lỗi thay vì tự đoán. Khi nhập cao độ trên giao diện, chênh lệch cũng phải khớp hình học trong sai số 0.5 mm.

**Overall width** chỉ vẽ tổng ngang 6500 theo hình người dùng. Đã bỏ 5 dim đánh X: tổng cao dầm dưới 400, tổng cao dầm trên 400, lọt lòng dưới 1700, lọt lòng trên 1100 và tổng cao bao 2600. Hình học bê tông không thay đổi; vẫn giữ chênh cao sàn 2200, các dim 120/280 và bề rộng các gối.

### Dimension cấu tạo bê tông

Bản v3 giữ riêng 24 điểm gốc theo STT trước khi loại trùng để nhận diện các chi tiết trong mẫu Excel. Với dữ liệu gốc, bật Concrete details sẽ tạo 15 dimension:

| Nhóm | Kích thước mẫu (mm) |
|---|---|
| Chuỗi ngang phía trên | 2000 / 3000 / 1500 |
| Chênh cao sàn | 2200 |
| Bản dưới / dầm nhô dưới bản | 120 / 280 |
| Bề rộng gối dưới | 200 và 250; không còn dim 1700 |
| Bản trên / dầm nhô dưới bản | 120 / 280 |
| Bề rộng gối trên | 200 và 200; không còn dim 1100 |
| Chênh cao đầu/cuối đoạn xiên | 314.286 / 157.143, hiển thị theo độ chính xác DimStyle |
| Bản xiên | 120, **đo vuông góc** giữa hai biên |

Các số là số đo hình học, không ghi đè text dimension. Dimension ngang/đứng dùng `AddDimRotated`; chiều dày bản xiên dùng `AddDimAligned` sau khi chiếu vuông góc. Đoạn có kích thước bằng 0 được bỏ qua, không tạo dim rỗng. Khi thông số Excel không khớp đường bao trong sai số 0.5 mm, hoặc hai biên xiên không song song, chương trình báo lỗi trước khi dựng hình mới. Tắt Concrete details nếu chỉ cần đường bao từ một workbook khác không theo hợp đồng 24 điểm này.

Các giá trị bậc hiện là chênh cao hình học ở hai đầu bản xiên, chưa phải chi tiết bậc thang riêng lẻ. Phần bê tông không suy diễn thêm bậc riêng lẻ; tim thép được tính từ các thông số riêng theo phần hướng dẫn bên dưới.

Excel được **kết nối vào phiên đang chạy**. Tiện ích không tạo/đóng Excel, không ghi ô, không tự bật macro hay tính lại workbook. Nếu có nhiều phiên Excel, hãy mở workbook trong phiên mà AutoCAD kết nối được; thông báo sẽ chỉ rõ nếu không tìm thấy file đang mở. Ô Excel lỗi, dữ liệu không hợp lệ hoặc đường bao suy biến sẽ bị từ chối trước khi thay dữ liệu đã nạp.

## Kiểm tra nghiệm thu vòng này

Gửi ảnh gồm giao diện sau Load Excel và mặt cắt sau Preview/Draw Section. Kiểm tra:

1. Đường bao khớp hình trong workbook, giữ đúng gối/dầm và chiều dày.
2. Cao độ hiển thị ba số lẻ, đúng vị trí và scale 0.25.
3. Tên cầu thang và cụm MAT CAT căn giữa dưới hình, đủ lớn với Title height 200. Ký hiệu mặt cắt có scale tham chiếu 0.01; kích thước dùng GB 25.
4. Có các chuỗi kích thước cấu tạo như bảng trên; bản xiên đo được 120, không phải khoảng cách đứng giữa hai biên.
5. Preview lặp lại không chồng hình; Clear Preview giữ nguyên hình chính thức và các đối tượng khác trên cùng layer.
6. Khi Excel đang có lỗi hoặc tài nguyên CSA thiếu/khóa, có thông báo và không xuất hình dở dang mới.

Nút **Plan (next phase)** được vô hiệu hóa: bảng tọa độ đang có là đường bao mặt cắt, chưa chứa dữ liệu mặt bằng 2 vế/3 vế. Đã có tùy chọn tim thép dọc và thép chiếu nghỉ ở giai đoạn kiểm tra, chưa có thống kê hoặc móc/uốn hoàn chỉnh. Không lấy các thanh mẫu ở tiện ích kiểm tra để thay cho thiết kế. Bản này chưa triển khai toàn bộ cầu thang 2/3 vế.

## Bước tiếp theo: tim thép dọc và chiếu nghỉ v3

Sau APPLOAD bản mới, **Load / Reload Excel** để đọc thêm `BJ28:BJ41`, rồi bật **Rebar draft** và Preview. Tùy chọn mặc định tắt để phần bê tông đã nghiệm thu không tự xuất thêm thép. Người dùng đã xác nhận neo thẳng 30d theo Excel và thép chiếu nghỉ chạy trong mặt phẳng mặt cắt.

| Ô | Dữ liệu sử dụng |
|---|---|
| `BJ28` | Cover tới bề mặt ngoài thanh; tim thanh cách biên bằng cover + d/2 |
| `BJ29`, `BJ31` | Bề rộng vế/chiếu nghỉ, được đọc nhưng chưa suy ra số thanh |
| `BJ32`, `BJ33` | Thép chiếu nghỉ dưới/trên, dựng thanh ngang trong mặt phẳng mặt cắt |
| `BJ34`, `BJ35` | Thép dọc dưới/trên, dạng `12a150` |
| `BJ36` | Thép cấu tạo/phân bố, hiện ghi nhận bằng note đầu vào |
| `BJ37` | 1 hoặc 2 lớp, áp dụng cho cả vế xiên và chiếu nghỉ; 1 lớp chỉ dựng lớp dưới |
| `BJ38` | Chiều dài đoạn neo thẳng theo bội số d, ví dụ 30d = 360 mm với d12 |
| `BJ39` | Số hiệu thanh bắt đầu; thứ tự vế xiên, chiếu nghỉ dưới, chiếu nghỉ trên; mỗi nhóm dưới rồi trên |
| `BJ40`, `BJ41` | Số cấu kiện và kiểu triển khai, đọc để mở rộng sau; chưa lập thống kê |

Bản này dựng một thanh đại diện cho mỗi lớp theo mặt cắt, không vẽ toàn bộ thanh theo chiều rộng vế. Tim thép được offset từ các biên xiên và bản, nối bằng các đoạn thẳng trong gối rồi đi ngang vào chiếu nghỉ. Mỗi đoạn ngang neo được đo từ góc chuyển hướng tim thanh, có chiều dài đúng `BJ38 × đường kính`; đây chưa phải kiểm tra chiều dài neo hiệu dụng theo tiêu chuẩn.

Hình học tim thanh có góc gãy để kiểm tra bố trí, chưa có bán kính uốn, móc, nối chồng hay chiều dài cắt gia công. Note **REBAR CENTRELINE DRAFT** luôn đi cùng hình. Không tự chọn đường kính, bước thép, bỏ lớp hoặc rút ngắn neo khi không đủ chỗ. Chương trình kiểm tra toàn bộ đoạn tim nằm trong bê tông với khoảng cách tới biên không nhỏ hơn cover + d/2, và kiểm tra hai lớp không đè lên nhau. Kiểm tra này không thay cho tính toán kết cấu hay kiểm tra khoảng cách tối thiểu theo tiêu chuẩn dự án.

Thép và ghi chú dùng `18-GB-Reinf`, `20-GB-GC`, block `CSA_Sohieu-KCthep` với tag `SH`, `DK-KC`; preview vẫn dùng hệ đánh dấu riêng. Có thể xuất cùng mặt cắt bằng Draw Section, nhưng trạng thái draft vẫn được ghi rõ.

Thép chiếu nghỉ là các thanh thẳng đại diện nằm ngang, dừng cách biên bê tông theo cover + d/2, dùng đường kính/bước thép riêng từ BJ32/BJ33. Với hai lớp, mặc định có sáu tim thanh đại diện: hai vế xiên, hai chiếu nghỉ dưới và hai chiếu nghỉ trên. Các đoạn neo của vế xiên có thể trùng hình chiếu với thanh chiếu nghỉ; bản này chưa xác định vị trí theo chiều rộng, nối chồng hoặc cấu tạo neo đầu thanh chiếu nghỉ. Ghi chú trên hình nhắc kiểm tra các phần đó. Thép phân bố BJ36 vẫn chỉ được ghi nhận bằng note `DISTRIBUTION INPUT ONLY`, chưa dựng hình.

Khi gửi ảnh vòng này, nên có cả Preview bê tông sau khi bỏ dim X và một Preview bật Rebar draft. Với dữ liệu mẫu, d12/neo30d cho hai đoạn ngang neo của mỗi thanh vế xiên dài 360 mm; cover lấy trực tiếp từ workbook đang mở (không khóa cứng 15 hoặc 25).

## Kiểm tra mã nguồn

Đã kiểm tra tên layer/tag với CSV gốc và thực thi các helper xử lý tọa độ/định dạng bằng evaluator giới hạn cho hàm thuần. Bộ kiểm tra dùng chính 24 dòng tọa độ được lưu trong workbook. Chưa thực thi COM Excel, DCL hoặc dựng entity trong AutoCAD từ môi trường Linux.

Nguồn UI ở `../ui/CSA_StairDrawing.core.lsp`, planner dimension ở `../ui/CSA_StairConcreteDetails.lsp`, tim thép ở `../ui/CSA_StairRebar.lsp`; bản một file được tạo bằng `python3 stair-tool/tools/build_stair_bundle.py`. Không sửa trực tiếp file gộp. Chạy `python3 -m unittest discover -s stair-tool/tests -v` để kiểm tra.

Khi nạp đè bản cũ, cần bấm **Load / Reload Excel một lần** để có thêm thông số cấu tạo. Các bản vẽ chính thức cũ không tự cập nhật; chọn một điểm mới để so sánh. Tên phiên bản xuất ở command line là **rebar-draft v3**.
